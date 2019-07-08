import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class ForegroundService {
  static const MethodChannel _mainChannel = const MethodChannel(
      "org.thebus.foreground_service/main", JSONMethodCodec());

  static final _ForegroundServiceNotification notification =
      new _ForegroundServiceNotification(_mainChannel);

  ///serviceFunction needs to be self-contained
  ///i.e. all setup/init/etc. needs to be done entirely within serviceFunction
  ///since apparently due to how the implementation works
  ///(callback is done via a new background isolate?)
  ///the "static" variables and so forth appear to be different instances
  static Future<void> startForegroundService([Function serviceFunction]) async {
    final setupHandle = PluginUtilities.getCallbackHandle(
            _setupForegroundServiceCallbackChannel)
        .toRawHandle();
    await _mainChannel
        .invokeMethod("startForegroundService", <dynamic>[setupHandle]);

    if (serviceFunction != null) {
      setServiceFunction(serviceFunction);
    }
  }

  static Future<void> stopForegroundService() async{
    await _mainChannel.invokeMethod("stopForegroundService");
  }

  static Future<bool> foregroundServiceIsStarted() async{
    return await _mainChannel.invokeMethod("foregroundServiceIsStarted");
  }

  ///get the function being executed periodically by the service
  static Future<Function> getServiceFunction() async =>
      PluginUtilities.getCallbackFromHandle(
          await _mainChannel.invokeMethod("getServiceFunctionHandle"));

  ///set the function being executed periodically by the service
  static Future<void> setServiceFunction(Function serviceFunction) async {
    final serviceFunctionHandle =
        PluginUtilities.getCallbackHandle(serviceFunction).toRawHandle();

    await _mainChannel.invokeMethod(
        "setServiceFunctionHandle", <dynamic>[serviceFunctionHandle]);
  }

  ///get the execution period for the service function (get/setServiceFunction);
  ///period is "minimum/best-effort" - will try to space executions with an interval that's *at least* this long
  static Future<int> getServiceIntervalSeconds() async =>
      await _mainChannel.invokeMethod("getServiceFunctionInterval");

  ///set the execution period for the service function (get/setServiceFunction)
  ///period is "minimum/best-effort" - will try to space executions with an interval that's *at least* this long
  static Future<void> setServiceIntervalSeconds(int intervalSeconds) async {
    await _mainChannel
        .invokeMethod("setServiceFunctionInterval", <dynamic>[intervalSeconds]);
  }
}

//helper/wrapper for the notification
class _ForegroundServiceNotification {
  final MethodChannel _foregroundServiceChannel;

  _ForegroundServiceNotification(this._foregroundServiceChannel);

  //wrappers just because
  Future<void> _invokeMethodSingleParam(
      String methodName, dynamic paramValue) async {
    await _foregroundServiceChannel
        .invokeMethod(methodName, <dynamic>[paramValue]);
  }

  Future<dynamic> _invokeMethod(String methodName) async {
    return await _foregroundServiceChannel.invokeMethod(methodName);
  }

  //TODO: make safe?
  ///(*see README for warning about notification-related "gets")
  Future<AndroidNotificationPriority> getPriority() async =>
      _priorityFromString(
          (await _invokeMethod("getNotificationPriority")) as String);

  ///users are allowed to change some app notification via the system UI;
  ///this probably won't work properly if they've done so
  ///(see android plugin implementation for details)
  Future<void> setPriority(AndroidNotificationPriority newPriority) async {
    await _invokeMethodSingleParam(
        "setNotificationPriority", describeEnum(newPriority));
  }

  ///(*see README for warning about notification-related "gets")
  Future<String> getTitle() async =>
      await _invokeMethod("getNotificationTitle");

  Future<void> setTitle(String newTitle) async {
    await _invokeMethodSingleParam("setNotificationTitle", newTitle);
  }

  ///(*see README for warning about notification-related "gets")
  Future<String> getText() async => await _invokeMethod("getNotificationText");

  Future<void> setText(String newText) async {
    await _invokeMethodSingleParam("setNotificationText", newText);
  }

  ///possibly not necessary
  ///in most cases it seems like things are well-behaved
  ///so a few changes at once will still result in only one response
  ///
  ///the plugin will actually rebuild/renotify for each change
  ///so there's a chance that the notification sound and/or popup
  ///may be played/shown multiple times
  ///
  ///if you await this first
  ///then make your changes
  ///and then call finshEditMode()
  ///the plugin will only call rebuild/renotify once for the whole batch
  Future<void> startEditMode() async {
    await _invokeMethod("startEditNotification");
  }

  ///use in conjunction with startEditMode()
  Future<void> finishEditMode() async {
    await _invokeMethod("finishEditNotification");
  }

  AndroidNotificationPriority _priorityFromString(String priorityString) {
    switch (priorityString) {
      case "LOW":
        return AndroidNotificationPriority.LOW;

      case "DEFAULT":
        return AndroidNotificationPriority.DEFAULT;

      case "HIGH":
        return AndroidNotificationPriority.HIGH;

      //this should never happen
      default:
        throw new Exception(
            "returned priority could not be translated: $priorityString");
    }
  }
}

//enums can't belong to classes
//so here we are
enum AndroidNotificationPriority { LOW, DEFAULT, HIGH }

//the android side will use this function as the entry point
//for the background isolate that will be used to execute dart handles
void _setupForegroundServiceCallbackChannel() {
  const MethodChannel _callbackChannel = MethodChannel(
      "org.thebus.foreground_service/callback", JSONMethodCodec());

  WidgetsFlutterBinding.ensureInitialized();

  _callbackChannel.setMethodCallHandler((MethodCall call) async {
    final dynamic args = call.arguments;
    final CallbackHandle handle = CallbackHandle.fromRawHandle(args[0]);

    PluginUtilities.getCallbackFromHandle(handle)();
  });
}

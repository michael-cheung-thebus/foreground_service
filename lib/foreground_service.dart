import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class ForegroundService {
  static const MethodChannel _mainChannel = const MethodChannel(
      "org.thebus.foreground_service/main", JSONMethodCodec());

  static MethodChannel _fromBackgroundIsolateChannel;

  static final _ForegroundServiceNotification notification =
      new _ForegroundServiceNotification(_invokeMainChannel);

  static Future<T> _invokeMainChannel<T>(String method,
      [dynamic arguments]) async {
    //this means that the method is being invoked from main isolate;
    //so can just invoke channel directly
    if (_fromBackgroundIsolateChannel == null) {
      return await _mainChannel.invokeMethod(method, arguments);
    } else {
      return await _fromBackgroundIsolateChannel.invokeMethod(
          "fromBackgroundIsolate", {"method": method, "arguments": arguments});
    }
  }

  ///serviceFunction needs to be self-contained
  ///i.e. all setup/init/etc. needs to be done entirely within serviceFunction
  ///since apparently due to how the implementation works
  ///(callback is done via a new background isolate?)
  ///the "static" variables and so forth appear to be different instances
  static Future<void> startForegroundService(
      [Function serviceFunction, bool holdWakeLock = false]) async {
    final setupHandle = PluginUtilities.getCallbackHandle(
            _setupForegroundServiceCallbackChannel)
        .toRawHandle();

    //don't know why anyone would pass null, but w/e
    final shouldHoldWakeLock = holdWakeLock ?? false;

    await _invokeMainChannel(
        "startForegroundService", <dynamic>[setupHandle, shouldHoldWakeLock]);

    if (serviceFunction != null) {
      setServiceFunction(serviceFunction);
    }
  }

  static Future<void> stopForegroundService() async {
    await _invokeMainChannel("stopForegroundService");
  }

  static Future<bool> foregroundServiceIsStarted() async {
    return await _invokeMainChannel("foregroundServiceIsStarted");
  }

  ///get the function being executed periodically by the service
  static Future<Function> getServiceFunction() async =>
      PluginUtilities.getCallbackFromHandle(
          await _invokeMainChannel("getServiceFunctionHandle"));

  ///set the function being executed periodically by the service
  static Future<void> setServiceFunction(Function serviceFunction) async {
    final serviceFunctionHandle =
        PluginUtilities.getCallbackHandle(serviceFunction).toRawHandle();

    await _invokeMainChannel(
        "setServiceFunctionHandle", <dynamic>[serviceFunctionHandle]);
  }

  ///get the execution period for the service function (get/setServiceFunction);
  ///period is "minimum/best-effort" - will try to space executions with an interval that's *at least* this long
  static Future<int> getServiceIntervalSeconds() async =>
      await _invokeMainChannel("getServiceFunctionInterval");

  ///set the execution period for the service function (get/setServiceFunction)
  ///period is "minimum/best-effort" - will try to space executions with an interval that's *at least* this long
  static Future<void> setServiceIntervalSeconds(int intervalSeconds) async {
    await _invokeMainChannel(
        "setServiceFunctionInterval", <dynamic>[intervalSeconds]);
  }

  ///tells the foreground service to also hold a wake lock
  static Future<void> getWakeLock() async {
    await _invokeMainChannel("getWakeLock");
  }

  ///tells the foreground service to release the wake lock, if it's holding one
  static Future<void> releaseWakeLock() async {
    await _invokeMainChannel("releaseWakeLock");
  }

  ///only works with v2 Android embedding (Flutter 1.12.x+)
  ///gets whether the foreground service should continue running after the app is killed
  ///for instance when it's swiped off of the recent apps list
  ///default behavior is true = keep service running after app killed
  static Future<bool> getContinueRunningAfterAppKilled() async =>
      await _invokeMainChannel("getContinueRunningAfterAppKilled");

  ///only works with v2 Android embedding (Flutter 1.12.x+)
  ///sets whether the foreground service should continue running after the app is killed
  ///for instance when it's swiped off of the recent apps list
  ///default behavior = true = keep service running after app killed
  static Future<void> setContinueRunningAfterAppKilled(
      bool shouldContinueRunning) async {
    await _invokeMainChannel(
        "setContinueRunningAfterAppKilled", <dynamic>[shouldContinueRunning]);
  }
}

//helper/wrapper for the notification
class _ForegroundServiceNotification {
  Future<T> Function<T>(String method, [dynamic arguments]) _invokeMainChannel;

  _ForegroundServiceNotification(this._invokeMainChannel);

  //TODO: make safe?
  ///(*see README for warning about notification-related "gets")
  Future<AndroidNotificationPriority> getPriority() async =>
      _priorityFromString(
          (await _invokeMainChannel("getNotificationPriority")) as String);

  ///users are allowed to change some app notification via the system UI;
  ///this probably won't work properly if they've done so
  ///(see android plugin implementation for details)
  Future<void> setPriority(AndroidNotificationPriority newPriority) async {
    await _invokeMainChannel(
        "setNotificationPriority", <dynamic>[describeEnum(newPriority)]);
  }

  ///(*see README for warning about notification-related "gets")
  Future<String> getTitle() async =>
      await _invokeMainChannel("getNotificationTitle");

  Future<void> setTitle(String newTitle) async {
    await _invokeMainChannel("setNotificationTitle", <dynamic>[newTitle]);
  }

  ///(*see README for warning about notification-related "gets")
  Future<String> getText() async =>
      await _invokeMainChannel("getNotificationText");

  Future<void> setText(String newText) async {
    await _invokeMainChannel("setNotificationText", <dynamic>[newText]);
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
    await _invokeMainChannel("startEditNotification");
  }

  ///use in conjunction with startEditMode()
  Future<void> finishEditMode() async {
    await _invokeMainChannel("finishEditNotification");
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

  ForegroundService._fromBackgroundIsolateChannel = MethodChannel(
      "org.thebus.foreground_service/fromBackgroundIsolate", JSONMethodCodec());

  WidgetsFlutterBinding.ensureInitialized();

  _callbackChannel.setMethodCallHandler((MethodCall call) async {
    final dynamic args = call.arguments;
    final CallbackHandle handle = CallbackHandle.fromRawHandle(args[0]);

    PluginUtilities.getCallbackFromHandle(handle)();
  });
}

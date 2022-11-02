import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class ForegroundService {
  static const MethodChannel _mainChannel = const MethodChannel(
      "org.thebus.foreground_service/main", JSONMethodCodec());

  static MethodChannel _fromBackgroundIsolateChannel;
  static Future<bool> get isBackgroundIsolate async =>
      (await isBackgroundIsolateSetupComplete()) &&
      (_fromBackgroundIsolateChannel != null);

  static Future<T> _invokeMainChannel<T>(String method,
      [dynamic arguments]) async {
    if (_fromBackgroundIsolateChannel == null) {
      return await _mainChannel.invokeMethod(method, arguments);
    } else {
      return await _fromBackgroundIsolateChannel.invokeMethod(
          "fromBackgroundIsolate", {"method": method, "arguments": arguments});
    }
  }

  ///set notification text, etc. through methods on this property
  static final ForegroundServiceNotification notification =
      new ForegroundServiceNotification._(_invokeMainChannel);

  ///when sendToPort(message) is called in one isolate,
  ///messageHandler(message) will be invoked from the other isolate
  ///i.e. main_sendToPort -> background_messageHandler and vice-versa
  static Future<void> setupIsolateCommunication(
      Function(dynamic message) messageHandler) async {
    _receiveHandler = messageHandler;

    if (_receivePort == null) {
      _receivePort = new ReceivePort();

      _receivePort.listen((data) {
        final callHandler = _receiveHandler;

        callHandler?.call(data);

        () async {
          if (callHandler == null) {
            debugPrint(
                "${DateTime.now()}: ${await isBackgroundIsolate ? "Background" : "Main"} isolate "
                "received message $data, but receiveHandler is null.");
          }
        }();
      });

      final String portMappingName = (await isBackgroundIsolate)
          ? _BACKGROUND_ISOLATE_PORT_NAME
          : _MAIN_ISOLATE_PORT_NAME;

      IsolateNameServer.removePortNameMapping(portMappingName);

      IsolateNameServer.registerPortWithName(
          _receivePort.sendPort, portMappingName);
    }
  }

  static bool get isIsolateCommunicationSetup =>
      ((_receivePort != null) && (_receiveHandler != null));

  static ReceivePort _receivePort;

  static const String _MAIN_ISOLATE_PORT_NAME =
      "org.thebus.foreground_service/MAIN_ISOLATE_PORT";
  static const String _BACKGROUND_ISOLATE_PORT_NAME =
      "org.thebus.foreground_service/BACKGROUND_ISOLATE_PORT";

  static void Function(dynamic message) _receiveHandler;

  ///sends a message to the other isolate, which is handled by whatever
  ///function was passed to setupIsolateCommunication in that isolate
  ///
  /// i.e. background_sendToPort("a") -> main_receiveHandler("a")
  ///
  /// values that can be sent are subject to the limitations of SendPort,
  /// i.e. primitives and lists/maps thereof
  static Future<void> sendToPort(dynamic message) async {
    final SendPort targetPort = IsolateNameServer.lookupPortByName(
        (await isBackgroundIsolate
            ? _MAIN_ISOLATE_PORT_NAME
            : _BACKGROUND_ISOLATE_PORT_NAME));

    if (targetPort != null) {
      targetPort.send(message);
    } else {
      throw _SendToPortException(await isBackgroundIsolate);
    }
  }

  ///serviceFunction needs to be self-contained
  ///i.e. all setup/init/etc. needs to be done entirely within serviceFunction
  ///since apparently due to how the implementation works
  ///callback is done within a new isolate, so memory is not shared
  ///(static variables will not have the same values, etc. etc.)
  ///communication of simple values between serviceFunction and the main app
  ///can be accomplished using setupIsolateCommunication & sendToPort
  static Future<void> startForegroundService(
      [Function serviceFunction, bool holdWakeLock = false]) async {
    //foreground service should only be started from the main isolate
    if (!(await isBackgroundIsolate)) {
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
    } else {
      throw _WrongIsolateException(await isBackgroundIsolate);
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

  ///if coordinating communication between foreground service function
  ///and main isolate, can use this to confirm setup complete
  ///before sending any messages
  static Future<bool> isBackgroundIsolateSetupComplete() async =>
      await _invokeMainChannel("isBackgroundIsolateSetupComplete");

  ///see setServiceFunctionAsync
  static Future<bool> getServiceFunctionAsync() async =>
      await _invokeMainChannel("getServiceFunctionAsync");

  ///by default, the service function is async, and will be invoked on a timer
  ///if you want to wait for the previous function execution to finish
  ///before invoking it again, set this to false (default is true)
  ///it will also wait until the serviceInterval has elapsed
  ///ex:
  /// interval = 5 seconds; instance1 required execution time = 9 seconds;
  /// instance2 required execution time = 2 seconds
  ///
  /// when (false):
  ///   instance1 start -> 9 seconds -> instance2 start -> 5 seconds -> i3 start
  ///
  /// when (true):
  ///   instance1 start -> 5 seconds -> instance2 start -> 5 seconds -> i3 start
  static Future<void> setServiceFunctionAsync(
      bool isServiceFunctionAsync) async {
    await _invokeMainChannel(
        "setServiceFunctionAsync", <dynamic>[isServiceFunctionAsync]);
  }
}

//helper/wrapper for the notification
class ForegroundServiceNotification {
  Future<T> Function<T>(String method, [dynamic arguments]) _invokeMainChannel;

  ForegroundServiceNotification._(this._invokeMainChannel);

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
@pragma('vm:entry-point')
void _setupForegroundServiceCallbackChannel() async {
  const MethodChannel _callbackChannel = MethodChannel(
      "org.thebus.foreground_service/callback", JSONMethodCodec());

  ForegroundService._fromBackgroundIsolateChannel = MethodChannel(
      "org.thebus.foreground_service/fromBackgroundIsolate", JSONMethodCodec());

  WidgetsFlutterBinding.ensureInitialized();

  _callbackChannel.setMethodCallHandler((MethodCall call) async {
    final dynamic args = call.arguments;
    final CallbackHandle handle = CallbackHandle.fromRawHandle(args[0]);

    await PluginUtilities.getCallbackFromHandle(handle)();
    await ForegroundService._invokeMainChannel(
        "backgroundIsolateCallbackComplete");
  });

  await ForegroundService._invokeMainChannel("backgroundIsolateSetupComplete");
}

class _SendToPortException implements Exception {
  final bool contextIsBackgroundIsolate;

  _SendToPortException(this.contextIsBackgroundIsolate);

  @override
  String toString() {
    return "sendToPort was called in "
        "${contextIsBackgroundIsolate ? "background" : "main"} isolate "
        "before setupIsolateCommunication for "
        "${contextIsBackgroundIsolate ? "main" : "background"} isolate was "
        "called.";
  }
}

class _WrongIsolateException implements Exception {
  final bool contextIsBackgroundIsolate;

  _WrongIsolateException(this.contextIsBackgroundIsolate);

  @override
  String toString() {
    return "Throwing function was executed in the ${contextIsBackgroundIsolate ? "background" : "main"} isolate.";
  }
}

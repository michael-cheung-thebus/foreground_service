# foreground_service (Flutter v.1.12.x or later)

Create Android foreground service&#x2F;notification

## Prep (Android side):

Android foreground services require a notification to be displayed,
and notifications require an icon.

For this plugin to work, the icon needs to be in this specific location:

`res/drawable/org_thebus_foregroundserviceplugin_notificationicon`

(take a look at the /example app if you're confused)

If you want to make deawable resourses, you can use [APPICON.CO](https://appicon.co/)

-- NOTE FOR PLUGIN VERSION 2.0.0 and above --
compileSdkVersion & targetSdkVersion need to be 29 or above, or the build will fail
these values are set/can be changed in the build.gradle for the app

## Use (Flutter/Dart side):

To start the service, Paste these code inside main function
This is an example of how to get location of the device in the background after every 600 seconds

```dart
void foreGroundFetch() async {
  if (!(await ForegroundService.foregroundServiceIsStarted())) {
    await ForegroundService.setServiceIntervalSeconds(600);

    await ForegroundService.notification.startEditMode();
    await ForegroundService.notification.setTitle("Getting Location");
    await ForegroundService.notification
        .setText("Please turn on your location service");

    await ForegroundService.notification.finishEditMode();

    await ForegroundService.startForegroundService(foregroundServiceFunction);
    await ForegroundService.getWakeLock();
  }
  
  
  // This setup communication with the background isolate
  await ForegroundService.setupIsolateCommunication((msg) {
   print(msg);
  });
}

void foregroundServiceFunction() async {

  Position position = await getPosition();
  
  //Setting new location info in the notification
  ForegroundService.notification.setText(
      "${DateTime.now().minute} ${DateTime.now().second}: ${position.latitude} ${position.longititude}");
      
  //This send positoin information to foreground UI  
  ForegroundService.sendToPort(position)

  if (!ForegroundService.isIsolateCommunicationSetup) {
    ForegroundService.setupIsolateCommunication(
        (message) => print("isolate msg received: $message"));
  }
}


```

## Doesn't work?

    As long as you're calling ForegroundService.startForegroundService,
    "flutter run" should show error messages that indicate what's wrong/missing

    i.e. messages beginning with E/ForegroundServicePlugin indicate an error from the plugin

## Caution:

    ForegroundService.notification.get* methods may give unexpected values.

    Once notifications are sent out, there's no way to retrieve the "current" data.

    To work around this, the plugin keeps a version of the notification around.
    This version may not have been "sent out" yet, however.


Disclaimer:

Most of the fancy stuff is shamelessly pilfered from the android_alarm_manager plugin

# foreground_service

Create Android foreground service&#x2F;notification

## Prep (Android side):

###### Step 1 - Create FlutterApplication subclass

    i.e. (Kotlin)

    class OverrideApplication: FlutterApplication(), PluginRegistry.PluginRegistrantCallback{
        override fun onCreate() {
            super.onCreate()
            ForegroundServicePlugin.setPluginRegistrantCallback(this)
        }

        override fun registerWith(p0: PluginRegistry?) {
            GeneratedPluginRegistrant.registerWith(p0)
        }
    }

###### Step 2 - Make necessary changes to android manifest

    Don't delete things willy-nilly unless you know what you're doing.
    Just add lines/modify as necessary.

    If you're having trouble, take a look at the /example app.

    <manifest>
        <!-- add this line -->
	    <uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>

	    <!-- there should already be an <application/> section -->
	    <!-- just modify the value of android:name, leave everything else -->
        <application android:name=".OverrideApplication">

            <!-- add this line within the application section -->
            <service android:name="org.thebus.foreground_service.ForegroundServicePlugin"
                android:exported="false"/>
        </application>
    </manifest>

###### Step 3

    Add icon resource to project.

    The icon needs to be in this specific location:

    res/drawable/org_thebus_foregroundserviceplugin_notificationicon

    (take a look at the /example app if you're confused)

## Use (Flutter/Dart side):

    To start the service, call ForegroundService.startForegroundService([serviceFunction])

    serviceFunction will then be executed periodically, but "minimum/best-effort"
    i.e. it will try to make the interval between function executions *at least* that long

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
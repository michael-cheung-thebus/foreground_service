## 1.1.0+2

Remove author from pubspec (deprecated)

## 1.1.0+1

Update example/readme to reflect Flutter 1.12.x changes

## 1.1.0

Add foreground service permission/service to manifest in plugin

## 1.0.0

Implemented FlutterPlugin interface for Flutter 1.12.x

## 0.3.1

Updated Kotlin to v1.3.50, Gradle to v3.5.3

## 0.3.0

Add option to get a wake lock

Either by passing true to second parameter of startForegroundService
or by calling new method getWakeLock()

## 0.2.1

Should no longer crash due to @UiThread exception.

## 0.2.0

Add functions to check service started status & stop service

## 0.1.1+1

Slightly updated readme

## 0.1.1

Fix bug
(class would try to init Instant regardless of api level)

## 0.1.0+2

Try to fix wording. ("No" got left behind on a separate line, so it look liked it said
"iOS support planned" at a glance).

## 0.1.0+1

Typo

## 0.1.0

1st version.  Should suffice to take care of the simple case/bare necessities:
Change title, Change text, Change icon, Change priority,
and most importantly run a dart function within the context of a foreground service.
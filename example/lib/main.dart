import 'package:flutter/material.dart';
import 'package:foreground_service/foreground_service.dart';

void main() {
  runApp(MyApp());

  startFGS();
}

//use an async method so we can await
void startFGS() async {
  await ForegroundService.setServiceIntervalSeconds(5);

  //necessity of editMode is dubious (see function comments)
  await ForegroundService.notification.startEditMode();

  await ForegroundService.notification
      .setTitle("Example Title: ${DateTime.now()}");
  await ForegroundService.notification
      .setText("Example Text: ${DateTime.now()}");

  await ForegroundService.notification.finishEditMode();

  await ForegroundService.startForegroundService(foregroundServiceFunction);
}

void foregroundServiceFunction() {
  debugPrint("The current time is: ${DateTime.now()}");
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Center(
          child: Text('Foreground Service Example'),
        ),
      ),
    );
  }
}

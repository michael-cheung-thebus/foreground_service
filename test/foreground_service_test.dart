import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foreground_service/foreground_service.dart';

void main() {
  const MethodChannel channel = MethodChannel('foreground_service');

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    channel.setMockMethodCallHandler((MethodCall methodCall) async {
      return '42';
    });
  });

  tearDown(() {
    channel.setMockMethodCallHandler(null);
  });

  test('getPlatformVersion', () async {
    expect(await ForegroundService.platformVersion, '42');
  });
}

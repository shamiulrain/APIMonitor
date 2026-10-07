import 'package:api_monitor/api_monitor.dart';
import 'package:api_monitor_example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('overlay renders the debug bubble', (tester) async {
    ApiMonitor.instance.start(globalCapture: false, shakeToOpen: false);
    await tester.pumpWidget(const ExampleApp());
    await tester.pump();

    expect(find.text('APIMonitor demo'), findsOneWidget);
    expect(find.byIcon(Icons.wifi_tethering), findsWidgets);

    ApiMonitor.instance.stop();
  });
}

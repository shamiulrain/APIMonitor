import 'package:api_monitor/api_monitor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('bubble opens the list and a row opens the detail view',
      (tester) async {
    final monitor = ApiMonitor.instance;
    monitor.stop();
    monitor.isOpen.value = false;
    monitor.start(globalCapture: false, shakeToOpen: false);

    final record = RequestRecord(
      id: monitor.store.nextId(),
      method: 'GET',
      url: 'https://example.com/api/items?page=1',
      startTime: DateTime(2024, 1, 1, 12),
    )
      ..statusCode = 200
      ..status = RequestStatus.success
      ..responseHeaders = {'content-type': 'application/json'}
      ..responseBody = '{"ok":true}'
      ..endTime = DateTime(2024, 1, 1, 12, 0, 1);
    monitor.store.add(record);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => ApiMonitorOverlay(child: child!),
        home: const Scaffold(body: Center(child: Text('home'))),
      ),
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.wifi_tethering));
    await tester.pumpAndSettle();

    expect(find.textContaining('/api/items'), findsWidgets);

    await tester.tap(find.textContaining('/api/items').first);
    await tester.pumpAndSettle();

    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('Response'), findsOneWidget);

    monitor.stop();
  });
}

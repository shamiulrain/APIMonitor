import 'package:flutter/material.dart';

import '../core/api_monitor.dart';
import 'request_list_screen.dart';

/// Standalone inspector route, used when [ApiMonitor.show] is called without an
/// [ApiMonitorOverlay] installed.
class ApiMonitorInspectorPage extends StatelessWidget {
  const ApiMonitorInspectorPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ApiMonitor.instance.theme.toThemeData(),
      child: const RequestListScreen(),
    );
  }
}

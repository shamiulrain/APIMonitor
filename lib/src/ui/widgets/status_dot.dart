import 'package:flutter/material.dart';

import '../../core/api_monitor.dart';
import '../../core/request_record.dart';

/// Coloured dot representing a record's status.
class StatusDot extends StatelessWidget {
  const StatusDot({super.key, required this.record, this.size = 8});

  final RequestRecord record;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = ApiMonitor.instance.theme;
    final color = theme.statusColor(
      record.statusCode,
      isError: record.isError,
      isPending: record.isPending,
    );
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}

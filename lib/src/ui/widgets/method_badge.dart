import 'package:flutter/material.dart';

import '../../core/api_monitor.dart';

/// Small pill showing the HTTP method, tinted by verb.
class MethodBadge extends StatelessWidget {
  const MethodBadge({super.key, required this.method, this.dense = true});

  final String method;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = ApiMonitor.instance.theme;
    final color = theme.methodColor(method);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 6 : 10,
        vertical: dense ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        method.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: dense ? 10 : 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

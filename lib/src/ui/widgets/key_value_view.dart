import 'package:flutter/material.dart';

import '../../core/api_monitor.dart';
import '../log_sharing.dart';

/// Renders a header/parameter map as selectable rows.
class KeyValueView extends StatelessWidget {
  const KeyValueView({super.key, required this.entries, this.emptyLabel = 'None'});

  final Map<String, String> entries;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    final theme = ApiMonitor.instance.theme;
    if (entries.isEmpty) {
      return Text(
        emptyLabel,
        style: TextStyle(color: theme.onSurfaceVariant, fontSize: 13),
      );
    }
    final keys = entries.keys.toList()..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final key in keys)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 120,
                  child: SelectableText(
                    key,
                    style: TextStyle(
                      color: theme.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      fontFamily: theme.monoFontFamily,
                    ),
                  ),
                ),
                Expanded(
                  child: SelectableText(
                    entries[key]!,
                    style: TextStyle(
                      color: theme.onSurface,
                      fontSize: 12,
                      fontFamily: theme.monoFontFamily,
                    ),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  iconSize: 16,
                  tooltip: 'Copy value',
                  icon: Icon(Icons.copy, color: theme.onSurfaceVariant),
                  onPressed: () => copyToClipboard(
                    context,
                    entries[key]!,
                    message: 'Copied "$key"',
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

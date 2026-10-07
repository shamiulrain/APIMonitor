import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/api_monitor.dart';
import '../../core/response_type.dart';
import '../../utils/formatters.dart';

/// Renders a request/response body: pretty printed text, an image preview, or
/// a placeholder for binary payloads.
class BodyView extends StatelessWidget {
  const BodyView({
    super.key,
    this.text,
    this.bytes,
    required this.type,
    this.emptyLabel = 'No body',
  });

  final String? text;
  final Uint8List? bytes;
  final ResponseType type;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    final theme = ApiMonitor.instance.theme;

    if (bytes != null && bytes!.isNotEmpty) {
      if (type == ResponseType.image) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(bytes!, fit: BoxFit.contain),
        );
      }
      return Text(
        'Binary data · ${formatBytes(bytes!.length)}',
        style: TextStyle(
          color: theme.onSurfaceVariant,
          fontSize: 13,
          fontFamily: theme.monoFontFamily,
        ),
      );
    }

    final value = text;
    if (value == null || value.isEmpty) {
      return Text(
        emptyLabel,
        style: TextStyle(color: theme.onSurfaceVariant, fontSize: 13),
      );
    }

    final formatted = switch (type) {
      ResponseType.json => prettyJson(value),
      ResponseType.xml || ResponseType.html => prettyMarkup(value),
      _ => value,
    };

    return SelectableText(
      formatted,
      style: TextStyle(
        color: theme.onSurface,
        fontSize: 12,
        height: 1.45,
        fontFamily: theme.monoFontFamily,
      ),
    );
  }
}

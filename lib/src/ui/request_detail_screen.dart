import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/api_monitor.dart';
import '../core/request_record.dart';
import '../core/response_type.dart';
import '../utils/curl_builder.dart';
import '../utils/formatters.dart';
import 'log_sharing.dart';
import 'widgets/body_view.dart';
import 'widgets/key_value_view.dart';
import 'widgets/method_badge.dart';
import 'widgets/section_card.dart';

/// Full detail view for a single captured call.
class RequestDetailScreen extends StatelessWidget {
  const RequestDetailScreen({super.key, required this.record});

  final RequestRecord record;

  @override
  Widget build(BuildContext context) {
    final theme = ApiMonitor.instance.theme;
    final tabs = <Tab>[
      const Tab(text: 'Overview'),
      const Tab(text: 'Request'),
      const Tab(text: 'Response'),
      if (record.isError) const Tab(text: 'Error'),
    ];

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        backgroundColor: theme.background,
        appBar: AppBar(
          titleSpacing: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  MethodBadge(method: record.method, dense: false),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      record.host,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: theme.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                record.pathWithQuery,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: theme.onSurfaceVariant, fontSize: 11),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Copy as cURL',
              icon: const Icon(Icons.terminal),
              onPressed: () => copyToClipboard(
                context,
                buildCurl(record),
                message: 'cURL copied',
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Share',
              icon: const Icon(Icons.ios_share),
              onSelected: (value) => _onShare(context, value),
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'simple', child: Text('Share log')),
                PopupMenuItem(value: 'json', child: Text('Share as JSON')),
                PopupMenuItem(value: 'curl', child: Text('Share as cURL')),
              ],
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: theme.primary,
            unselectedLabelColor: theme.onSurfaceVariant,
            indicatorColor: theme.primary,
            tabs: tabs,
          ),
        ),
        body: ListenableBuilder(
          listenable: ApiMonitor.instance.store,
          builder: (context, _) => TabBarView(
            children: [
              _OverviewTab(record: record),
              _PayloadTab(
                headersTitle: 'Request headers',
                headers: record.requestHeaders,
                type: record.requestType,
                body: record.requestBody,
                bytes: record.requestBodyBytes,
                emptyBodyLabel: 'No request body',
              ),
              _ResponseTab(record: record),
              if (record.isError) _ErrorTab(record: record),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onShare(BuildContext context, String value) async {
    switch (value) {
      case 'simple':
        await shareText(buildSimpleLog(record), subject: 'APIMonitor log');
      case 'json':
        await shareText(buildJsonLog(record), subject: 'APIMonitor log (JSON)');
      case 'curl':
        await shareText(buildCurl(record), subject: 'APIMonitor cURL');
    }
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.record});

  final RequestRecord record;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        SectionCard(
          title: 'GENERAL',
          child: Column(
            children: [
              _DetailRow(label: 'URL', value: record.url),
              _DetailRow(label: 'Method', value: record.method),
              _DetailRow(
                label: 'Status',
                value: record.isPending ? 'pending' : '${record.statusCode ?? '—'}',
              ),
              _DetailRow(label: 'Response type', value: record.responseType.label),
              _DetailRow(label: 'Duration', value: formatDuration(record.duration)),
              _DetailRow(
                label: 'Response size',
                value: formatBytes(record.responseSizeBytes),
              ),
              _DetailRow(
                label: 'Request size',
                value: formatBytes(record.requestSizeBytes),
              ),
              _DetailRow(label: 'Started', value: formatTime(record.startTime)),
              _DetailRow(label: 'Captured via', value: record.source.label),
              _DetailRow(label: 'Secure', value: record.isSecure ? 'yes' : 'no'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'QUERY PARAMETERS',
          child: KeyValueView(
            entries: record.uri?.queryParameters ?? const {},
            emptyLabel: 'No query parameters',
          ),
        ),
      ],
    );
  }
}

class _ResponseTab extends StatelessWidget {
  const _ResponseTab({required this.record});

  final RequestRecord record;

  @override
  Widget build(BuildContext context) {
    final theme = ApiMonitor.instance.theme;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        SectionCard(
          title: 'STATUS',
          child: Row(
            children: [
              Text(
                record.isPending ? '…' : '${record.statusCode ?? '—'}',
                style: TextStyle(
                  color: theme.statusColor(
                    record.statusCode,
                    isError: record.isError,
                    isPending: record.isPending,
                  ),
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  record.status.name,
                  style: TextStyle(color: theme.onSurfaceVariant, fontSize: 13),
                ),
              ),
              Text(
                formatDuration(record.duration),
                style: TextStyle(color: theme.onSurfaceVariant, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'RESPONSE HEADERS',
          child: KeyValueView(entries: record.responseHeaders),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'RESPONSE BODY',
          trailing: IconButton(
            visualDensity: VisualDensity.compact,
            iconSize: 16,
            tooltip: 'Copy body',
            icon: Icon(Icons.copy, color: theme.onSurfaceVariant),
            onPressed: record.responseBody == null
                ? null
                : () => copyToClipboard(
                      context,
                      record.responseBody!,
                      message: 'Body copied',
                    ),
          ),
          child: BodyView(
            type: record.responseType,
            text: record.responseBody,
            bytes: record.responseBodyBytes,
            emptyLabel: 'No response body',
          ),
        ),
      ],
    );
  }
}

class _PayloadTab extends StatelessWidget {
  const _PayloadTab({
    required this.headersTitle,
    required this.headers,
    required this.type,
    required this.body,
    required this.bytes,
    required this.emptyBodyLabel,
  });

  final String headersTitle;
  final Map<String, String> headers;
  final ResponseType type;
  final String? body;
  final Uint8List? bytes;
  final String emptyBodyLabel;

  @override
  Widget build(BuildContext context) {
    final theme = ApiMonitor.instance.theme;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        SectionCard(title: headersTitle.toUpperCase(), child: KeyValueView(entries: headers)),
        const SizedBox(height: 12),
        SectionCard(
          title: 'BODY',
          trailing: IconButton(
            visualDensity: VisualDensity.compact,
            iconSize: 16,
            tooltip: 'Copy body',
            icon: Icon(Icons.copy, color: theme.onSurfaceVariant),
            onPressed: body == null
                ? null
                : () => copyToClipboard(context, body!, message: 'Body copied'),
          ),
          child: BodyView(
            type: type,
            text: body,
            bytes: bytes,
            emptyLabel: emptyBodyLabel,
          ),
        ),
      ],
    );
  }
}

class _ErrorTab extends StatelessWidget {
  const _ErrorTab({required this.record});

  final RequestRecord record;

  @override
  Widget build(BuildContext context) {
    final theme = ApiMonitor.instance.theme;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        SectionCard(
          title: 'ERROR',
          trailing: IconButton(
            visualDensity: VisualDensity.compact,
            iconSize: 16,
            tooltip: 'Copy error',
            icon: Icon(Icons.copy, color: theme.onSurfaceVariant),
            onPressed: () => copyToClipboard(
              context,
              record.error ?? '',
              message: 'Error copied',
            ),
          ),
          child: SelectableText(
            record.error ?? 'Unknown error',
            style: TextStyle(
              color: theme.error,
              fontSize: 12,
              fontFamily: theme.monoFontFamily,
            ),
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = ApiMonitor.instance.theme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                color: theme.onSurfaceVariant,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: TextStyle(color: theme.onSurface, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

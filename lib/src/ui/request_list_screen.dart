import 'package:flutter/material.dart';

import '../core/api_monitor.dart';
import '../core/request_record.dart';
import '../core/record_store.dart';
import '../core/response_type.dart';
import '../utils/formatters.dart';
import 'app_info_screen.dart';
import 'log_sharing.dart';
import 'request_detail_screen.dart';
import 'statistics_screen.dart';
import 'widgets/empty_state.dart';
import 'widgets/method_badge.dart';
import 'widgets/status_dot.dart';

/// The main inspector list. Shared by [ApiMonitorOverlay] and the standalone
/// inspector route.
class RequestListScreen extends StatefulWidget {
  const RequestListScreen({
    super.key,
    this.onOpenRecord,
    this.leading,
    this.showAppBar = true,
  });

  /// Called when a row is tapped. When null, the detail screen is pushed on the
  /// ambient navigator.
  final void Function(RequestRecord record)? onOpenRecord;

  /// Optional leading widget (e.g. a close button when embedded in the overlay).
  final Widget? leading;

  final bool showAppBar;

  @override
  State<RequestListScreen> createState() => _RequestListScreenState();
}

class _RequestListScreenState extends State<RequestListScreen> {
  final TextEditingController _searchController = TextEditingController();
  final Set<ResponseType> _types = <ResponseType>{};
  bool _searching = false;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openRecord(RequestRecord record) {
    final callback = widget.onOpenRecord;
    if (callback != null) {
      callback(record);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RequestDetailScreen(record: record),
      ),
    );
  }

  void _toggleSearch() {
    setState(() {
      _searching = !_searching;
      if (!_searching) {
        _query = '';
        _searchController.clear();
      }
    });
  }

  Future<void> _showFilterSheet() async {
    final theme = ApiMonitor.instance.theme;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: theme.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(
                  'Filter by response type',
                  style: TextStyle(
                    color: theme.onSurface,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              for (final type in ResponseType.values)
                CheckboxListTile(
                  dense: true,
                  value: _types.contains(type),
                  activeColor: theme.primary,
                  title: Text(type.label, style: TextStyle(color: theme.onSurface)),
                  onChanged: (selected) {
                    setSheetState(() {
                      if (selected == true) {
                        _types.add(type);
                      } else {
                        _types.remove(type);
                      }
                    });
                    setState(() {});
                  },
                ),
              if (_types.isNotEmpty)
                TextButton(
                  onPressed: () {
                    setSheetState(_types.clear);
                    setState(() {});
                  },
                  child: const Text('Clear filters'),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _shareAll(List<RequestRecord> records) async {
    if (records.isEmpty) return;
    final text = records.map(buildSimpleLog).join('\n\n────────\n\n');
    await shareText(text, subject: 'APIMonitor log (${records.length} requests)');
  }

  @override
  Widget build(BuildContext context) {
    final monitor = ApiMonitor.instance;
    final theme = monitor.theme;

    return Scaffold(
      backgroundColor: theme.background,
      appBar: widget.showAppBar
          ? AppBar(
              leading: widget.leading,
              automaticallyImplyLeading: widget.leading == null,
              title: _searching
                  ? TextField(
                      controller: _searchController,
                      autofocus: true,
                      onChanged: (value) => setState(() => _query = value),
                      style: TextStyle(color: theme.onSurface, fontSize: 15),
                      decoration: const InputDecoration(
                        hintText: 'Search url, method, status, body…',
                        border: InputBorder.none,
                      ),
                    )
                  : const Text('APIMonitor'),
              actions: [
                IconButton(
                  tooltip: _searching ? 'Close search' : 'Search',
                  icon: Icon(_searching ? Icons.close : Icons.search),
                  onPressed: _toggleSearch,
                ),
                IconButton(
                  tooltip: 'Filter',
                  icon: Badge(
                    isLabelVisible: _types.isNotEmpty,
                    label: Text('${_types.length}'),
                    child: const Icon(Icons.filter_list),
                  ),
                  onPressed: _showFilterSheet,
                ),
                PopupMenuButton<String>(
                  tooltip: 'More',
                  onSelected: (value) => _onMenuSelected(value),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'toggle',
                      child: Text(
                        monitor.isEnabled ? 'Disable logging' : 'Enable logging',
                      ),
                    ),
                    const PopupMenuItem(value: 'stats', child: Text('Statistics')),
                    const PopupMenuItem(value: 'info', child: Text('App info')),
                    const PopupMenuItem(value: 'share', child: Text('Share log')),
                    const PopupMenuItem(value: 'clear', child: Text('Clear data')),
                  ],
                ),
              ],
            )
          : null,
      body: ListenableBuilder(
        listenable: monitor.store,
        builder: (context, _) {
          final records =
              monitor.store.query(search: _query, types: _types);
          return Column(
            children: [
              _StatsStrip(store: monitor.store),
              Expanded(
                child: records.isEmpty
                    ? EmptyState(
                        title: monitor.store.isEmpty
                            ? 'No requests captured yet'
                            : 'No matching requests',
                        subtitle: monitor.store.isEmpty
                            ? 'Make an API call and it will show up here.'
                            : 'Try a different search or filter.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.only(bottom: 24),
                        itemCount: records.length,
                        separatorBuilder: (_, _) =>
                            Divider(height: 1, color: theme.divider),
                        itemBuilder: (context, index) => _RecordTile(
                          record: records[index],
                          onTap: () => _openRecord(records[index]),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _onMenuSelected(String value) {
    final monitor = ApiMonitor.instance;
    switch (value) {
      case 'toggle':
        monitor.setEnabled(!monitor.isEnabled);
        setState(() {});
      case 'stats':
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const StatisticsScreen()),
        );
      case 'info':
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const AppInfoScreen()),
        );
      case 'share':
        _shareAll(monitor.store.records);
      case 'clear':
        confirmClear(context, monitor);
    }
  }
}

/// Asks for confirmation before wiping captured data.
Future<void> confirmClear(BuildContext context, ApiMonitor monitor) async {
  final theme = monitor.theme;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: theme.surface,
      title: Text('Clear data?', style: TextStyle(color: theme.onSurface)),
      content: Text(
        'All captured requests will be removed.',
        style: TextStyle(color: theme.onSurfaceVariant),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text('Clear', style: TextStyle(color: theme.error)),
        ),
      ],
    ),
  );
  if (confirmed == true) monitor.clear();
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({required this.record, required this.onTap});

  final RequestRecord record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ApiMonitor.instance.theme;
    final statusColor = theme.statusColor(
      record.statusCode,
      isError: record.isError,
      isPending: record.isPending,
    );

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: StatusDot(record: record),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      MethodBadge(method: record.method),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          record.pathWithQuery,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: theme.onSurface,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${record.host}  ·  ${record.responseType.label}  ·  ${record.source.label}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: theme.onSurfaceVariant, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  record.isPending
                      ? '…'
                      : (record.statusCode?.toString() ?? '—'),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${formatDuration(record.duration)} · ${formatBytes(record.responseSizeBytes)}',
                  style: TextStyle(color: theme.onSurfaceVariant, fontSize: 10),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsStrip extends StatelessWidget {
  const _StatsStrip({required this.store});

  final RecordStore store;

  @override
  Widget build(BuildContext context) {
    final theme = ApiMonitor.instance.theme;
    final stats = store.computeStats();
    return Container(
      color: theme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          _Stat(label: 'Total', value: '${stats.total}', color: theme.onSurface),
          _Stat(label: 'Errors', value: '${stats.failed}', color: theme.error),
          _Stat(
            label: 'Pending',
            value: '${stats.pending}',
            color: theme.pending,
          ),
          _Stat(
            label: 'Avg',
            value: formatDuration(stats.averageDuration),
            color: theme.onSurface,
          ),
          _Stat(
            label: 'Size',
            value: formatBytes(stats.totalSizeBytes),
            color: theme.onSurface,
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = ApiMonitor.instance.theme;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: theme.onSurfaceVariant, fontSize: 10),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

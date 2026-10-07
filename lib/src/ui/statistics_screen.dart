import 'package:flutter/material.dart';

import '../core/api_monitor.dart';
import '../core/response_type.dart';
import '../utils/formatters.dart';
import 'widgets/empty_state.dart';
import 'widgets/section_card.dart';

/// Aggregate statistics across captured calls.
class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final monitor = ApiMonitor.instance;
    final theme = monitor.theme;

    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(title: const Text('Statistics')),
      body: ListenableBuilder(
        listenable: monitor.store,
        builder: (context, _) {
          final stats = monitor.store.computeStats();
          if (stats.total == 0) {
            return const EmptyState(
              icon: Icons.bar_chart,
              title: 'No data yet',
              subtitle: 'Statistics appear once requests are captured.',
            );
          }
          final hosts = stats.byHost.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              SectionCard(
                title: 'SUMMARY',
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _Metric(label: 'Requests', value: '${stats.total}'),
                    _Metric(label: 'Success', value: '${stats.success}'),
                    _Metric(label: 'Errors', value: '${stats.failed}'),
                    _Metric(label: 'Pending', value: '${stats.pending}'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SectionCard(
                title: 'TIMING & SIZE',
                child: Column(
                  children: [
                    _Line(
                      label: 'Average duration',
                      value: formatDuration(stats.averageDuration),
                    ),
                    _Line(
                      label: 'Slowest request',
                      value: formatDuration(stats.slowest),
                    ),
                    _Line(
                      label: 'Total response size',
                      value: formatBytes(stats.totalSizeBytes),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SectionCard(
                title: 'BY RESPONSE TYPE',
                child: Column(
                  children: [
                    for (final type in ResponseType.values)
                      if ((stats.byType[type] ?? 0) > 0)
                        _Line(
                          label: type.label,
                          value: '${stats.byType[type]}',
                        ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SectionCard(
                title: 'TOP HOSTS',
                child: Column(
                  children: [
                    for (final entry in hosts.take(10))
                      _Line(label: entry.key, value: '${entry.value}'),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = ApiMonitor.instance.theme;
    return SizedBox(
      width: 120,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              color: theme.primary,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            style: TextStyle(color: theme.onSurfaceVariant, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = ApiMonitor.instance.theme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: theme.onSurfaceVariant, fontSize: 13),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: theme.onSurface,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

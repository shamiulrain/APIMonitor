import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../core/api_monitor.dart';
import '../version.dart';
import 'widgets/section_card.dart';

/// Redundant with Netfox's "Info" screen: app/build details and SDK state.
class AppInfoScreen extends StatefulWidget {
  const AppInfoScreen({super.key});

  @override
  State<AppInfoScreen> createState() => _AppInfoScreenState();
}

class _AppInfoScreenState extends State<AppInfoScreen> {
  PackageInfo? _info;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _info = info);
    } catch (_) {
      // Platform info is unavailable on some targets; fail silently.
    }
  }

  @override
  Widget build(BuildContext context) {
    final monitor = ApiMonitor.instance;
    final theme = monitor.theme;
    final info = _info;

    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(title: const Text('App info')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          SectionCard(
            title: 'APPLICATION',
            child: Column(
              children: [
                _Row(label: 'App name', value: info?.appName ?? '—'),
                _Row(label: 'Package', value: info?.packageName ?? '—'),
                _Row(label: 'Version', value: info?.version ?? '—'),
                _Row(label: 'Build number', value: info?.buildNumber ?? '—'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'DEVICE',
            child: Column(
              children: [
                _Row(label: 'Platform', value: _platformName),
                _Row(label: 'OS version', value: _osVersion),
                _Row(label: 'Dart', value: Platform.version.split(' ').first),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'API MONITOR',
            child: Column(
              children: [
                _Row(label: 'SDK version', value: apiMonitorVersion),
                _Row(
                  label: 'Capture',
                  value: monitor.isEnabled ? 'enabled' : 'disabled',
                ),
                _Row(
                  label: 'Global capture',
                  value: monitor.isGlobalCaptureEnabled ? 'on' : 'off',
                ),
                _Row(label: 'Records', value: '${monitor.store.length}'),
                _Row(
                  label: 'Ignored URLs',
                  value: '${monitor.ignoredUrls.length}',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String get _platformName {
    if (kIsWeb) return 'web';
    return Platform.operatingSystem;
  }

  String get _osVersion {
    if (kIsWeb) return '—';
    return Platform.operatingSystemVersion;
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

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
            width: 120,
            child: Text(
              label,
              style: TextStyle(color: theme.onSurfaceVariant, fontSize: 12),
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

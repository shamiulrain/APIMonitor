import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'request_record.dart';
import 'request_status.dart';
import 'response_type.dart';

/// In-memory store of captured calls. Newest records come first.
///
/// Notifies listeners whenever a record is added, updated or removed, so the
/// UI can rebuild reactively.
class RecordStore extends ChangeNotifier {
  final List<RequestRecord> _records = <RequestRecord>[];
  final Map<int, RequestRecord> _byId = <int, RequestRecord>{};
  int _nextId = 1;

  /// Maximum number of records kept before the oldest are evicted.
  int maxRecords = 250;

  /// When false, no new records are captured (existing ones remain).
  bool enabled = true;

  /// Whether bodies should be captured at all. Disabling keeps memory low.
  bool captureBodies = true;

  /// Records are truncated to this many characters before being stored.
  int maxBodyLength = 20000;

  /// Binary payloads (images, files) larger than this are clipped.
  int maxBinaryBodyLength = 2 * 1024 * 1024;

  List<RequestRecord> get records => List.unmodifiable(_records);

  int get length => _records.length;

  bool get isEmpty => _records.isEmpty;

  int get pendingCount =>
      _records.where((r) => r.status == RequestStatus.pending).length;

  int get errorCount =>
      _records.where((r) => r.status == RequestStatus.error).length;

  /// Allocates the next record id.
  int nextId() => _nextId++;

  /// Adds a new record at the top of the list.
  void add(RequestRecord record) {
    _byId[record.id] = record;
    _records.insert(0, record);
    while (_records.length > maxRecords && _records.isNotEmpty) {
      final removed = _records.removeLast();
      _byId.remove(removed.id);
    }
    notifyListeners();
  }

  /// Notifies listeners that [record] changed (response arrived, etc).
  void touch(RequestRecord record) {
    if (!_byId.containsKey(record.id)) {
      add(record);
    } else {
      notifyListeners();
    }
  }

  void clear() {
    _records.clear();
    _byId.clear();
    notifyListeners();
  }

  /// Applies the search text and response-type filter used by the list screen.
  List<RequestRecord> query({
    String search = '',
    Set<ResponseType> types = const <ResponseType>{},
  }) {
    final term = search.trim().toLowerCase();
    return _records.where((record) {
      if (types.isNotEmpty && !types.contains(record.responseType)) {
        return false;
      }
      if (term.isEmpty) return true;
      return record.url.toLowerCase().contains(term) ||
          record.method.toLowerCase().contains(term) ||
          (record.statusCode?.toString() ?? '').contains(term) ||
          record.responseType.label.toLowerCase().contains(term) ||
          (record.responseBody?.toLowerCase().contains(term) ?? false);
    }).toList();
  }

  /// Simple aggregate statistics for the statistics screen.
  Stats computeStats() {
    if (_records.isEmpty) return const Stats.empty();

    var totalDurationMs = 0;
    var completed = 0;
    var totalSize = 0;
    var success = 0;
    var failed = 0;
    var slowest = Duration.zero;
    final byType = <ResponseType, int>{};
    final hosts = <String, int>{};

    for (final record in _records) {
      byType.update(record.responseType, (v) => v + 1, ifAbsent: () => 1);
      hosts.update(record.host, (v) => v + 1, ifAbsent: () => 1);
      totalSize += record.responseSizeBytes;
      if (record.status == RequestStatus.success) success++;
      if (record.status == RequestStatus.error) failed++;
      if (!record.isPending) {
        completed++;
        totalDurationMs += record.duration.inMilliseconds;
        if (record.duration > slowest) slowest = record.duration;
      }
    }

    return Stats(
      total: _records.length,
      success: success,
      failed: failed,
      pending: _records.length - success - failed,
      averageDuration: completed == 0
          ? Duration.zero
          : Duration(milliseconds: totalDurationMs ~/ completed),
      slowest: slowest,
      totalSizeBytes: totalSize,
      byType: byType,
      byHost: hosts,
    );
  }

  /// Renders every record as newline delimited JSON (used by exporters).
  String toNdjson() =>
      _records.map((r) => jsonEncode(r.toJson())).join('\n');
}

/// Aggregate view over the captured records.
class Stats {
  const Stats({
    required this.total,
    required this.success,
    required this.failed,
    required this.pending,
    required this.averageDuration,
    required this.slowest,
    required this.totalSizeBytes,
    required this.byType,
    required this.byHost,
  });

  const Stats.empty()
      : total = 0,
        success = 0,
        failed = 0,
        pending = 0,
        averageDuration = Duration.zero,
        slowest = Duration.zero,
        totalSizeBytes = 0,
        byType = const {},
        byHost = const {};

  final int total;
  final int success;
  final int failed;
  final int pending;
  final Duration averageDuration;
  final Duration slowest;
  final int totalSizeBytes;
  final Map<ResponseType, int> byType;
  final Map<String, int> byHost;
}

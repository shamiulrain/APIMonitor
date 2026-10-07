import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Calls [onShake] when the device is shaken. Used to open the inspector the
/// same way Netfox does.
///
/// Silently does nothing on platforms without an accelerometer (desktop, web).
class ShakeDetector extends StatefulWidget {
  const ShakeDetector({
    super.key,
    required this.child,
    this.onShake,
    this.enabled = true,
    this.threshold = 16.0,
    this.cooldown = const Duration(milliseconds: 800),
  });

  final Widget child;
  final VoidCallback? onShake;
  final bool enabled;

  /// G-force magnitude that counts as a shake.
  final double threshold;
  final Duration cooldown;

  @override
  State<ShakeDetector> createState() => _ShakeDetectorState();
}

class _ShakeDetectorState extends State<ShakeDetector> {
  StreamSubscription<AccelerometerEvent>? _subscription;
  DateTime _lastShake = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(ShakeDetector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled != oldWidget.enabled) {
      if (widget.enabled) {
        _subscribe();
      } else {
        _unsubscribe();
      }
    }
  }

  void _subscribe() {
    if (!widget.enabled || _subscription != null) return;
    try {
      _subscription = accelerometerEventStream().listen(
        _onEvent,
        onError: (_) {},
        cancelOnError: true,
      );
    } catch (error) {
      debugPrint('[ApiMonitor] shake detection unavailable: $error');
    }
  }

  void _unsubscribe() {
    _subscription?.cancel();
    _subscription = null;
  }

  void _onEvent(AccelerometerEvent event) {
    final magnitude =
        math.sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
    if (magnitude < widget.threshold) return;
    final now = DateTime.now();
    if (now.difference(_lastShake) < widget.cooldown) return;
    _lastShake = now;
    widget.onShake?.call();
  }

  @override
  void dispose() {
    _unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

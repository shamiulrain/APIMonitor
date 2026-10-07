import 'package:flutter/material.dart';

import '../core/api_monitor.dart';
import '../core/request_record.dart';
import 'inspector_host.dart';
import 'request_detail_screen.dart';
import 'request_list_screen.dart';
import 'shake_detector.dart';

/// Hosts the floating debug bubble and the inspector overlay, and registers
/// itself so [ApiMonitor.show] / [ApiMonitor.hide] work from anywhere.
///
/// Install it as `MaterialApp.builder` so it sits above every route:
///
/// ```dart
/// MaterialApp(
///   builder: (context, child) => ApiMonitorOverlay(child: child!),
///   home: const HomePage(),
/// )
/// ```
class ApiMonitorOverlay extends StatefulWidget {
  const ApiMonitorOverlay({super.key, required this.child});

  final Widget child;

  @override
  State<ApiMonitorOverlay> createState() => _ApiMonitorOverlayState();
}

class _ApiMonitorOverlayState extends State<ApiMonitorOverlay>
    implements InspectorHost {
  final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    ApiMonitor.instance.registerHost(this);
  }

  @override
  void dispose() {
    ApiMonitor.instance.unregisterHost(this);
    super.dispose();
  }

  @override
  void open() => ApiMonitor.instance.isOpen.value = true;

  @override
  void close() {
    final navigator = _navKey.currentState;
    if (navigator != null && navigator.canPop()) {
      navigator.pop();
      return;
    }
    ApiMonitor.instance.isOpen.value = false;
  }

  @override
  void toggle() =>
      ApiMonitor.instance.isOpen.value ? close() : open();

  @override
  Widget build(BuildContext context) {
    final monitor = ApiMonitor.instance;
    return ShakeDetector(
      enabled: monitor.shakeToOpen,
      onShake: monitor.toggle,
      child: Stack(
        fit: StackFit.expand,
        textDirection: TextDirection.ltr,
        children: [
          widget.child,
          ValueListenableBuilder<bool>(
            valueListenable: monitor.isOpen,
            builder: (context, isOpen, _) {
              if (isOpen) return const SizedBox.shrink();
              if (!monitor.showFloatingButton) return const SizedBox.shrink();
              return _DebugBubble(onTap: monitor.toggle);
            },
          ),
          ValueListenableBuilder<bool>(
            valueListenable: monitor.isOpen,
            builder: (context, isOpen, _) {
              if (!isOpen) return const SizedBox.shrink();
              return Positioned.fill(child: _Inspector(navKey: _navKey));
            },
          ),
        ],
      ),
    );
  }
}

class _Inspector extends StatelessWidget {
  const _Inspector({required this.navKey});

  final GlobalKey<NavigatorState> navKey;

  @override
  Widget build(BuildContext context) {
    final monitor = ApiMonitor.instance;
    return Material(
      color: monitor.theme.background,
      child: Theme(
        data: monitor.theme.toThemeData(),
        // The inspector's nested Navigator must not inherit the app's
        // HeroController, otherwise Flutter asserts about a shared controller.
        child: HeroControllerScope.none(
          child: Navigator(
            key: navKey,
            onGenerateRoute: (settings) {
              if (settings.name == '/detail') {
                final record = settings.arguments as RequestRecord;
                return MaterialPageRoute<void>(
                  builder: (_) => RequestDetailScreen(record: record),
                );
              }
              return MaterialPageRoute<void>(
                builder: (_) => RequestListScreen(
                  leading: IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Close',
                    onPressed: monitor.hide,
                  ),
                  onOpenRecord: (record) => navKey.currentState?.pushNamed(
                    '/detail',
                    arguments: record,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _DebugBubble extends StatefulWidget {
  const _DebugBubble({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_DebugBubble> createState() => _DebugBubbleState();
}

class _DebugBubbleState extends State<_DebugBubble> {
  static const double _size = 52;
  Offset? _position;

  @override
  Widget build(BuildContext context) {
    final monitor = ApiMonitor.instance;
    final theme = monitor.theme;
    final screen = MediaQuery.sizeOf(context);
    final position = _position ??
        Offset(screen.width - _size - 12, screen.height - _size - 96);
    final left = position.dx.clamp(0.0, (screen.width - _size).clamp(0.0, double.infinity));
    final top = position.dy.clamp(0.0, (screen.height - _size).clamp(0.0, double.infinity));

    return Positioned(
      left: left,
      top: top,
      child: GestureDetector(
        onTap: widget.onTap,
        onPanUpdate: (details) => setState(() {
          _position = Offset(left + details.delta.dx, top + details.delta.dy);
        }),
        child: ListenableBuilder(
          listenable: monitor.store,
          builder: (context, _) {
            final count = monitor.store.length;
            final errors = monitor.store.errorCount;
            return Container(
              width: _size,
              height: _size,
              decoration: BoxDecoration(
                color: theme.bubble,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Center(
                    child: Icon(
                      Icons.wifi_tethering,
                      color: theme.bubbleForeground,
                      size: 24,
                    ),
                  ),
                  if (count > 0)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: errors > 0 ? theme.error : theme.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: theme.bubble, width: 1.5),
                        ),
                        child: Text(
                          '$count',
                          style: TextStyle(
                            color: errors > 0 ? Colors.white : theme.onSurface,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

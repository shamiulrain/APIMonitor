/// Implemented by [ApiMonitorOverlay]'s state to let [ApiMonitor] open and
/// close the inspector without needing a `BuildContext`.
abstract class InspectorHost {
  void open();
  void close();
  void toggle();
}

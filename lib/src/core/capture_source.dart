/// Where a captured call came from. Useful for debugging which integration is
/// responsible for a record.
enum CaptureSource {
  /// Captured through the global `HttpOverrides` interceptor (covers
  /// `package:http`, Dio's default adapter, `Image.network`, and any library
  /// built on `dart:io`).
  httpOverrides('dart:io'),

  /// Captured through [ApiMonitorDioInterceptor].
  dio('dio'),

  /// Captured through [ApiMonitorHttpClient].
  http('http');

  const CaptureSource(this.label);

  final String label;
}

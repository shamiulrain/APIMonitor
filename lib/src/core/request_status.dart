/// Lifecycle state of a captured call.
enum RequestStatus {
  /// Request is in flight.
  pending,

  /// Response received with a 2xx-3xx status code.
  success,

  /// Response received with a 4xx-5xx status code, or a transport error.
  error,
}

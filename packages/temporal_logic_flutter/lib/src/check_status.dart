/// Represents the status of a temporal check, especially for runtime monitoring.
enum CheckStatus {
  /// The property is currently satisfied.
  success,

  /// The property is currently violated.
  failure,

  /// The property's status cannot yet be determined (e.g., waiting for more data or time).
  pending,
}

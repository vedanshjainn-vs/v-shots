// ════════════════════════════════════════════════
// V Shots — Provider Architecture: result wrapper
// ════════════════════════════════════════════════
//
// A minimal success/failure wrapper for provider calls. Deliberately
// NOT an exception-based API: network/YouTube failures are a routine,
// expected outcome here (see stream_resolver.dart's own multi-client
// fallback and Home's per-section error/retry UI, both already handle
// "this can and will fail sometimes" as normal operation) — callers
// should check `.isSuccess` rather than wrap every call in try/catch.
// ════════════════════════════════════════════════

class ProviderResult<T> {
  const ProviderResult._({this.data, this.error});

  factory ProviderResult.success(T data) => ProviderResult._(data: data);
  factory ProviderResult.failure(String error) =>
      ProviderResult._(error: error);

  final T? data;
  final String? error;

  bool get isSuccess => error == null;
  bool get isFailure => error != null;

  /// Returns [data] if successful, otherwise [fallback]. Convenience
  /// for call sites that want a non-null value without an explicit
  /// isSuccess check (e.g. "empty list on failure").
  T orElse(T fallback) => isSuccess ? data as T : fallback;
}

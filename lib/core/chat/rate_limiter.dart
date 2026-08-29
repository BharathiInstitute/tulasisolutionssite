/// Simple client-side rate limiter to prevent accidental rapid-fire writes.
class RateLimiter {
  final Duration interval;
  DateTime? _lastCall;

  RateLimiter({required this.interval});

  /// Returns true if the action is allowed; false if throttled.
  bool allow() {
    final now = DateTime.now();
    if (_lastCall != null && now.difference(_lastCall!) < interval) {
      return false;
    }
    _lastCall = now;
    return true;
  }
}

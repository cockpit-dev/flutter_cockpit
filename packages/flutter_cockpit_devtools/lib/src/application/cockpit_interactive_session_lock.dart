import 'dart:async';

final class CockpitInteractiveSessionLock {
  final Map<String, Future<void>> _tails = <String, Future<void>>{};

  Future<T> run<T>(
    String sessionKey,
    Future<T> Function() action,
  ) async {
    final previousTail = _tails[sessionKey];
    final completer = Completer<void>();
    _tails[sessionKey] = completer.future;

    if (previousTail != null) {
      await previousTail;
    }

    try {
      return await action();
    } finally {
      completer.complete();
      if (identical(_tails[sessionKey], completer.future)) {
        _tails.remove(sessionKey);
      }
    }
  }
}

import 'dart:async';

typedef CockpitCaseOperationAbort = Future<void> Function();

final class CockpitCaseOperationLease {
  bool _active = true;
  bool _abortRequested = false;
  CockpitCaseOperationAbort? _abort;

  bool get isActive => _active;

  void registerAbort(CockpitCaseOperationAbort abort) {
    if (!_active) {
      _requestAbort(abort);
      return;
    }
    _abort = abort;
  }

  void clearAbort() {
    _abort = null;
  }

  bool tryCommit(void Function() commit) {
    if (!_active) {
      return false;
    }
    commit();
    return true;
  }

  void revoke({required bool requestAbort}) {
    if (!_active) {
      return;
    }
    _active = false;
    final abort = _abort;
    _abort = null;
    if (requestAbort && abort != null) {
      _requestAbort(abort);
    }
  }

  void _requestAbort(CockpitCaseOperationAbort abort) {
    if (_abortRequested) {
      return;
    }
    _abortRequested = true;
    unawaited(Future<void>.sync(abort).catchError((Object _, StackTrace _) {}));
  }
}

export 'cockpit_application_service_exception.dart';

import '../remote/cockpit_remote_session_client.dart';
import '../session/cockpit_remote_session_handle.dart';
import 'cockpit_interactive_session_lock.dart';
import 'cockpit_session_reference_resolver.dart';

typedef CockpitRemoteUiIdleWaiter =
    Future<bool> Function(
      Uri baseUri, {
      required Duration quietWindow,
      required Duration timeout,
      required bool includeNetworkIdle,
    });
typedef CockpitUiIdleBackoffWait = Future<void> Function(Duration duration);

final class CockpitWaitRemoteUiIdleRequest {
  const CockpitWaitRemoteUiIdleRequest({
    this.baseUri,
    this.sessionHandle,
    this.sessionHandlePath,
    this.androidDeviceId,
    this.iosDeviceId,
    this.quietWindow = const Duration(milliseconds: 96),
    this.timeout = const Duration(milliseconds: 1600),
    this.includeNetworkIdle = true,
  });

  final Uri? baseUri;
  final CockpitRemoteSessionHandle? sessionHandle;
  final String? sessionHandlePath;
  final String? androidDeviceId;
  final String? iosDeviceId;
  final Duration quietWindow;
  final Duration timeout;
  final bool includeNetworkIdle;
}

final class CockpitWaitRemoteUiIdleResult {
  const CockpitWaitRemoteUiIdleResult({
    required this.idle,
    required this.durationMs,
    required this.quietWindowMs,
    required this.timeoutMs,
    required this.includeNetworkIdle,
    this.sessionHandle,
  });

  final bool idle;
  final int durationMs;
  final int quietWindowMs;
  final int timeoutMs;
  final bool includeNetworkIdle;
  final CockpitRemoteSessionHandle? sessionHandle;

  Map<String, Object?> toJson() => <String, Object?>{
    'idle': idle,
    'durationMs': durationMs,
    'quietWindowMs': quietWindowMs,
    'timeoutMs': timeoutMs,
    'includeNetworkIdle': includeNetworkIdle,
    if (sessionHandle != null) 'sessionHandle': sessionHandle!.toJson(),
  };
}

final class CockpitWaitRemoteUiIdleService {
  CockpitWaitRemoteUiIdleService({
    CockpitRemoteUiIdleWaiter? waitForIdle,
    CockpitSessionReferenceResolver? sessionReferenceResolver,
    CockpitInteractiveSessionLock? sessionLock,
    CockpitUiIdleBackoffWait? wait,
  }) : _waitForIdle =
           waitForIdle ??
           ((
             baseUri, {
             required quietWindow,
             required timeout,
             required includeNetworkIdle,
           }) => CockpitRemoteSessionClient(baseUri: baseUri).waitForUiIdle(
             quietWindow: quietWindow,
             timeout: timeout,
             includeNetworkIdle: includeNetworkIdle,
           )),
       _sessionReferenceResolver =
           sessionReferenceResolver ?? CockpitSessionReferenceResolver(),
       _sessionLock = sessionLock ?? CockpitInteractiveSessionLock(),
       _wait = wait ?? Future<void>.delayed;

  final CockpitRemoteUiIdleWaiter _waitForIdle;
  final CockpitSessionReferenceResolver _sessionReferenceResolver;
  final CockpitInteractiveSessionLock _sessionLock;
  final CockpitUiIdleBackoffWait _wait;

  Future<CockpitWaitRemoteUiIdleResult> wait(
    CockpitWaitRemoteUiIdleRequest request,
  ) async {
    final resolved = await _sessionReferenceResolver.resolve(
      baseUri: request.baseUri,
      sessionHandle: request.sessionHandle,
      sessionHandlePath: request.sessionHandlePath,
      androidDeviceId: request.androidDeviceId,
      iosDeviceId: request.iosDeviceId,
    );
    final stopwatch = Stopwatch()..start();
    final idle = await _sessionLock.run(resolved.baseUri.toString(), () async {
      final initial = await _waitForIdle(
        resolved.baseUri,
        quietWindow: request.quietWindow,
        timeout: request.timeout,
        includeNetworkIdle: request.includeNetworkIdle,
      );
      if (initial) {
        return true;
      }

      await _wait(_transientRetryDelay);
      return _waitForIdle(
        resolved.baseUri,
        quietWindow: request.quietWindow,
        timeout: _retryTimeoutFor(request.timeout),
        includeNetworkIdle: request.includeNetworkIdle,
      );
    });
    stopwatch.stop();

    return CockpitWaitRemoteUiIdleResult(
      idle: idle,
      durationMs: stopwatch.elapsedMilliseconds,
      quietWindowMs: request.quietWindow.inMilliseconds,
      timeoutMs: request.timeout.inMilliseconds,
      includeNetworkIdle: request.includeNetworkIdle,
      sessionHandle: resolved.sessionHandle,
    );
  }

  static Duration _retryTimeoutFor(Duration timeout) {
    const retryCap = Duration(milliseconds: 400);
    return timeout < retryCap ? timeout : retryCap;
  }
}

const Duration _transientRetryDelay = Duration(milliseconds: 120);

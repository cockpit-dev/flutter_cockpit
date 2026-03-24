import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'cockpit_development_session_handle.dart';
import 'cockpit_development_session_status.dart';
import 'cockpit_flutter_run_machine_client.dart';
import 'cockpit_flutter_run_machine_event.dart';

typedef CockpitRemoteReachabilityProbe = Future<bool> Function(Uri baseUri);
typedef CockpitUiIdleWaiter = Future<bool> Function(Uri baseUri);

final class CockpitDevelopmentSessionSupervisor {
  CockpitDevelopmentSessionSupervisor({
    required CockpitDevelopmentSessionHandle initialHandle,
    required CockpitFlutterRunMachineClient machineClient,
    required CockpitRemoteReachabilityProbe remoteReachabilityProbe,
    required CockpitUiIdleWaiter uiIdleWaiter,
    DateTime Function()? now,
    InternetAddress? bindAddress,
    int bindPort = 0,
    Duration settleTimeout = const Duration(seconds: 30),
    Duration settlePollInterval = const Duration(milliseconds: 500),
  })  : _handle = initialHandle,
        _machineClient = machineClient,
        _remoteReachabilityProbe = remoteReachabilityProbe,
        _uiIdleWaiter = uiIdleWaiter,
        _now = now ?? DateTime.now,
        _bindAddress = bindAddress ?? InternetAddress.loopbackIPv4,
        _bindPort = bindPort,
        _settleTimeout = settleTimeout,
        _settlePollInterval = settlePollInterval,
        _status = CockpitDevelopmentSessionStatus(
          developmentSessionId: initialHandle.developmentSessionId,
          state: CockpitDevelopmentSessionState.starting,
          appReachable: false,
          remoteSessionReachable: false,
          reloadGeneration: initialHandle.reloadGeneration,
          lastStatusAt: (now ?? DateTime.now)().toUtc(),
        );

  CockpitDevelopmentSessionHandle _handle;
  final CockpitFlutterRunMachineClient _machineClient;
  final CockpitRemoteReachabilityProbe _remoteReachabilityProbe;
  final CockpitUiIdleWaiter _uiIdleWaiter;
  final DateTime Function() _now;
  final InternetAddress _bindAddress;
  final int _bindPort;
  final Duration _settleTimeout;
  final Duration _settlePollInterval;
  CockpitDevelopmentSessionStatus _status;
  final Completer<void> _doneCompleter = Completer<void>();
  HttpServer? _server;
  StreamSubscription<CockpitFlutterRunMachineEvent>? _eventSubscription;
  Future<void>? _pendingStartupSettle;
  bool _explicitStopRequested = false;

  Future<void> start() async {
    _server = await HttpServer.bind(_bindAddress, _bindPort);
    _handle = _handle.copyWith(
      supervisorBaseUrl: Uri(
        scheme: 'http',
        host: _server!.address.host,
        port: _server!.port,
      ).toString(),
    );
    _eventSubscription = _machineClient.events.listen(_handleMachineEvent);
    unawaited(_server!.listen(_handleHttpRequest).asFuture<void>());
  }

  Future<void> dispose() async {
    await _eventSubscription?.cancel();
    await _server?.close(force: true);
    await _machineClient.dispose();
    if (!_doneCompleter.isCompleted) {
      _doneCompleter.complete();
    }
  }

  Future<CockpitDevelopmentSessionStatus> currentStatus() async => _status;

  Future<CockpitDevelopmentSessionHandle> currentHandle() async => _handle;

  Future<void> get done => _doneCompleter.future;

  Future<void> waitForState(
    CockpitDevelopmentSessionState state, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final deadline = _now().add(timeout);
    while (_status.state != state) {
      if (_now().isAfter(deadline)) {
        throw TimeoutException(
          'Supervisor never reached ${state.jsonValue}.',
          timeout,
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  Future<CockpitDevelopmentSessionStatus> reload(
    CockpitDevelopmentReloadMode mode,
  ) async {
    final appId = _machineClient.currentAppId ?? _handle.appId;
    _setStatus(
      _status.copyWith(
        state: mode == CockpitDevelopmentReloadMode.hotReload
            ? CockpitDevelopmentSessionState.reloading
            : CockpitDevelopmentSessionState.restarting,
        lastReloadMode: mode,
        lastError: null,
      ),
    );

    try {
      switch (mode) {
        case CockpitDevelopmentReloadMode.hotReload:
          await _machineClient.hotReload(appId: appId);
        case CockpitDevelopmentReloadMode.hotRestart:
          await _machineClient.hotRestart(appId: appId);
      }
      await _settleReadyState(lastReloadMode: mode, bumpGeneration: true);
      return _status;
    } on Object catch (error) {
      _setStatus(
        _status.copyWith(
          state: CockpitDevelopmentSessionState.failed,
          lastReloadMode: mode,
          lastReloadSucceeded: false,
          lastError: '$error',
        ),
      );
      rethrow;
    }
  }

  Future<CockpitDevelopmentSessionStatus> stop({
    bool closeControlPlane = true,
  }) async {
    _explicitStopRequested = true;
    try {
      await Future.any<Object?>(<Future<Object?>>[
        _machineClient.stop(
          appId: _machineClient.currentAppId ?? _handle.appId,
        ),
        Future<Object?>.delayed(const Duration(milliseconds: 200)),
      ]);
    } on Object {
      // The process may already be gone.
    }
    _setStatus(
      _status.copyWith(
        state: CockpitDevelopmentSessionState.stopped,
        appReachable: false,
        remoteSessionReachable: false,
      ),
    );
    if (closeControlPlane) {
      await _closeControlPlane();
    }
    return _status;
  }

  void _handleMachineEvent(CockpitFlutterRunMachineEvent event) {
    switch (event.kind) {
      case CockpitFlutterRunMachineEventKind.appStart:
        final startedAppId = event.params?['appId'] as String?;
        if (startedAppId != null) {
          _handle = _handle.copyWith(appId: startedAppId);
        }
        _pendingStartupSettle ??= _settleReadyState(bumpGeneration: false);
      case CockpitFlutterRunMachineEventKind.appDebugPort:
        final wsUri = event.params?['wsUri'] as String?;
        if (wsUri != null) {
          _handle = _handle.copyWith(vmServiceUri: Uri.parse(wsUri));
        }
      case CockpitFlutterRunMachineEventKind.appStarted:
        _pendingStartupSettle ??= _settleReadyState(bumpGeneration: false);
      case CockpitFlutterRunMachineEventKind.appStop:
        final error = event.params?['error'] as String?;
        _setStatus(
          _status.copyWith(
            state: _explicitStopRequested
                ? CockpitDevelopmentSessionState.stopped
                : error == null
                    ? CockpitDevelopmentSessionState.stopped
                    : CockpitDevelopmentSessionState.failed,
            appReachable: false,
            remoteSessionReachable: false,
            lastError: error ?? _status.lastError,
          ),
        );
      case CockpitFlutterRunMachineEventKind.stderr:
        _setStatus(_status.copyWith(lastError: event.message));
      case CockpitFlutterRunMachineEventKind.processExit:
        _setStatus(
          _status.copyWith(
            state: _explicitStopRequested
                ? CockpitDevelopmentSessionState.stopped
                : CockpitDevelopmentSessionState.failed,
            appReachable: false,
            remoteSessionReachable: false,
            lastError: event.exitCode == null
                ? _status.lastError
                : 'flutter run exited with code ${event.exitCode}',
          ),
        );
      case CockpitFlutterRunMachineEventKind.daemonConnected:
      case CockpitFlutterRunMachineEventKind.appProgress:
      case CockpitFlutterRunMachineEventKind.daemonLogMessage:
      case CockpitFlutterRunMachineEventKind.request:
      case CockpitFlutterRunMachineEventKind.response:
      case CockpitFlutterRunMachineEventKind.stdout:
      case CockpitFlutterRunMachineEventKind.unknown:
        break;
    }
  }

  Future<void> _settleReadyState({
    CockpitDevelopmentReloadMode? lastReloadMode,
    required bool bumpGeneration,
  }) async {
    final deadline = _now().add(_settleTimeout);
    var remoteReachable = false;
    var uiIdle = false;
    var ready = false;

    while (!ready && _now().isBefore(deadline)) {
      remoteReachable = await _remoteReachabilityProbe(_handle.baseUri);
      uiIdle = remoteReachable ? await _uiIdleWaiter(_handle.baseUri) : false;
      ready = remoteReachable && uiIdle;
      if (!ready) {
        await Future<void>.delayed(_settlePollInterval);
      }
    }

    if (bumpGeneration && ready) {
      _handle = _handle.copyWith(
        reloadGeneration: _handle.reloadGeneration + 1,
        lastReloadAt: _now().toUtc(),
      );
    }
    _setStatus(
      _status.copyWith(
        state: ready
            ? CockpitDevelopmentSessionState.ready
            : CockpitDevelopmentSessionState.failed,
        appReachable: ready,
        remoteSessionReachable: remoteReachable,
        reloadGeneration: _handle.reloadGeneration,
        lastReloadMode: lastReloadMode ?? _status.lastReloadMode,
        lastReloadSucceeded: ready,
        lastError: ready
            ? null
            : 'Remote session did not recover to an idle ready state.',
      ),
    );
    _pendingStartupSettle = null;
  }

  Future<void> _handleHttpRequest(HttpRequest request) async {
    try {
      switch ('${request.method} ${request.uri.path}') {
        case 'GET /health':
          await _writeJson(request.response, _status.toJson());
        case 'GET /status':
          await _writeJson(request.response, <String, Object?>{
            'status': _status.toJson(),
            'handle': _handle.toJson(),
          });
        case 'POST /reload':
          final payload = await _readJsonBody(request);
          final mode = CockpitDevelopmentReloadMode.fromJson(
            payload['mode'] ?? 'hot_reload',
          );
          final status = await reload(mode);
          await _writeJson(request.response, <String, Object?>{
            'status': status.toJson(),
            'handle': _handle.toJson(),
          });
        case 'POST /restart':
          final status = await reload(CockpitDevelopmentReloadMode.hotRestart);
          await _writeJson(request.response, <String, Object?>{
            'status': status.toJson(),
            'handle': _handle.toJson(),
          });
        case 'POST /stop':
          final status = await stop(closeControlPlane: false);
          await _writeJson(request.response, <String, Object?>{
            'status': status.toJson(),
            'handle': _handle.toJson(),
          });
          unawaited(
            Future<void>.delayed(
              const Duration(milliseconds: 50),
            ).then((_) => _closeControlPlane()),
          );
        default:
          request.response.statusCode = HttpStatus.notFound;
          await _writeJson(request.response, <String, Object?>{
            'error': 'not_found',
          });
      }
    } catch (error) {
      request.response.statusCode = HttpStatus.internalServerError;
      await _writeJson(request.response, <String, Object?>{'error': '$error'});
    } finally {
      await request.response.close();
    }
  }

  Future<Map<String, Object?>> _readJsonBody(HttpRequest request) async {
    final payload = await utf8.decoder.bind(request).join();
    if (payload.isEmpty) {
      return const <String, Object?>{};
    }
    final decoded = jsonDecode(payload);
    if (decoded is! Map<Object?, Object?>) {
      throw StateError('Supervisor request body must be a JSON object.');
    }
    return Map<String, Object?>.from(decoded);
  }

  Future<void> _writeJson(
    HttpResponse response,
    Map<String, Object?> payload,
  ) async {
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode(payload));
  }

  void _setStatus(CockpitDevelopmentSessionStatus status) {
    _status = status.copyWith(lastStatusAt: _now().toUtc());
  }

  Future<void> _closeControlPlane() async {
    await _server?.close(force: true);
    if (!_doneCompleter.isCompleted) {
      _doneCompleter.complete();
    }
  }
}

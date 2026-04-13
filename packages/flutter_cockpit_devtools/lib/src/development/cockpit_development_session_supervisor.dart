import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../bridge/cockpit_web_remote_session_bridge_server.dart';
import 'cockpit_development_session_handle.dart';
import 'cockpit_development_session_status.dart';
import 'cockpit_flutter_run_machine_client.dart';
import 'cockpit_flutter_run_machine_event.dart';
import '../application/cockpit_compact_json.dart';
import '../session/cockpit_remote_session_handle.dart';

typedef CockpitRemoteReachabilityProbe = Future<bool> Function(Uri baseUri);
typedef CockpitUiIdleWaiter = Future<bool> Function(Uri baseUri);
typedef CockpitAppStopper = Future<void> Function(String appId);
typedef CockpitMachineClientConnector = Future<CockpitFlutterRunMachineClient>
    Function();
typedef CockpitSupervisorLogger = Future<void> Function(String message);
typedef CockpitWebRemoteSessionBridgeServerFactory
    = CockpitWebRemoteSessionBridgeServer? Function({
  required CockpitDevelopmentSessionHandle handle,
});

final class CockpitDevelopmentSessionSupervisor {
  CockpitDevelopmentSessionSupervisor({
    required CockpitDevelopmentSessionHandle initialHandle,
    required CockpitFlutterRunMachineClient? machineClient,
    required CockpitRemoteReachabilityProbe remoteReachabilityProbe,
    required CockpitUiIdleWaiter uiIdleWaiter,
    CockpitMachineClientConnector? machineClientConnector,
    CockpitAppStopper? appStopper,
    CockpitSupervisorLogger? logger,
    CockpitWebRemoteSessionBridgeServerFactory? webBridgeServerFactory,
    DateTime Function()? now,
    InternetAddress? bindAddress,
    int bindPort = 0,
    Duration settleTimeout = const Duration(seconds: 30),
    Duration settlePollInterval = const Duration(milliseconds: 500),
  })  : _handle = initialHandle,
        _machineClient = machineClient,
        _remoteReachabilityProbe = remoteReachabilityProbe,
        _uiIdleWaiter = uiIdleWaiter,
        _machineClientConnector = machineClientConnector,
        _appStopper = appStopper,
        _logger = logger,
        _webBridgeServerFactory =
            webBridgeServerFactory ?? cockpitCreateWebRemoteSessionBridgeServer,
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
  CockpitFlutterRunMachineClient? _machineClient;
  final CockpitRemoteReachabilityProbe _remoteReachabilityProbe;
  final CockpitUiIdleWaiter _uiIdleWaiter;
  final CockpitMachineClientConnector? _machineClientConnector;
  final CockpitAppStopper? _appStopper;
  final CockpitSupervisorLogger? _logger;
  final CockpitWebRemoteSessionBridgeServerFactory _webBridgeServerFactory;
  final DateTime Function() _now;
  final InternetAddress _bindAddress;
  final int _bindPort;
  final Duration _settleTimeout;
  final Duration _settlePollInterval;
  CockpitDevelopmentSessionStatus _status;
  final Completer<void> _doneCompleter = Completer<void>();
  HttpServer? _server;
  CockpitWebRemoteSessionBridgeServer? _webBridgeServer;
  StreamSubscription<CockpitFlutterRunMachineEvent>? _eventSubscription;
  StreamSubscription<HttpRequest>? _requestSubscription;
  Future<void>? _pendingStartupSettle;
  Future<CockpitFlutterRunMachineClient>? _machineClientConnectFuture;
  bool _explicitStopRequested = false;
  bool _controlPlaneClosed = false;
  bool _resourcesDisposed = false;

  Future<void> start() async {
    if (_handle.platform == 'web') {
      final bridge = _webBridgeServerFactory(handle: _handle);
      if (bridge != null) {
        await bridge.start();
        _webBridgeServer = bridge;
        _handle = _handle.copyWith(appBaseUrl: bridge.baseUri.toString());
      }
    }
    _server = await HttpServer.bind(_bindAddress, _bindPort);
    _handle = _handle.copyWith(
      supervisorBaseUrl: Uri(
        scheme: 'http',
        host: _server!.address.host,
        port: _server!.port,
      ).toString(),
    );
    _requestSubscription = _server!.listen(_handleHttpRequest);
    _subscribeToMachineClient(_machineClient);
    _log(
      'supervisor started control_plane=${_handle.supervisorBaseUrl} '
      'app_base=${_handle.appBaseUrl}',
    );
    _beginStartupRecovery();
  }

  Future<void> dispose() async {
    _controlPlaneClosed = true;
    await _disposeResources();
    if (!_doneCompleter.isCompleted) {
      _doneCompleter.complete();
    }
  }

  Future<CockpitDevelopmentSessionStatus> currentStatus() async => _status;

  Future<CockpitDevelopmentSessionHandle> currentHandle() async => _handle;

  Future<void> get done => _doneCompleter.future;

  Future<void> bindRemoteSession(
    CockpitRemoteSessionHandle remoteSessionHandle,
  ) async {
    _handle = _handle.copyWith(
      appId: remoteSessionHandle.appId,
      appBaseUrl: remoteSessionHandle.baseUrl,
      remoteSessionHandle: remoteSessionHandle,
    );
    _setStatus(
      _status.copyWith(
        state: CockpitDevelopmentSessionState.starting,
        lastError: null,
      ),
    );
    _log(
      'bound remote session app_id=${remoteSessionHandle.appId} '
      'base_url=${remoteSessionHandle.baseUrl}',
    );
    _beginStartupRecovery();
  }

  void reportStartupFailure(Object error) {
    _log('startup failure error=$error');
    _setStatus(
      _status.copyWith(
        state: CockpitDevelopmentSessionState.failed,
        appReachable: false,
        remoteSessionReachable: false,
        lastError: '$error',
      ),
    );
  }

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
    final machineClient = await _requireMachineClient();
    final appId = machineClient.currentAppId ?? _handle.appId;
    _setStatus(
      _status.copyWith(
        state: mode == CockpitDevelopmentReloadMode.hotReload
            ? CockpitDevelopmentSessionState.reloading
            : CockpitDevelopmentSessionState.restarting,
        lastReloadMode: mode,
        lastError: null,
      ),
    );
    _log('reload requested mode=${mode.jsonValue}');

    try {
      switch (mode) {
        case CockpitDevelopmentReloadMode.hotReload:
          await machineClient.hotReload(appId: appId);
        case CockpitDevelopmentReloadMode.hotRestart:
          await machineClient.hotRestart(appId: appId);
      }
      await _settleReadyState(lastReloadMode: mode, bumpGeneration: true);
      _log('reload completed mode=${mode.jsonValue}');
      return _status;
    } on Object catch (error) {
      _log('reload failed mode=${mode.jsonValue} error=$error');
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
    _log('stop requested close_control_plane=$closeControlPlane');
    final remoteAppId = _handle.remoteSessionHandle?.appId;
    final machineClient = _machineClient;
    if (machineClient != null) {
      try {
        await Future.any<Object?>(<Future<Object?>>[
          machineClient.stop(
            appId: machineClient.currentAppId ?? _handle.appId,
          ),
          Future<Object?>.delayed(const Duration(milliseconds: 200)),
        ]);
      } on Object {
        // The process may already be gone.
      }
    }
    if (_appStopper != null && remoteAppId != null && remoteAppId.isNotEmpty) {
      try {
        await _appStopper.call(remoteAppId);
      } on Object {
        // Best effort desktop shutdown only.
      }
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
        _log('machine event app.start app_id=${startedAppId ?? _handle.appId}');
        _beginStartupRecovery();
      case CockpitFlutterRunMachineEventKind.appDebugPort:
        final wsUri = event.params?['wsUri'] as String?;
        if (wsUri != null) {
          _handle = _handle.copyWith(vmServiceUri: Uri.parse(wsUri));
        }
        _log('machine event app.debugPort ws_uri=${wsUri ?? ''}');
      case CockpitFlutterRunMachineEventKind.appStarted:
        _log('machine event app.started');
        _beginStartupRecovery();
      case CockpitFlutterRunMachineEventKind.appStop:
        final error = event.params?['error'] as String?;
        _log('machine event app.stop error=${error ?? ''}');
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
        _log('machine stderr ${event.message ?? ''}');
        _setStatus(_status.copyWith(lastError: event.message));
      case CockpitFlutterRunMachineEventKind.processExit:
        _log('machine exit code=${event.exitCode?.toString() ?? ''}');
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
        _log('machine event daemon.connected');
      case CockpitFlutterRunMachineEventKind.appProgress:
        if (event.message case final message? when message.isNotEmpty) {
          _log('machine progress $message');
        }
      case CockpitFlutterRunMachineEventKind.daemonLogMessage:
        if (event.message case final message? when message.isNotEmpty) {
          _log('machine log $message');
        }
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
    final requireUiIdle = lastReloadMode == null;
    _log(
      'settle begin '
      'mode=${lastReloadMode?.jsonValue ?? 'startup'} '
      'base_url=${_handle.baseUri}',
    );
    final deadline = _now().add(_settleTimeout);
    var remoteReachable = false;
    var uiIdle = false;
    var ready = false;

    while (!ready && _now().isBefore(deadline)) {
      remoteReachable = await _remoteReachabilityProbe(_handle.baseUri);
      uiIdle = remoteReachable ? await _uiIdleWaiter(_handle.baseUri) : false;
      ready = remoteReachable && (uiIdle || !requireUiIdle);
      if (!ready) {
        await Future<void>.delayed(_settlePollInterval);
      }
    }

    if (ready && !requireUiIdle && !uiIdle) {
      _log(
        'settle accepted remote recovery without ui idle '
        'mode=${lastReloadMode.jsonValue}',
      );
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
            : requireUiIdle
                ? 'Remote session did not recover to an idle ready state.'
                : 'Remote session did not recover to a ready state.',
      ),
    );
    _log(
      'settle end state=${_status.state.jsonValue} '
      'app_reachable=${_status.appReachable} '
      'remote_reachable=${_status.remoteSessionReachable} '
      'error=${_status.lastError ?? ''}',
    );
    _pendingStartupSettle = null;
  }

  Future<CockpitFlutterRunMachineClient> _requireMachineClient() async {
    final existing = _machineClient;
    if (existing != null) {
      return existing;
    }
    final connected = await _ensureMachineClientConnected(
      updateStatusOnFailure: true,
    );
    if (connected == null) {
      throw StateError('Development attach is unavailable for this session.');
    }
    return connected;
  }

  void _beginStartupRecovery() {
    if (!_canProbeRemoteSession) {
      return;
    }
    _pendingStartupSettle ??= _settleReadyState(bumpGeneration: false);
    if (_machineClient == null) {
      final connectFuture = _ensureMachineClientConnected(
        updateStatusOnFailure: false,
      );
      unawaited(connectFuture.catchError((_) => null));
    }
  }

  bool get _canProbeRemoteSession {
    return _handle.remoteSessionHandle != null && _handle.appId.isNotEmpty;
  }

  Future<CockpitFlutterRunMachineClient?> _ensureMachineClientConnected({
    required bool updateStatusOnFailure,
  }) {
    final existing = _machineClient;
    if (existing != null) {
      return Future<CockpitFlutterRunMachineClient?>.value(existing);
    }
    final connector = _machineClientConnector;
    if (connector == null) {
      return Future<CockpitFlutterRunMachineClient?>.value(null);
    }
    final pending = _machineClientConnectFuture;
    if (pending != null) {
      return pending;
    }
    final future = connector().then((client) {
      _machineClient = client;
      _subscribeToMachineClient(client);
      _machineClientConnectFuture = null;
      return client;
    }).catchError((Object error) {
      _machineClientConnectFuture = null;
      if (updateStatusOnFailure) {
        _setStatus(
          _status.copyWith(
            state: CockpitDevelopmentSessionState.failed,
            lastError: '$error',
          ),
        );
      }
      throw error;
    });
    _machineClientConnectFuture = future;
    return future;
  }

  void _subscribeToMachineClient(CockpitFlutterRunMachineClient? client) {
    if (client == null || _eventSubscription != null) {
      return;
    }
    final currentAppId = client.currentAppId;
    if (currentAppId != null && currentAppId.isNotEmpty) {
      _handle = _handle.copyWith(appId: currentAppId);
    }
    final currentVmServiceUri = client.currentVmServiceUri;
    if (currentVmServiceUri != null) {
      _handle = _handle.copyWith(vmServiceUri: currentVmServiceUri);
    }
    _eventSubscription = client.events.listen(_handleMachineEvent);
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
      _log('http ${request.method} ${request.uri.path} failed error=$error');
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
    response.write(cockpitCompactJsonText(payload));
  }

  void _setStatus(CockpitDevelopmentSessionStatus status) {
    if (_status != status) {
      _log(
        'status ${_status.state.jsonValue} -> ${status.state.jsonValue} '
        'app=${status.appReachable} remote=${status.remoteSessionReachable} '
        'reload_generation=${status.reloadGeneration} '
        'error=${status.lastError ?? ''}',
      );
    }
    _status = status.copyWith(lastStatusAt: _now().toUtc());
  }

  Future<void> _closeControlPlane() async {
    if (_controlPlaneClosed) {
      return;
    }
    _controlPlaneClosed = true;
    await _disposeResources();
    if (!_doneCompleter.isCompleted) {
      _doneCompleter.complete();
    }
  }

  Future<void> _disposeResources() async {
    if (_resourcesDisposed) {
      return;
    }
    _resourcesDisposed = true;
    await _eventSubscription?.cancel();
    await _requestSubscription?.cancel();
    await _server?.close(force: true);
    await _webBridgeServer?.close();
    await _machineClient?.dispose();
  }

  void _log(String message) {
    final logger = _logger;
    if (logger == null) {
      return;
    }
    unawaited(logger(message));
  }
}

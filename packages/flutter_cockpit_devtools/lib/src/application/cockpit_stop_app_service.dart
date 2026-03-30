import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../development/cockpit_development_session_status.dart';
import 'cockpit_app_handle.dart';
import 'cockpit_app_reference_resolver.dart';
import 'cockpit_application_service_exception.dart';
import 'cockpit_platform_app_stopper.dart';
import 'cockpit_session_registry.dart';
import 'cockpit_stop_development_session_service.dart';

typedef CockpitStopDevelopmentAppFunction
    = Future<CockpitStopDevelopmentSessionResult> Function(
  CockpitStopDevelopmentSessionRequest request,
);
typedef CockpitStopAutomationAppFunction = Future<void> Function(
  CockpitAppHandle app,
);
typedef CockpitAppReachabilityProbe = Future<bool> Function(Uri baseUri);

Future<bool> cockpitProbeAppReachability(Uri baseUri) async {
  try {
    final client = HttpClient();
    try {
      final request = await client
          .getUrl(baseUri.resolve('/status'))
          .timeout(const Duration(seconds: 2));
      final response =
          await request.close().timeout(const Duration(seconds: 2));
      await response.drain<void>();
      return response.statusCode >= 200 && response.statusCode < 500;
    } finally {
      client.close(force: true);
    }
  } on Object {
    return false;
  }
}

final class CockpitStopAppRequest {
  const CockpitStopAppRequest({
    this.appId,
    this.app,
    this.appHandlePath,
  });

  final String? appId;
  final CockpitAppHandle? app;
  final String? appHandlePath;
}

final class CockpitStopAppResult {
  const CockpitStopAppResult({
    required this.app,
    required this.status,
    this.appJsonPath,
  });

  final CockpitAppHandle app;
  final CockpitAppStopStatus status;
  final String? appJsonPath;

  Map<String, Object?> toJson() => <String, Object?>{
        'app': app.toJson(),
        'status': status.toJson(),
        'app_json_path': appJsonPath,
      };
}

final class CockpitAppStopStatus {
  const CockpitAppStopStatus({
    required this.mode,
    required this.state,
    required this.appReachable,
    required this.remoteSessionReachable,
    this.lastError,
  });

  final CockpitAppMode mode;
  final String state;
  final bool appReachable;
  final bool remoteSessionReachable;
  final String? lastError;

  Map<String, Object?> toJson() => <String, Object?>{
        'mode': mode.jsonValue,
        'state': state,
        'app_reachable': appReachable,
        'remote_session_reachable': remoteSessionReachable,
        'last_error': lastError,
      };

  factory CockpitAppStopStatus.fromDevelopmentStatus(
    CockpitDevelopmentSessionStatus status,
  ) {
    return CockpitAppStopStatus(
      mode: CockpitAppMode.development,
      state: status.state.jsonValue,
      appReachable: status.appReachable,
      remoteSessionReachable: status.remoteSessionReachable,
      lastError: status.lastError,
    );
  }

  factory CockpitAppStopStatus.stopped({
    required CockpitAppMode mode,
    String? lastError,
  }) {
    return CockpitAppStopStatus(
      mode: mode,
      state: 'stopped',
      appReachable: false,
      remoteSessionReachable: false,
      lastError: lastError,
    );
  }
}

final class CockpitStopAppService {
  CockpitStopAppService({
    CockpitStopDevelopmentSessionService? stopService,
    CockpitPlatformAppStopper? automationStopper,
    CockpitAppReferenceResolver? appReferenceResolver,
    CockpitSessionRegistry? registry,
    CockpitStopDevelopmentAppFunction? stopDevelopment,
    CockpitStopAutomationAppFunction? stopAutomation,
    CockpitAppReachabilityProbe? probeReachability,
  })  : _stopDevelopment =
            stopDevelopment ?? _defaultStopDevelopment(stopService),
        _stopAutomation = stopAutomation ??
            (automationStopper ?? CockpitPlatformAppStopper()).stop,
        _appReferenceResolver = appReferenceResolver ??
            CockpitAppReferenceResolver(registry: registry),
        _registry = registry,
        _probeReachability = probeReachability ?? cockpitProbeAppReachability;

  final CockpitStopDevelopmentAppFunction _stopDevelopment;
  final CockpitStopAutomationAppFunction _stopAutomation;
  final CockpitAppReferenceResolver _appReferenceResolver;
  final CockpitSessionRegistry? _registry;
  final CockpitAppReachabilityProbe _probeReachability;

  Future<CockpitStopAppResult> stop(CockpitStopAppRequest request) async {
    final resolved = await _appReferenceResolver.resolve(
      appId: request.appId,
      app: request.app,
      appHandlePath: request.appHandlePath,
    );
    final developmentHandle =
        resolved.app?.developmentSession ?? resolved.developmentRecord?.handle;
    if (developmentHandle != null) {
      final stopped = await _stopDevelopment(
        CockpitStopDevelopmentSessionRequest(sessionHandle: developmentHandle),
      );
      _registry?.removeDevelopmentSession(
        stopped.sessionHandle.developmentSessionId,
      );
      final app = CockpitAppHandle.fromDevelopmentSession(
        stopped.sessionHandle,
        supervisorLogPath: resolved.app?.supervisorLogPath ??
            resolved.developmentRecord?.supervisorLogPath,
      );
      final appJsonPath = await _persistAppIfRequested(
        path: request.appHandlePath,
        app: app,
      );
      return CockpitStopAppResult(
        app: app,
        status: CockpitAppStopStatus.fromDevelopmentStatus(stopped.status),
        appJsonPath: appJsonPath,
      );
    }

    final automationApp = resolved.app ??
        (resolved.remoteRecord == null
            ? null
            : CockpitAppHandle.fromRemoteSession(
                resolved.remoteRecord!.handle));
    if (automationApp == null) {
      throw const CockpitApplicationServiceException(
        code: 'stopAppUnavailable',
        message: 'Stop requires a resolved app handle.',
      );
    }
    await _stopAutomation(automationApp);
    final status = await _waitUntilStopped(automationApp);
    final remoteHandle =
        automationApp.remoteSession ?? resolved.remoteRecord?.handle;
    if (remoteHandle != null) {
      _registry?.removeRemoteSession(remoteHandle);
    }
    final appJsonPath = await _persistAppIfRequested(
      path: request.appHandlePath,
      app: automationApp,
    );
    return CockpitStopAppResult(
      app: automationApp,
      status: status,
      appJsonPath: appJsonPath,
    );
  }

  Future<String?> _persistAppIfRequested({
    required String? path,
    required CockpitAppHandle app,
  }) async {
    if (path == null || path.isEmpty) {
      return null;
    }
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(app.toJson()),
    );
    return p.normalize(file.path);
  }

  Future<CockpitAppStopStatus> _waitUntilStopped(CockpitAppHandle app) async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (DateTime.now().isBefore(deadline)) {
      final reachable = await _probeReachability(app.baseUri);
      if (!reachable) {
        return CockpitAppStopStatus.stopped(mode: app.mode);
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    throw const CockpitApplicationServiceException(
      code: 'stopAppTimeout',
      message: 'The app remained reachable after the stop request.',
    );
  }
}

CockpitStopDevelopmentAppFunction _defaultStopDevelopment(
  CockpitStopDevelopmentSessionService? stopService,
) {
  final service = stopService ?? CockpitStopDevelopmentSessionService();
  return (request) => service.stop(request);
}

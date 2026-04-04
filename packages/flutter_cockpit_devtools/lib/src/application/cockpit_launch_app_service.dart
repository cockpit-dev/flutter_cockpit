import 'dart:io';

import 'package:path/path.dart' as p;

import 'cockpit_app_handle.dart';
import 'cockpit_json_key_normalizer.dart';
import 'cockpit_launch_development_session_service.dart';
import 'cockpit_launch_remote_session_service.dart';
import 'cockpit_session_registry.dart';

final class CockpitLaunchAppRequest {
  const CockpitLaunchAppRequest({
    required this.projectDir,
    required this.platform,
    required this.deviceId,
    required this.sessionPort,
    this.target,
    this.mode = CockpitAppMode.development,
    this.launchTimeout = const Duration(seconds: 120),
    this.appHandlePath,
  });

  final String projectDir;
  final String? target;
  final String platform;
  final String deviceId;
  final int sessionPort;
  final CockpitAppMode mode;
  final Duration launchTimeout;
  final String? appHandlePath;
}

final class CockpitLaunchAppResult {
  const CockpitLaunchAppResult({
    required this.app,
    this.appJsonPath,
    this.supervisorLogPath,
  });

  final CockpitAppHandle app;
  final String? appJsonPath;
  final String? supervisorLogPath;

  Map<String, Object?> toJson() => <String, Object?>{
        'app': app.toJson(),
        if (appJsonPath != null) 'appJsonPath': appJsonPath,
        if (supervisorLogPath != null) 'supervisorLogPath': supervisorLogPath,
      };
}

final class CockpitLaunchAppService {
  CockpitLaunchAppService({
    CockpitLaunchDevelopmentSessionService? developmentService,
    CockpitLaunchRemoteSessionService? remoteService,
    CockpitSessionRegistry? registry,
  })  : _developmentService =
            developmentService ?? CockpitLaunchDevelopmentSessionService(),
        _remoteService = remoteService ?? CockpitLaunchRemoteSessionService(),
        _registry = registry;

  final CockpitLaunchDevelopmentSessionService _developmentService;
  final CockpitLaunchRemoteSessionService _remoteService;
  final CockpitSessionRegistry? _registry;

  Future<CockpitLaunchAppResult> launch(CockpitLaunchAppRequest request) async {
    return switch (request.mode) {
      CockpitAppMode.development => _launchDevelopment(request),
      CockpitAppMode.automation => _launchAutomation(request),
    };
  }

  Future<CockpitLaunchAppResult> _launchDevelopment(
    CockpitLaunchAppRequest request,
  ) async {
    final result = await _developmentService.launch(
      CockpitLaunchDevelopmentSessionRequest(
        projectDir: request.projectDir,
        target: request.target,
        platform: request.platform,
        deviceId: request.deviceId,
        sessionPort: request.sessionPort,
        launchTimeout: request.launchTimeout,
      ),
    );
    _registry?.recordDevelopmentSession(
      handle: result.sessionHandle,
      status: result.status,
      supervisorLogPath: result.supervisorLogPath,
    );
    final app = CockpitAppHandle.fromDevelopmentSession(
      result.sessionHandle,
      supervisorLogPath: result.supervisorLogPath,
    );
    final appJsonPath = await _persistAppIfRequested(
      path: request.appHandlePath,
      app: app,
    );
    return CockpitLaunchAppResult(
      app: app,
      appJsonPath: appJsonPath,
      supervisorLogPath: result.supervisorLogPath,
    );
  }

  Future<CockpitLaunchAppResult> _launchAutomation(
    CockpitLaunchAppRequest request,
  ) async {
    final result = await _remoteService.launch(
      CockpitLaunchRemoteSessionRequest(
        projectDir: request.projectDir,
        target: request.target,
        platform: request.platform,
        deviceId: request.deviceId,
        sessionPort: request.sessionPort,
        launchTimeout: request.launchTimeout,
      ),
    );
    _registry?.recordRemoteSession(
      handle: result.sessionHandle,
      status: result.health,
      recommendedNextStep: result.health.capabilities.supportsInAppControl
          ? 'readyForCommands'
          : 'limited_capabilities',
    );
    final app = CockpitAppHandle.fromRemoteSession(result.sessionHandle);
    final appJsonPath = await _persistAppIfRequested(
      path: request.appHandlePath,
      app: app,
    );
    return CockpitLaunchAppResult(
      app: app,
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
    await file.writeAsString(cockpitPrettyJsonText(app.toJson()));
    return p.normalize(file.path);
  }
}

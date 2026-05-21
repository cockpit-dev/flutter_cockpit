import 'cockpit_app_handle.dart';
import 'cockpit_session_registry.dart';

final class CockpitAppSummary {
  const CockpitAppSummary({
    required this.appId,
    required this.mode,
    required this.platform,
    required this.deviceId,
    required this.projectDir,
    required this.target,
    required this.baseUrl,
    required this.updatedAt,
    this.platformAppId,
    this.state,
    this.lastError,
  });

  final String appId;
  final CockpitAppMode mode;
  final String platform;
  final String deviceId;
  final String projectDir;
  final String target;
  final String baseUrl;
  final DateTime updatedAt;
  final String? platformAppId;
  final String? state;
  final String? lastError;

  Map<String, Object?> toJson() => <String, Object?>{
        'appId': appId,
        'mode': mode.jsonValue,
        'platform': platform,
        'deviceId': deviceId,
        'projectDir': projectDir,
        'target': target,
        'baseUrl': baseUrl,
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        if (platformAppId != null) 'platformAppId': platformAppId,
        if (state != null) 'state': state,
        if (lastError != null) 'lastError': lastError,
      };
}

final class CockpitListAppsResult {
  const CockpitListAppsResult({required this.apps});

  final List<CockpitAppSummary> apps;

  Map<String, Object?> toJson() => <String, Object?>{
        'apps': apps.map((app) => app.toJson()).toList(growable: false),
      };
}

final class CockpitListAppsService {
  const CockpitListAppsService({required CockpitSessionRegistry registry})
      : _registry = registry;

  final CockpitSessionRegistry _registry;

  CockpitListAppsResult list() {
    final snapshot = _registry.snapshot();
    final apps = <CockpitAppSummary>[
      for (final record in snapshot.developmentSessions)
        CockpitAppSummary(
          appId: record.handle.appId,
          mode: CockpitAppMode.development,
          platform: record.handle.platform,
          deviceId: record.handle.deviceId,
          projectDir: record.handle.projectDir,
          target: record.handle.target,
          baseUrl: record.handle.appBaseUrl,
          updatedAt: record.updatedAt,
          platformAppId:
              record.handle.remoteSessionHandle?.effectivePlatformAppId,
          state: record.status.state.jsonValue,
          lastError: record.status.lastError,
        ),
      for (final record in snapshot.remoteSessions)
        CockpitAppSummary(
          appId: record.handle.appId,
          mode: CockpitAppMode.automation,
          platform: record.handle.platform,
          deviceId: record.handle.deviceId,
          projectDir: record.handle.projectDir,
          target: record.handle.target,
          baseUrl: record.handle.baseUrl,
          updatedAt: record.updatedAt,
          platformAppId: record.handle.effectivePlatformAppId,
          state: record.recommendedNextStep,
          lastError: null,
        ),
    ];
    return CockpitListAppsResult(
        apps: List<CockpitAppSummary>.unmodifiable(apps));
  }
}

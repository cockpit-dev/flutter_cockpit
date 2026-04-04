import '../development/cockpit_development_session_handle.dart';
import '../session/cockpit_remote_session_handle.dart';
import 'cockpit_json_key_normalizer.dart';

enum CockpitAppMode {
  development('development'),
  automation('automation');

  const CockpitAppMode(this.jsonValue);

  final String jsonValue;

  static CockpitAppMode fromJson(Object? value) {
    return values.firstWhere(
      (candidate) => candidate.jsonValue == value,
      orElse: () => throw ArgumentError.value(
        value,
        'value',
        'Unsupported app mode.',
      ),
    );
  }
}

final class CockpitAppHandle {
  const CockpitAppHandle({
    required this.appId,
    required this.mode,
    required this.platform,
    required this.deviceId,
    required this.projectDir,
    required this.target,
    required this.baseUrl,
    required this.launchedAt,
    this.platformAppId,
    this.supervisorLogPath,
    this.developmentSession,
    this.remoteSession,
  });

  final String appId;
  final CockpitAppMode mode;
  final String platform;
  final String deviceId;
  final String projectDir;
  final String target;
  final String baseUrl;
  final DateTime launchedAt;
  final String? platformAppId;
  final String? supervisorLogPath;
  final CockpitDevelopmentSessionHandle? developmentSession;
  final CockpitRemoteSessionHandle? remoteSession;

  Uri get baseUri => Uri.parse(baseUrl);

  bool get supportsHotReload => mode == CockpitAppMode.development;

  Map<String, Object?> toJson() => <String, Object?>{
        'appId': appId,
        'mode': mode.jsonValue,
        'platform': platform,
        'deviceId': deviceId,
        'projectDir': projectDir,
        'target': target,
        'baseUrl': baseUrl,
        'launchedAt': launchedAt.toUtc().toIso8601String(),
        'platformAppId': platformAppId,
        'supportsHotReload': supportsHotReload,
        'supervisorLogPath': supervisorLogPath,
        'developmentSessionId': developmentSession?.developmentSessionId,
        'supervisorBaseUrl': developmentSession?.supervisorBaseUri.toString(),
        'reloadGeneration': developmentSession?.reloadGeneration,
        'vmServiceUri': developmentSession?.vmServiceUri?.toString(),
        'lastReloadAt':
            developmentSession?.lastReloadAt?.toUtc().toIso8601String(),
      };

  factory CockpitAppHandle.fromJson(Map<String, Object?> json) {
    final normalizedJson = cockpitNormalizeJsonKeys(json);
    final developmentSessionJson =
        normalizedJson['developmentSession'] as Map<Object?, Object?>?;
    final remoteSessionJson =
        normalizedJson['remoteSession'] as Map<Object?, Object?>?;
    return CockpitAppHandle(
      appId: normalizedJson['appId']! as String,
      mode: CockpitAppMode.fromJson(normalizedJson['mode']),
      platform: normalizedJson['platform']! as String,
      deviceId: normalizedJson['deviceId']! as String,
      projectDir: normalizedJson['projectDir']! as String,
      target: normalizedJson['target']! as String,
      baseUrl: normalizedJson['baseUrl']! as String,
      launchedAt:
          DateTime.parse(normalizedJson['launchedAt']! as String).toUtc(),
      platformAppId: normalizedJson['platformAppId'] as String?,
      supervisorLogPath: normalizedJson['supervisorLogPath'] as String?,
      developmentSession: developmentSessionJson == null
          ? _developmentSessionFromCompactJson(normalizedJson)
          : CockpitDevelopmentSessionHandle.fromJson(
              Map<String, Object?>.from(developmentSessionJson),
            ),
      remoteSession: remoteSessionJson == null
          ? null
          : CockpitRemoteSessionHandle.fromJson(
              Map<String, Object?>.from(remoteSessionJson),
            ),
    );
  }

  factory CockpitAppHandle.fromDevelopmentSession(
      CockpitDevelopmentSessionHandle handle,
      {String? supervisorLogPath}) {
    return CockpitAppHandle(
      appId: handle.appId,
      mode: CockpitAppMode.development,
      platform: handle.platform,
      deviceId: handle.deviceId,
      projectDir: handle.projectDir,
      target: handle.target,
      baseUrl: handle.appBaseUrl,
      launchedAt: handle.launchedAt,
      platformAppId: handle.remoteSessionHandle?.appId,
      supervisorLogPath: supervisorLogPath,
      developmentSession: handle,
      remoteSession: handle.remoteSessionHandle,
    );
  }

  factory CockpitAppHandle.fromRemoteSession(
      CockpitRemoteSessionHandle handle) {
    return CockpitAppHandle(
      appId: handle.appId,
      mode: CockpitAppMode.automation,
      platform: handle.platform,
      deviceId: handle.deviceId,
      projectDir: handle.projectDir,
      target: handle.target,
      baseUrl: handle.baseUrl,
      launchedAt: handle.launchedAt,
      platformAppId: handle.appId,
      remoteSession: handle,
    );
  }

  CockpitAppHandle copyWith({
    String? appId,
    CockpitAppMode? mode,
    String? platform,
    String? deviceId,
    String? projectDir,
    String? target,
    String? baseUrl,
    DateTime? launchedAt,
    String? platformAppId,
    String? supervisorLogPath,
    CockpitDevelopmentSessionHandle? developmentSession,
    CockpitRemoteSessionHandle? remoteSession,
  }) {
    return CockpitAppHandle(
      appId: appId ?? this.appId,
      mode: mode ?? this.mode,
      platform: platform ?? this.platform,
      deviceId: deviceId ?? this.deviceId,
      projectDir: projectDir ?? this.projectDir,
      target: target ?? this.target,
      baseUrl: baseUrl ?? this.baseUrl,
      launchedAt: launchedAt ?? this.launchedAt,
      platformAppId: platformAppId ?? this.platformAppId,
      supervisorLogPath: supervisorLogPath ?? this.supervisorLogPath,
      developmentSession: developmentSession ?? this.developmentSession,
      remoteSession: remoteSession ?? this.remoteSession,
    );
  }
}

CockpitDevelopmentSessionHandle? _developmentSessionFromCompactJson(
  Map<String, Object?> json,
) {
  final developmentSessionId = json['developmentSessionId'] as String?;
  final supervisorBaseUrl = json['supervisorBaseUrl'] as String?;
  if (developmentSessionId == null ||
      developmentSessionId.isEmpty ||
      supervisorBaseUrl == null ||
      supervisorBaseUrl.isEmpty) {
    return null;
  }
  return CockpitDevelopmentSessionHandle(
    developmentSessionId: developmentSessionId,
    platform: json['platform']! as String,
    deviceId: json['deviceId']! as String,
    projectDir: json['projectDir']! as String,
    target: json['target']! as String,
    appId: json['appId']! as String,
    appBaseUrl: json['baseUrl']! as String,
    supervisorBaseUrl: supervisorBaseUrl,
    launchedAt: DateTime.parse(json['launchedAt']! as String).toUtc(),
    reloadGeneration: json['reloadGeneration'] as int? ?? 0,
    vmServiceUri: json['vmServiceUri'] == null
        ? null
        : Uri.parse(json['vmServiceUri']! as String),
    lastReloadAt: json['lastReloadAt'] == null
        ? null
        : DateTime.parse(json['lastReloadAt']! as String).toUtc(),
  );
}

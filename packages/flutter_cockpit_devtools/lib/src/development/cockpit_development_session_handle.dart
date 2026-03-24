import '../session/cockpit_remote_session_handle.dart';

enum CockpitDevelopmentLaunchMode {
  development('development');

  const CockpitDevelopmentLaunchMode(this.jsonValue);

  final String jsonValue;

  static CockpitDevelopmentLaunchMode fromJson(Object? json) {
    return values.firstWhere(
      (value) => value.jsonValue == json,
      orElse: () => throw ArgumentError.value(
        json,
        'json',
        'Unsupported development launch mode.',
      ),
    );
  }
}

final class CockpitDevelopmentSessionHandle {
  const CockpitDevelopmentSessionHandle({
    required this.developmentSessionId,
    required this.platform,
    required this.deviceId,
    required this.projectDir,
    required this.target,
    required this.appId,
    required this.appBaseUrl,
    required this.supervisorBaseUrl,
    required this.launchedAt,
    required this.reloadGeneration,
    this.launchMode = CockpitDevelopmentLaunchMode.development,
    this.remoteSessionHandle,
    this.vmServiceUri,
    this.lastReloadAt,
  });

  final String developmentSessionId;
  final String platform;
  final String deviceId;
  final String projectDir;
  final String target;
  final String appId;
  final String appBaseUrl;
  final String supervisorBaseUrl;
  final CockpitDevelopmentLaunchMode launchMode;
  final CockpitRemoteSessionHandle? remoteSessionHandle;
  final Uri? vmServiceUri;
  final DateTime launchedAt;
  final DateTime? lastReloadAt;
  final int reloadGeneration;

  Uri get baseUri => Uri.parse(appBaseUrl);

  Uri get supervisorBaseUri => Uri.parse(supervisorBaseUrl);

  Map<String, Object?> toJson() => <String, Object?>{
        'developmentSessionId': developmentSessionId,
        'platform': platform,
        'deviceId': deviceId,
        'projectDir': projectDir,
        'target': target,
        'appId': appId,
        'appBaseUrl': appBaseUrl,
        'supervisorBaseUrl': supervisorBaseUrl,
        'launchMode': launchMode.jsonValue,
        'remoteSessionHandle': remoteSessionHandle?.toJson(),
        'vmServiceUri': vmServiceUri?.toString(),
        'launchedAt': launchedAt.toUtc().toIso8601String(),
        'lastReloadAt': lastReloadAt?.toUtc().toIso8601String(),
        'reloadGeneration': reloadGeneration,
      };

  factory CockpitDevelopmentSessionHandle.fromJson(Map<String, Object?> json) {
    final remoteSessionHandleJson =
        json['remoteSessionHandle'] as Map<Object?, Object?>?;
    return CockpitDevelopmentSessionHandle(
      developmentSessionId: json['developmentSessionId']! as String,
      platform: json['platform']! as String,
      deviceId: json['deviceId']! as String,
      projectDir: json['projectDir']! as String,
      target: json['target']! as String,
      appId: json['appId']! as String,
      appBaseUrl: json['appBaseUrl']! as String,
      supervisorBaseUrl: json['supervisorBaseUrl']! as String,
      launchMode: json['launchMode'] == null
          ? CockpitDevelopmentLaunchMode.development
          : CockpitDevelopmentLaunchMode.fromJson(json['launchMode']),
      remoteSessionHandle: remoteSessionHandleJson == null
          ? null
          : CockpitRemoteSessionHandle.fromJson(
              Map<String, Object?>.from(remoteSessionHandleJson),
            ),
      vmServiceUri: json['vmServiceUri'] == null
          ? null
          : Uri.parse(json['vmServiceUri']! as String),
      launchedAt: DateTime.parse(json['launchedAt']! as String).toUtc(),
      lastReloadAt: json['lastReloadAt'] == null
          ? null
          : DateTime.parse(json['lastReloadAt']! as String).toUtc(),
      reloadGeneration: json['reloadGeneration'] as int? ?? 0,
    );
  }

  CockpitDevelopmentSessionHandle copyWith({
    String? developmentSessionId,
    String? platform,
    String? deviceId,
    String? projectDir,
    String? target,
    String? appId,
    String? appBaseUrl,
    String? supervisorBaseUrl,
    CockpitDevelopmentLaunchMode? launchMode,
    CockpitRemoteSessionHandle? remoteSessionHandle,
    Uri? vmServiceUri,
    DateTime? launchedAt,
    DateTime? lastReloadAt,
    int? reloadGeneration,
  }) {
    return CockpitDevelopmentSessionHandle(
      developmentSessionId: developmentSessionId ?? this.developmentSessionId,
      platform: platform ?? this.platform,
      deviceId: deviceId ?? this.deviceId,
      projectDir: projectDir ?? this.projectDir,
      target: target ?? this.target,
      appId: appId ?? this.appId,
      appBaseUrl: appBaseUrl ?? this.appBaseUrl,
      supervisorBaseUrl: supervisorBaseUrl ?? this.supervisorBaseUrl,
      launchMode: launchMode ?? this.launchMode,
      remoteSessionHandle: remoteSessionHandle ?? this.remoteSessionHandle,
      vmServiceUri: vmServiceUri ?? this.vmServiceUri,
      launchedAt: launchedAt ?? this.launchedAt,
      lastReloadAt: lastReloadAt ?? this.lastReloadAt,
      reloadGeneration: reloadGeneration ?? this.reloadGeneration,
    );
  }
}

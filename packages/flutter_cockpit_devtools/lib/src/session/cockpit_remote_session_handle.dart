import 'package:flutter_cockpit/flutter_cockpit.dart';

final class CockpitRemoteSessionHandle {
  const CockpitRemoteSessionHandle({
    required this.platform,
    required this.deviceId,
    required this.projectDir,
    required this.target,
    required this.appId,
    required this.host,
    required this.hostPort,
    required this.devicePort,
    required this.baseUrl,
    required this.launchedAt,
  });

  final String platform;
  final String deviceId;
  final String projectDir;
  final String target;
  final String appId;
  final String host;
  final int hostPort;
  final int devicePort;
  final String baseUrl;
  final DateTime launchedAt;

  Uri get baseUri => Uri.parse(baseUrl);

  Map<String, Object?> toJson() => <String, Object?>{
        'platform': platform,
        'deviceId': deviceId,
        'projectDir': projectDir,
        'target': target,
        'appId': appId,
        'host': host,
        'hostPort': hostPort,
        'devicePort': devicePort,
        'baseUrl': baseUrl,
        'launchedAt': launchedAt.toUtc().toIso8601String(),
      };

  factory CockpitRemoteSessionHandle.fromJson(Map<String, Object?> json) {
    return CockpitRemoteSessionHandle(
      platform: json['platform']! as String,
      deviceId: json['deviceId']! as String,
      projectDir: json['projectDir']! as String,
      target: json['target']! as String,
      appId: json['appId']! as String,
      host: json['host']! as String,
      hostPort: json['hostPort']! as int,
      devicePort: json['devicePort']! as int,
      baseUrl: json['baseUrl']! as String,
      launchedAt: DateTime.parse(json['launchedAt']! as String).toUtc(),
    );
  }

  static CockpitRemoteSessionHandle fromRemoteStatus({
    required String projectDir,
    required String target,
    required String deviceId,
    required String appId,
    required String host,
    required int hostPort,
    required int devicePort,
    required CockpitRemoteSessionStatus status,
    DateTime? launchedAt,
  }) {
    return CockpitRemoteSessionHandle(
      platform: status.platform.toLowerCase(),
      deviceId: deviceId,
      projectDir: projectDir,
      target: target,
      appId: appId,
      host: host,
      hostPort: hostPort,
      devicePort: devicePort,
      baseUrl: Uri(scheme: 'http', host: host, port: hostPort).toString(),
      launchedAt: (launchedAt ?? DateTime.now()).toUtc(),
    );
  }
}

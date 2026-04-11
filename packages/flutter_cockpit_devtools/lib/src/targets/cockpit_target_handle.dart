import 'package:collection/collection.dart';
import 'package:flutter_cockpit/flutter_cockpit.dart';

import '../application/cockpit_app_handle.dart';

final class CockpitTargetConnection {
  const CockpitTargetConnection({required this.baseUrl});

  final String baseUrl;

  Uri get baseUri => Uri.parse(baseUrl);

  Map<String, Object?> toJson() => <String, Object?>{
        'baseUrl': baseUrl,
      };

  factory CockpitTargetConnection.fromJson(Map<String, Object?> json) {
    return CockpitTargetConnection(
      baseUrl: json['baseUrl']! as String,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CockpitTargetConnection && other.baseUrl == baseUrl;
  }

  @override
  int get hashCode => baseUrl.hashCode;
}

final class CockpitTargetHandle {
  CockpitTargetHandle({
    required this.targetId,
    required this.targetKind,
    required this.platform,
    required this.deviceId,
    required this.projectDir,
    required this.target,
    required this.connection,
    required this.launchedAt,
    this.capabilityProfile,
    Map<String, Object?> metadata = const <String, Object?>{},
  }) : metadata = Map.unmodifiable(metadata);

  final String targetId;
  final CockpitTargetKind targetKind;
  final String platform;
  final String deviceId;
  final String projectDir;
  final String target;
  final CockpitTargetConnection connection;
  final DateTime launchedAt;
  final CockpitCapabilityProfile? capabilityProfile;
  final Map<String, Object?> metadata;

  static const MapEquality<String, Object?> _metadataEquality =
      MapEquality<String, Object?>();

  Uri get baseUri => connection.baseUri;

  factory CockpitTargetHandle.fromAppHandle(CockpitAppHandle app) {
    return CockpitTargetHandle(
      targetId: app.appId,
      targetKind: CockpitTargetKind.flutterApp,
      platform: app.platform,
      deviceId: app.deviceId,
      projectDir: app.projectDir,
      target: app.target,
      connection: CockpitTargetConnection(baseUrl: app.baseUrl),
      launchedAt: app.launchedAt,
      metadata: <String, Object?>{
        'appId': app.appId,
        'appMode': app.mode.jsonValue,
        'supportsHotReload': app.supportsHotReload,
        if (app.platformAppId != null) 'platformAppId': app.platformAppId,
        if (app.supervisorLogPath != null)
          'supervisorLogPath': app.supervisorLogPath,
      },
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'targetId': targetId,
        'targetKind': targetKind.name,
        'platform': platform,
        'deviceId': deviceId,
        'projectDir': projectDir,
        'target': target,
        'connection': connection.toJson(),
        'launchedAt': launchedAt.toUtc().toIso8601String(),
        if (capabilityProfile != null)
          'capabilityProfile': capabilityProfile!.toJson(),
        'metadata': metadata,
      };

  factory CockpitTargetHandle.fromJson(Map<String, Object?> json) {
    final connectionJson = json['connection']! as Map<Object?, Object?>;
    final capabilityProfileJson =
        json['capabilityProfile'] as Map<Object?, Object?>?;
    final metadataJson = json['metadata'] as Map<Object?, Object?>?;
    return CockpitTargetHandle(
      targetId: json['targetId']! as String,
      targetKind: CockpitTargetKind.fromJson(json['targetKind']),
      platform: json['platform']! as String,
      deviceId: json['deviceId']! as String,
      projectDir: json['projectDir']! as String,
      target: json['target']! as String,
      connection: CockpitTargetConnection.fromJson(
        Map<String, Object?>.from(connectionJson),
      ),
      launchedAt: DateTime.parse(json['launchedAt']! as String).toUtc(),
      capabilityProfile: capabilityProfileJson == null
          ? null
          : CockpitCapabilityProfile.fromJson(
              Map<String, Object?>.from(capabilityProfileJson),
            ),
      metadata: metadataJson == null
          ? const <String, Object?>{}
          : Map<String, Object?>.from(metadataJson),
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CockpitTargetHandle &&
            other.targetId == targetId &&
            other.targetKind == targetKind &&
            other.platform == platform &&
            other.deviceId == deviceId &&
            other.projectDir == projectDir &&
            other.target == target &&
            other.connection == connection &&
            other.launchedAt == launchedAt &&
            other.capabilityProfile == capabilityProfile &&
            _metadataEquality.equals(other.metadata, metadata);
  }

  @override
  int get hashCode => Object.hash(
        targetId,
        targetKind,
        platform,
        deviceId,
        projectDir,
        target,
        connection,
        launchedAt,
        capabilityProfile,
        _metadataEquality.hash(metadata),
      );
}

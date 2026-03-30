import '../development/cockpit_development_session_handle.dart';
import '../development/cockpit_development_session_status.dart';
import '../session/cockpit_remote_session_handle.dart';
import 'package:flutter_cockpit/flutter_cockpit.dart';

final class CockpitDevelopmentSessionRecord {
  const CockpitDevelopmentSessionRecord({
    required this.handle,
    required this.status,
    required this.updatedAt,
  });

  final CockpitDevelopmentSessionHandle handle;
  final CockpitDevelopmentSessionStatus status;
  final DateTime updatedAt;

  Map<String, Object?> toJson() => <String, Object?>{
        'handle': handle.toJson(),
        'status': status.toJson(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };
}

final class CockpitRemoteSessionRecord {
  const CockpitRemoteSessionRecord({
    required this.handle,
    required this.status,
    required this.recommendedNextStep,
    required this.updatedAt,
  });

  final CockpitRemoteSessionHandle handle;
  final CockpitRemoteSessionStatus status;
  final String recommendedNextStep;
  final DateTime updatedAt;

  Map<String, Object?> toJson() => <String, Object?>{
        'handle': handle.toJson(),
        'status': status.toJson(),
        'recommendedNextStep': recommendedNextStep,
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };
}

final class CockpitActiveSessionsSnapshot {
  const CockpitActiveSessionsSnapshot({
    required this.developmentSessions,
    required this.remoteSessions,
  });

  final List<CockpitDevelopmentSessionRecord> developmentSessions;
  final List<CockpitRemoteSessionRecord> remoteSessions;

  bool get isEmpty =>
      developmentSessions.isEmpty && remoteSessions.isEmpty;

  Map<String, Object?> toJson() => <String, Object?>{
        'developmentSessions': developmentSessions
            .map((record) => record.toJson())
            .toList(growable: false),
        'remoteSessions': remoteSessions
            .map((record) => record.toJson())
            .toList(growable: false),
      };
}

final class CockpitSessionRegistry {
  CockpitSessionRegistry({DateTime Function()? now})
      : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  final Map<String, CockpitDevelopmentSessionRecord> _developmentSessions =
      <String, CockpitDevelopmentSessionRecord>{};
  final Map<String, CockpitRemoteSessionRecord> _remoteSessions =
      <String, CockpitRemoteSessionRecord>{};

  void recordDevelopmentSession({
    required CockpitDevelopmentSessionHandle handle,
    required CockpitDevelopmentSessionStatus status,
  }) {
    _developmentSessions[handle.developmentSessionId] =
        CockpitDevelopmentSessionRecord(
      handle: handle,
      status: status,
      updatedAt: _now().toUtc(),
    );
  }

  void removeDevelopmentSession(String developmentSessionId) {
    _developmentSessions.remove(developmentSessionId);
  }

  void recordRemoteSession({
    required CockpitRemoteSessionHandle handle,
    required CockpitRemoteSessionStatus status,
    required String recommendedNextStep,
  }) {
    _remoteSessions[_remoteSessionKey(handle)] = CockpitRemoteSessionRecord(
      handle: handle,
      status: status,
      recommendedNextStep: recommendedNextStep,
      updatedAt: _now().toUtc(),
    );
  }

  void removeRemoteSession(CockpitRemoteSessionHandle handle) {
    _remoteSessions.remove(_remoteSessionKey(handle));
  }

  CockpitActiveSessionsSnapshot snapshot() => CockpitActiveSessionsSnapshot(
        developmentSessions: _developmentSessions.values
            .toList(growable: false),
        remoteSessions: _remoteSessions.values.toList(growable: false),
      );

  String _remoteSessionKey(CockpitRemoteSessionHandle handle) =>
      '${handle.platform}:${handle.deviceId}:${handle.hostPort}:${handle.appId}';
}

enum CockpitDevelopmentSessionState {
  starting('starting'),
  ready('ready'),
  reloading('reloading'),
  restarting('restarting'),
  stopped('stopped'),
  failed('failed');

  const CockpitDevelopmentSessionState(this.jsonValue);

  final String jsonValue;

  static CockpitDevelopmentSessionState fromJson(Object? json) {
    return values.firstWhere(
      (value) => value.jsonValue == json,
      orElse: () => throw ArgumentError.value(
        json,
        'json',
        'Unsupported development session state.',
      ),
    );
  }
}

enum CockpitDevelopmentReloadMode {
  hotReload('hot_reload'),
  hotRestart('hot_restart');

  const CockpitDevelopmentReloadMode(this.jsonValue);

  final String jsonValue;

  static CockpitDevelopmentReloadMode fromJson(Object? json) {
    return values.firstWhere(
      (value) => value.jsonValue == json,
      orElse: () => throw ArgumentError.value(
        json,
        'json',
        'Unsupported development reload mode.',
      ),
    );
  }
}

final class CockpitDevelopmentSessionStatus {
  const CockpitDevelopmentSessionStatus({
    required this.developmentSessionId,
    required this.state,
    required this.appReachable,
    required this.remoteSessionReachable,
    required this.reloadGeneration,
    required this.lastStatusAt,
    this.lastReloadMode,
    this.lastReloadSucceeded,
    this.lastError,
  });

  final String developmentSessionId;
  final CockpitDevelopmentSessionState state;
  final bool appReachable;
  final bool remoteSessionReachable;
  final int reloadGeneration;
  final CockpitDevelopmentReloadMode? lastReloadMode;
  final bool? lastReloadSucceeded;
  final String? lastError;
  final DateTime lastStatusAt;

  Map<String, Object?> toJson() => <String, Object?>{
        'developmentSessionId': developmentSessionId,
        'state': state.jsonValue,
        'appReachable': appReachable,
        'remoteSessionReachable': remoteSessionReachable,
        'reloadGeneration': reloadGeneration,
        'lastReloadMode': lastReloadMode?.jsonValue,
        'lastReloadSucceeded': lastReloadSucceeded,
        'lastError': lastError,
        'lastStatusAt': lastStatusAt.toUtc().toIso8601String(),
      };

  factory CockpitDevelopmentSessionStatus.fromJson(Map<String, Object?> json) {
    return CockpitDevelopmentSessionStatus(
      developmentSessionId: json['developmentSessionId']! as String,
      state: CockpitDevelopmentSessionState.fromJson(json['state']),
      appReachable: json['appReachable'] as bool? ?? false,
      remoteSessionReachable: json['remoteSessionReachable'] as bool? ?? false,
      reloadGeneration: json['reloadGeneration'] as int? ?? 0,
      lastReloadMode: json['lastReloadMode'] == null
          ? null
          : CockpitDevelopmentReloadMode.fromJson(json['lastReloadMode']),
      lastReloadSucceeded: json['lastReloadSucceeded'] as bool?,
      lastError: json['lastError'] as String?,
      lastStatusAt: DateTime.parse(json['lastStatusAt']! as String).toUtc(),
    );
  }

  CockpitDevelopmentSessionStatus copyWith({
    String? developmentSessionId,
    CockpitDevelopmentSessionState? state,
    bool? appReachable,
    bool? remoteSessionReachable,
    int? reloadGeneration,
    CockpitDevelopmentReloadMode? lastReloadMode,
    bool? lastReloadSucceeded,
    String? lastError,
    DateTime? lastStatusAt,
  }) {
    return CockpitDevelopmentSessionStatus(
      developmentSessionId: developmentSessionId ?? this.developmentSessionId,
      state: state ?? this.state,
      appReachable: appReachable ?? this.appReachable,
      remoteSessionReachable:
          remoteSessionReachable ?? this.remoteSessionReachable,
      reloadGeneration: reloadGeneration ?? this.reloadGeneration,
      lastReloadMode: lastReloadMode ?? this.lastReloadMode,
      lastReloadSucceeded: lastReloadSucceeded ?? this.lastReloadSucceeded,
      lastError: lastError ?? this.lastError,
      lastStatusAt: lastStatusAt ?? this.lastStatusAt,
    );
  }
}

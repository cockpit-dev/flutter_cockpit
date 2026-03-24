enum CockpitDevelopmentProbeProfile {
  quick('quick'),
  interactive('interactive'),
  diagnostic('diagnostic'),
  forensic('forensic');

  const CockpitDevelopmentProbeProfile(this.jsonValue);

  final String jsonValue;

  static CockpitDevelopmentProbeProfile fromJson(Object? json) {
    return values.firstWhere(
      (value) => value.jsonValue == json,
      orElse: () => throw ArgumentError.value(
        json,
        'json',
        'Unsupported development probe profile.',
      ),
    );
  }
}

enum CockpitDevelopmentProbeReason {
  manual('manual'),
  postReload('post_reload'),
  postAction('post_action'),
  failure('failure');

  const CockpitDevelopmentProbeReason(this.jsonValue);

  final String jsonValue;

  static CockpitDevelopmentProbeReason fromJson(Object? json) {
    return values.firstWhere(
      (value) => value.jsonValue == json,
      orElse: () => throw ArgumentError.value(
        json,
        'json',
        'Unsupported development probe reason.',
      ),
    );
  }
}

final class CockpitDevelopmentProbe {
  const CockpitDevelopmentProbe({
    required this.probeId,
    required this.sessionId,
    required this.reloadGeneration,
    required this.capturedAt,
    required this.reason,
    required this.profile,
    required this.routeName,
    this.checkpoint,
    this.ui = const <String, Object?>{},
    this.network = const <String, Object?>{},
    this.runtime = const <String, Object?>{},
    this.rebuild = const <String, Object?>{},
    this.artifacts = const <String, Object?>{},
  });

  final String probeId;
  final String sessionId;
  final int reloadGeneration;
  final DateTime capturedAt;
  final CockpitDevelopmentProbeReason reason;
  final String? checkpoint;
  final CockpitDevelopmentProbeProfile profile;
  final String routeName;
  final Map<String, Object?> ui;
  final Map<String, Object?> network;
  final Map<String, Object?> runtime;
  final Map<String, Object?> rebuild;
  final Map<String, Object?> artifacts;

  Map<String, Object?> toJson() => <String, Object?>{
        'probeId': probeId,
        'sessionId': sessionId,
        'reloadGeneration': reloadGeneration,
        'capturedAt': capturedAt.toUtc().toIso8601String(),
        'reason': reason.jsonValue,
        'checkpoint': checkpoint,
        'profile': profile.jsonValue,
        'routeName': routeName,
        'ui': ui,
        'network': network,
        'runtime': runtime,
        'rebuild': rebuild,
        'artifacts': artifacts,
      };

  factory CockpitDevelopmentProbe.fromJson(Map<String, Object?> json) {
    return CockpitDevelopmentProbe(
      probeId: json['probeId']! as String,
      sessionId: json['sessionId']! as String,
      reloadGeneration: json['reloadGeneration'] as int? ?? 0,
      capturedAt: DateTime.parse(json['capturedAt']! as String).toUtc(),
      reason: CockpitDevelopmentProbeReason.fromJson(json['reason']),
      checkpoint: json['checkpoint'] as String?,
      profile: CockpitDevelopmentProbeProfile.fromJson(json['profile']),
      routeName: json['routeName']! as String,
      ui: _readMap(json['ui']),
      network: _readMap(json['network']),
      runtime: _readMap(json['runtime']),
      rebuild: _readMap(json['rebuild']),
      artifacts: _readMap(json['artifacts']),
    );
  }

  static Map<String, Object?> _readMap(Object? json) {
    final map = json as Map<Object?, Object?>?;
    if (map == null) {
      return const <String, Object?>{};
    }
    return Map<String, Object?>.from(map);
  }
}

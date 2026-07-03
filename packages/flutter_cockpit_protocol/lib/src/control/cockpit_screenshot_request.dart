import '../runtime/cockpit_snapshot_options.dart';

enum CockpitScreenshotReason {
  baseline('baseline'),
  beforeAction('before_action'),
  afterAction('after_action'),
  assertionFailure('assertion_failure'),
  acceptance('acceptance');

  const CockpitScreenshotReason(this.jsonValue);

  final String jsonValue;

  static CockpitScreenshotReason fromJson(Object? json) {
    return values.firstWhere(
      (reason) => reason.jsonValue == json,
      orElse: () => throw ArgumentError.value(
        json,
        'json',
        'Unsupported screenshot reason.',
      ),
    );
  }
}

final class CockpitScreenshotRequest {
  const CockpitScreenshotRequest({
    required this.reason,
    required this.name,
    this.includeSnapshot = false,
    this.attachToStep = false,
    this.snapshotOptions,
  });

  final CockpitScreenshotReason reason;
  final String name;
  final bool includeSnapshot;
  final bool attachToStep;
  final CockpitSnapshotOptions? snapshotOptions;

  Map<String, Object?> toJson() => {
    'reason': reason.jsonValue,
    'name': name,
    'includeSnapshot': includeSnapshot,
    'attachToStep': attachToStep,
    if (snapshotOptions != null) 'snapshotOptions': snapshotOptions!.toJson(),
  };

  factory CockpitScreenshotRequest.fromJson(Map<String, Object?> json) {
    final snapshotOptionsJson =
        json['snapshotOptions'] as Map<Object?, Object?>?;
    return CockpitScreenshotRequest(
      reason: CockpitScreenshotReason.fromJson(json['reason']),
      name: json['name']! as String,
      includeSnapshot: json['includeSnapshot'] as bool? ?? false,
      attachToStep: json['attachToStep'] as bool? ?? false,
      snapshotOptions: snapshotOptionsJson == null
          ? null
          : CockpitSnapshotOptions.fromJson(
              Map<String, Object?>.from(snapshotOptionsJson),
            ),
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CockpitScreenshotRequest &&
            other.reason == reason &&
            other.name == name &&
            other.includeSnapshot == includeSnapshot &&
            other.attachToStep == attachToStep &&
            other.snapshotOptions == snapshotOptions;
  }

  @override
  int get hashCode =>
      Object.hash(reason, name, includeSnapshot, attachToStep, snapshotOptions);

  CockpitScreenshotRequest copyWith({
    CockpitScreenshotReason? reason,
    String? name,
    bool? includeSnapshot,
    bool? attachToStep,
    CockpitSnapshotOptions? snapshotOptions,
  }) {
    return CockpitScreenshotRequest(
      reason: reason ?? this.reason,
      name: name ?? this.name,
      includeSnapshot: includeSnapshot ?? this.includeSnapshot,
      attachToStep: attachToStep ?? this.attachToStep,
      snapshotOptions: snapshotOptions ?? this.snapshotOptions,
    );
  }
}

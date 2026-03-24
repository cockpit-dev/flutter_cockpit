import 'package:collection/collection.dart';

import 'cockpit_recording_kind.dart';

final class CockpitRecordingCapabilities {
  CockpitRecordingCapabilities({
    required this.supportsNativeRecording,
    this.preferredAcceptanceRecordingKind,
    List<String> recordingLimitations = const <String>[],
  }) : recordingLimitations = List.unmodifiable(recordingLimitations);

  final bool supportsNativeRecording;
  final CockpitRecordingKind? preferredAcceptanceRecordingKind;
  final List<String> recordingLimitations;

  static const ListEquality<String> _stringListEquality =
      ListEquality<String>();

  Map<String, Object?> toJson() => {
        'supportsNativeRecording': supportsNativeRecording,
        'preferredAcceptanceRecordingKind':
            preferredAcceptanceRecordingKind?.name,
        'recordingLimitations': recordingLimitations,
      };

  factory CockpitRecordingCapabilities.fromJson(Map<String, Object?> json) {
    final preferredKind = json['preferredAcceptanceRecordingKind'];

    return CockpitRecordingCapabilities(
      supportsNativeRecording:
          json['supportsNativeRecording'] as bool? ?? false,
      preferredAcceptanceRecordingKind: preferredKind == null
          ? null
          : CockpitRecordingKind.fromJson(preferredKind),
      recordingLimitations:
          (json['recordingLimitations'] as List<Object?>? ?? const <Object?>[])
              .cast<String>(),
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CockpitRecordingCapabilities &&
            other.supportsNativeRecording == supportsNativeRecording &&
            other.preferredAcceptanceRecordingKind ==
                preferredAcceptanceRecordingKind &&
            _stringListEquality.equals(
              other.recordingLimitations,
              recordingLimitations,
            );
  }

  @override
  int get hashCode => Object.hash(
        supportsNativeRecording,
        preferredAcceptanceRecordingKind,
        _stringListEquality.hash(recordingLimitations),
      );
}

import 'package:collection/collection.dart';

import '../model/cockpit_artifact_ref.dart';
import 'cockpit_recording_kind.dart';
import 'cockpit_recording_purpose.dart';
import 'cockpit_recording_state.dart';

final class CockpitRecordingResult {
  CockpitRecordingResult({
    required this.state,
    this.purpose,
    this.recordingKind,
    this.artifact,
    this.durationMs,
    List<int>? bytes,
    this.sourceFilePath,
    this.failureReason,
  }) : bytes = bytes == null ? null : List.unmodifiable(bytes);

  final CockpitRecordingState state;
  final CockpitRecordingPurpose? purpose;
  final CockpitRecordingKind? recordingKind;
  final CockpitArtifactRef? artifact;
  final int? durationMs;
  final List<int>? bytes;
  final String? sourceFilePath;
  final String? failureReason;

  static const ListEquality<int> _byteEquality = ListEquality<int>();

  Map<String, Object?> toJson() => {
        'state': state.name,
        if (purpose != null) 'purpose': purpose!.name,
        if (recordingKind != null) 'recordingKind': recordingKind!.name,
        if (artifact != null) 'artifact': artifact!.toJson(),
        if (durationMs != null) 'durationMs': durationMs,
        if (bytes != null) 'bytes': bytes,
        if (sourceFilePath != null) 'sourceFilePath': sourceFilePath,
        if (failureReason != null) 'failureReason': failureReason,
      };

  factory CockpitRecordingResult.fromJson(Map<String, Object?> json) {
    final artifactJson = json['artifact'] as Map<Object?, Object?>?;
    return CockpitRecordingResult(
      state: CockpitRecordingState.fromJson(json['state']),
      purpose: json['purpose'] == null
          ? null
          : CockpitRecordingPurpose.fromJson(json['purpose']),
      recordingKind: json['recordingKind'] == null
          ? null
          : CockpitRecordingKind.fromJson(json['recordingKind']),
      artifact: artifactJson == null
          ? null
          : CockpitArtifactRef.fromJson(
              Map<String, Object?>.from(artifactJson),
            ),
      durationMs: json['durationMs'] as int?,
      bytes: (json['bytes'] as List<Object?>?)?.cast<int>(),
      sourceFilePath: json['sourceFilePath'] as String?,
      failureReason: json['failureReason'] as String?,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CockpitRecordingResult &&
            other.state == state &&
            other.purpose == purpose &&
            other.recordingKind == recordingKind &&
            other.artifact == artifact &&
            other.durationMs == durationMs &&
            _byteEquality.equals(other.bytes, bytes) &&
            other.sourceFilePath == sourceFilePath &&
            other.failureReason == failureReason;
  }

  @override
  int get hashCode => Object.hash(
        state,
        purpose,
        recordingKind,
        artifact,
        durationMs,
        bytes == null ? null : _byteEquality.hash(bytes!),
        sourceFilePath,
        failureReason,
      );
}

import 'dart:io';

import 'package:flutter_cockpit/flutter_cockpit.dart';

import 'cockpit_interactive_result_data.dart';

final class CockpitRecordingEvidenceAssessment {
  const CockpitRecordingEvidenceAssessment({
    required this.state,
    this.artifact,
    this.failureReason,
  });

  final CockpitRecordingState state;
  final CockpitInteractiveArtifactDescriptor? artifact;
  final String? failureReason;
}

CockpitRecordingEvidenceAssessment cockpitAssessRecordingEvidence(
  CockpitRecordingResult recordingResult,
) {
  final artifactRef = recordingResult.artifact;
  final artifactEvidence = _artifactEvidenceFor(recordingResult);
  final evidenceFailure = _evidenceFailureFor(
    recordingResult: recordingResult,
    artifactEvidence: artifactEvidence,
  );
  final shouldFailCompletedRecording =
      recordingResult.state == CockpitRecordingState.completed &&
      evidenceFailure != null;

  return CockpitRecordingEvidenceAssessment(
    state: shouldFailCompletedRecording
        ? CockpitRecordingState.failed
        : recordingResult.state,
    artifact: artifactRef == null
        ? null
        : CockpitInteractiveArtifactDescriptor(
            role: artifactRef.role,
            relativePath: artifactRef.relativePath,
            byteLength: artifactEvidence.byteLength,
            sourcePath: artifactEvidence.sourcePath,
          ),
    failureReason: _combinedFailureReason(
      existing: recordingResult.failureReason,
      evidenceFailure: evidenceFailure,
    ),
  );
}

_CockpitRecordingArtifactEvidence _artifactEvidenceFor(
  CockpitRecordingResult recordingResult,
) {
  final bytes = recordingResult.bytes;
  if (bytes != null) {
    return _CockpitRecordingArtifactEvidence(
      byteLength: bytes.length,
      sourcePath: _nonEmptyString(recordingResult.sourceFilePath),
      failureReason: bytes.isEmpty
          ? 'Recording artifact bytes are empty.'
          : null,
    );
  }

  final sourceFilePath = _nonEmptyString(recordingResult.sourceFilePath);
  if (sourceFilePath == null) {
    return const _CockpitRecordingArtifactEvidence(
      failureReason:
          'Recording completed without artifact bytes or a source file.',
    );
  }

  try {
    final file = File(sourceFilePath);
    if (!file.existsSync()) {
      return _CockpitRecordingArtifactEvidence(
        sourcePath: sourceFilePath,
        failureReason: 'Recording artifact source file does not exist.',
      );
    }
    final byteLength = file.lengthSync();
    return _CockpitRecordingArtifactEvidence(
      byteLength: byteLength,
      sourcePath: sourceFilePath,
      failureReason: byteLength == 0
          ? 'Recording artifact source file is empty.'
          : null,
    );
  } on Object catch (error) {
    return _CockpitRecordingArtifactEvidence(
      sourcePath: sourceFilePath,
      failureReason:
          'Recording artifact source file could not be inspected: '
          '$error',
    );
  }
}

String? _evidenceFailureFor({
  required CockpitRecordingResult recordingResult,
  required _CockpitRecordingArtifactEvidence artifactEvidence,
}) {
  if (recordingResult.artifact == null) {
    return recordingResult.state == CockpitRecordingState.completed
        ? 'Recording completed without an artifact reference.'
        : null;
  }
  return artifactEvidence.failureReason;
}

String? _combinedFailureReason({
  required String? existing,
  required String? evidenceFailure,
}) {
  if (evidenceFailure == null || evidenceFailure.isEmpty) {
    return existing;
  }
  if (existing == null || existing.isEmpty) {
    return evidenceFailure;
  }
  if (existing.contains(evidenceFailure)) {
    return existing;
  }
  return '$existing $evidenceFailure';
}

String? _nonEmptyString(String? value) {
  if (value == null || value.isEmpty) {
    return null;
  }
  return value;
}

final class _CockpitRecordingArtifactEvidence {
  const _CockpitRecordingArtifactEvidence({
    this.byteLength,
    this.sourcePath,
    this.failureReason,
  });

  final int? byteLength;
  final String? sourcePath;
  final String? failureReason;
}

import 'dart:convert';
import 'dart:io';

import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:path/path.dart' as p;

import 'cockpit_bundle_artifact_paths.dart';
import 'cockpit_bundle_diagnostics_artifact_refs.dart';

final class CockpitIssueEvidenceBuilder {
  const CockpitIssueEvidenceBuilder();

  Future<Map<String, Object?>> buildFromBundleDir({
    required String bundleDir,
    required CockpitRunManifest manifest,
    required Map<String, Object?> handoff,
    required Map<String, Object?> delivery,
    required CockpitBundleArtifactPaths artifactPaths,
    required List<String> diagnosticsArtifactPaths,
    Map<String, Object?>? gateSummary,
  }) async {
    final steps = await _readSteps(bundleDir);
    final snapshots = await _readSnapshots(
      bundleDir: bundleDir,
      steps: steps,
      diagnosticsArtifactPaths: diagnosticsArtifactPaths,
    );
    return build(
      bundleDir: bundleDir,
      manifest: manifest,
      handoff: handoff,
      delivery: delivery,
      artifactPaths: artifactPaths,
      diagnosticsArtifactPaths: diagnosticsArtifactPaths,
      steps: steps,
      snapshots: snapshots,
      gateSummary: gateSummary,
    );
  }

  Map<String, Object?> build({
    required String bundleDir,
    required CockpitRunManifest manifest,
    required Map<String, Object?> handoff,
    required Map<String, Object?> delivery,
    required CockpitBundleArtifactPaths artifactPaths,
    required List<String> diagnosticsArtifactPaths,
    required List<CockpitStepRecord> steps,
    required List<CockpitSnapshot> snapshots,
    Map<String, Object?>? gateSummary,
  }) {
    final failedCommands = _failedCommands(bundleDir: bundleDir, steps: steps);
    final runtimeIssues = _runtimeIssues(steps: steps, snapshots: snapshots);
    final networkIssues = _networkIssues(snapshots);
    final gateFailures = _gateFailures(
      handoff: handoff,
      gateSummary: gateSummary,
    );
    final deliveryVideoFailureCodes = _deliveryVideoFailureCodes(
      manifest: manifest,
      handoff: handoff,
      delivery: delivery,
      artifactPaths: artifactPaths,
      steps: steps,
    );
    final effectiveGateFailures = <Map<String, Object?>>[
      ...gateFailures,
      if (deliveryVideoFailureCodes.isNotEmpty &&
          !gateFailures.any(
            (failure) => failure['gate'] == 'recordingReadyOrExplained',
          ))
        <String, Object?>{
          'gate': 'recordingReadyOrExplained',
          'failureCodes': deliveryVideoFailureCodes,
        },
    ];
    final artifactIssues = _artifactIssues(
      bundleDir: bundleDir,
      manifest: manifest,
      handoff: handoff,
      delivery: delivery,
      artifactPaths: artifactPaths,
      diagnosticsArtifactPaths: diagnosticsArtifactPaths,
      steps: steps,
    );
    final issueKinds = <String>[
      if (failedCommands.isNotEmpty) 'commandFailure',
      if (runtimeIssues.isNotEmpty) 'runtimeError',
      if (networkIssues.isNotEmpty) 'networkFailure',
      if (effectiveGateFailures.isNotEmpty) 'gateFailure',
      if (artifactIssues.isNotEmpty) 'artifactIssue',
    ];
    final recommendedNextStep = _recommendedNextStep(
      failedCommands: failedCommands,
      runtimeIssues: runtimeIssues,
      networkIssues: networkIssues,
      artifactIssues: artifactIssues,
      gateFailures: effectiveGateFailures,
      status: manifest.status.name,
    );

    return <String, Object?>{
      'schemaVersion': 1,
      'bundleDir': bundleDir,
      'sessionId': manifest.sessionId,
      'taskId': manifest.taskId,
      'platform': manifest.platform,
      'status': manifest.status.name,
      if (manifest.failureSummary != null)
        'failureSummary': manifest.failureSummary,
      'recommendedNextStep': recommendedNextStep,
      'issueKinds': issueKinds,
      'counts': <String, Object?>{
        'commandCount': manifest.commandCount,
        'failureCount': manifest.failureCount,
        'runtimeErrorCount': manifest.runtimeErrorCount,
        'runtimeWarningCount': manifest.runtimeWarningCount,
        'screenshotCount': manifest.screenshotCount,
        'recordingCount': manifest.recordingCount,
        'diagnosticsArtifactCount': diagnosticsArtifactPaths.length,
        'failedCommandCount': failedCommands.length,
        'runtimeIssueCount': runtimeIssues.length,
        'networkIssueCount': networkIssues.length,
        'artifactIssueCount': artifactIssues.length,
      },
      'failedCommands': failedCommands,
      'runtimeIssues': runtimeIssues,
      'networkIssues': networkIssues,
      'artifactIssues': artifactIssues,
      'gateFailures': effectiveGateFailures,
      'evidencePaths': <String, Object?>{
        if (artifactPaths.primaryScreenshotPath != null)
          'primaryScreenshotPath': artifactPaths.primaryScreenshotPath,
        if (artifactPaths.primaryRecordingPath != null)
          'primaryRecordingPath': artifactPaths.primaryRecordingPath,
        'attachmentPaths': artifactPaths.attachmentPaths,
        'videoAttachmentPaths': artifactPaths.videoAttachmentPaths,
        'keyframePaths': artifactPaths.keyframePaths,
        'diagnosticsArtifactPaths': diagnosticsArtifactPaths,
      },
    };
  }

  Future<List<CockpitStepRecord>> _readSteps(String bundleDir) async {
    final file = File(p.join(bundleDir, 'steps.json'));
    if (!file.existsSync()) {
      return const <CockpitStepRecord>[];
    }
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! List<Object?>) {
      return const <CockpitStepRecord>[];
    }
    return decoded
        .whereType<Map<Object?, Object?>>()
        .map(
          (item) => CockpitStepRecord.fromJson(Map<String, Object?>.from(item)),
        )
        .toList(growable: false);
  }

  Future<List<CockpitSnapshot>> _readSnapshots({
    required String bundleDir,
    required List<CockpitStepRecord> steps,
    required List<String> diagnosticsArtifactPaths,
  }) async {
    final snapshots = <CockpitSnapshot>[];
    final diagnosticPaths = <String>{...diagnosticsArtifactPaths};
    for (final step in steps) {
      if (step.snapshot case final snapshot?) {
        snapshots.add(snapshot);
        final ref = snapshot.diagnosticsArtifactRef;
        if (ref != null) {
          final resolved = CockpitBundleDiagnosticsArtifactRefs.resolvePath(
            bundleDir,
            ref.relativePath,
          );
          if (resolved != null) {
            diagnosticPaths.add(resolved);
          }
        }
      }
      for (final artifact in step.artifactRefs) {
        if (artifact.role != 'diagnostics') {
          continue;
        }
        final resolved = CockpitBundleDiagnosticsArtifactRefs.resolvePath(
          bundleDir,
          artifact.relativePath,
        );
        if (resolved != null) {
          diagnosticPaths.add(resolved);
        }
      }
    }
    for (final path in diagnosticPaths) {
      final snapshot = await _readDiagnosticSnapshot(path);
      if (snapshot != null) {
        snapshots.add(snapshot);
      }
    }
    return snapshots;
  }

  Future<CockpitSnapshot?> _readDiagnosticSnapshot(String path) async {
    final file = File(path);
    if (!file.existsSync()) {
      return null;
    }
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<Object?, Object?>) {
        return null;
      }
      return CockpitSnapshot.fromJson(Map<String, Object?>.from(decoded));
    } on FormatException {
      return null;
    } on IOException {
      return null;
    } on ArgumentError {
      return null;
    } on TypeError {
      return null;
    }
  }

  List<Map<String, Object?>> _failedCommands({
    required String bundleDir,
    required List<CockpitStepRecord> steps,
  }) {
    return steps
        .where(
          (step) =>
              step.commandType != null &&
              (step.status == CockpitCommandStatus.failed ||
                  step.commandError != null),
        )
        .map((step) => _failedCommand(bundleDir: bundleDir, step: step))
        .take(8)
        .toList(growable: false);
  }

  Map<String, Object?> _failedCommand({
    required String bundleDir,
    required CockpitStepRecord step,
  }) {
    final error = step.commandError;
    final failureDiagnostics = _readMap(error?.details['failureDiagnostics']);
    final routeName =
        _readString(failureDiagnostics?['routeName']) ??
        step.observation?.routeName ??
        step.snapshot?.routeName;
    final expectedRouteName =
        _readString(failureDiagnostics?['expectedRouteName']) ??
        _readString(step.actionArgs['expectedRouteName']);
    final diagnosticsArtifactPath = _diagnosticsArtifactPathForStep(
      bundleDir: bundleDir,
      step: step,
    );
    return <String, Object?>{
      'stepIndex': step.index,
      'actionType': step.actionType,
      if (step.actionArgs['commandId'] != null)
        'commandId': step.actionArgs['commandId'],
      if (step.commandType != null) 'commandType': step.commandType!.name,
      if (step.durationMs != null) 'durationMs': step.durationMs,
      'routeName': ?routeName,
      'expectedRouteName': ?expectedRouteName,
      if (step.locator != null) 'locator': step.locator!.toJson(),
      if (step.locatorResolution != null)
        'locatorResolution': step.locatorResolution!.toJson(),
      if (error != null) 'errorCode': error.code,
      if (error != null) 'errorMessage': error.message,
      'failureDiagnostics': ?failureDiagnostics,
      'diagnosticsArtifactPath': ?diagnosticsArtifactPath,
      'artifactRefs': step.artifactRefs
          .map((artifact) => artifact.relativePath)
          .toList(growable: false),
      if (step.captureRefs.isNotEmpty)
        'captureRefs': step.captureRefs
            .map((artifact) => artifact.relativePath)
            .toList(growable: false),
    };
  }

  String? _diagnosticsArtifactPathForStep({
    required String bundleDir,
    required CockpitStepRecord step,
  }) {
    final refs = <CockpitArtifactRef>[
      if (step.snapshot?.diagnosticsArtifactRef != null)
        step.snapshot!.diagnosticsArtifactRef!,
      ...step.artifactRefs.where((artifact) => artifact.role == 'diagnostics'),
    ];
    for (final ref in refs) {
      final resolved = CockpitBundleDiagnosticsArtifactRefs.resolvePath(
        bundleDir,
        ref.relativePath,
      );
      if (resolved != null) {
        return resolved;
      }
    }
    return null;
  }

  List<Map<String, Object?>> _runtimeIssues({
    required List<CockpitStepRecord> steps,
    required List<CockpitSnapshot> snapshots,
  }) {
    final issues = <String, CockpitRuntimeEvent>{};
    for (final step in steps) {
      final event = _runtimeEventFromStep(step);
      if (event != null && event.isError) {
        issues[event.eventId] = event;
      }
    }
    for (final snapshot in snapshots) {
      for (final event
          in snapshot.runtime?.entries ?? <CockpitRuntimeEvent>[]) {
        if (event.isError) {
          issues[event.eventId] = event;
        }
      }
    }
    final ordered = issues.values.toList(growable: true)
      ..sort((left, right) => right.recordedAt.compareTo(left.recordedAt));
    return ordered
        .take(5)
        .map(
          (event) => <String, Object?>{
            'eventId': event.eventId,
            'kind': event.kind.jsonValue,
            'severity': event.severity.jsonValue,
            'message': event.message,
            if (event.routeName != null) 'routeName': event.routeName,
            'recordedAt': event.recordedAt.toUtc().toIso8601String(),
          },
        )
        .toList(growable: false);
  }

  CockpitRuntimeEvent? _runtimeEventFromStep(CockpitStepRecord step) {
    final eventId = step.actionArgs['eventId'] as String?;
    final kind = step.actionArgs['kind'];
    final severity = step.actionArgs['severity'];
    final message = step.actionArgs['message'] as String?;
    if (eventId == null ||
        kind == null ||
        severity == null ||
        message == null) {
      return null;
    }
    final recordedAt = DateTime.tryParse(
      step.actionArgs['recordedAt'] as String? ?? '',
    );
    return CockpitRuntimeEvent(
      eventId: eventId,
      kind: CockpitRuntimeEventKind.fromJson(kind),
      severity: CockpitRuntimeEventSeverity.fromJson(severity),
      message: message,
      recordedAt: recordedAt ?? step.observedAt,
      routeName: step.actionArgs['routeName'] as String?,
    );
  }

  List<Map<String, Object?>> _networkIssues(List<CockpitSnapshot> snapshots) {
    final issues = <String, CockpitNetworkEntry>{};
    for (final snapshot in snapshots) {
      for (final entry
          in snapshot.network?.entries ?? <CockpitNetworkEntry>[]) {
        if (entry.isFailure) {
          issues[entry.requestId] = entry;
        }
      }
    }
    final ordered = issues.values.toList(growable: true)
      ..sort((left, right) => right.startedAt.compareTo(left.startedAt));
    return ordered
        .take(5)
        .map(
          (entry) => <String, Object?>{
            'requestId': entry.requestId,
            'method': entry.method,
            'uri': entry.uri,
            if (entry.statusCode != null) 'statusCode': entry.statusCode,
            if (entry.error != null) 'error': entry.error,
            'durationMs': entry.durationMs,
          },
        )
        .toList(growable: false);
  }

  List<Map<String, Object?>> _artifactIssues({
    required String bundleDir,
    required CockpitRunManifest manifest,
    required Map<String, Object?> handoff,
    required Map<String, Object?> delivery,
    required CockpitBundleArtifactPaths artifactPaths,
    required List<String> diagnosticsArtifactPaths,
    required List<CockpitStepRecord> steps,
  }) {
    final issues = <Map<String, Object?>>[];
    final videoEvidenceRequired = _videoEvidenceRequired(
      manifest: manifest,
      handoff: handoff,
      delivery: delivery,
      artifactPaths: artifactPaths,
      steps: steps,
    );
    for (final code in <String>{
      ...manifest.deliveryArtifactFailureCodes,
      ..._readStringList(delivery['artifactFailureCodes']),
      if (videoEvidenceRequired)
        ..._actionableVideoFailureCodes(manifest.deliveryVideoFailureCodes),
      if (videoEvidenceRequired)
        ..._actionableVideoFailureCodes(
          _readStringList(delivery['videoFailureCodes']),
        ),
    }) {
      issues.add(<String, Object?>{'code': code});
    }
    for (final issue in _deliveryAttachmentIssues(
      bundleDir: bundleDir,
      delivery: delivery,
    )) {
      issues.add(issue);
    }
    for (final issue in _manifestArtifactIssues(
      bundleDir: bundleDir,
      manifest: manifest,
    )) {
      issues.add(issue);
    }
    final primaryScreenshotPath = artifactPaths.primaryScreenshotPath;
    if (primaryScreenshotPath != null &&
        primaryScreenshotPath.isNotEmpty &&
        !File(primaryScreenshotPath).existsSync()) {
      issues.add(<String, Object?>{
        'code': 'primaryScreenshotMissing',
        'path': primaryScreenshotPath,
      });
    }
    final primaryRecordingPath = artifactPaths.primaryRecordingPath;
    if (primaryRecordingPath != null &&
        primaryRecordingPath.isNotEmpty &&
        !File(primaryRecordingPath).existsSync()) {
      issues.add(<String, Object?>{
        'code': 'primaryRecordingMissing',
        'path': primaryRecordingPath,
      });
    }
    for (final path in diagnosticsArtifactPaths) {
      final file = File(path);
      if (!file.existsSync()) {
        issues.add(<String, Object?>{
          'code': 'diagnosticsArtifactMissing',
          'path': path,
        });
        continue;
      }
      if (!_isReadableDiagnosticSnapshot(file)) {
        issues.add(<String, Object?>{
          'code': 'diagnosticsArtifactUnreadable',
          'path': path,
        });
      }
    }
    return issues.take(8).toList(growable: false);
  }

  List<String> _deliveryVideoFailureCodes({
    required CockpitRunManifest manifest,
    required Map<String, Object?> handoff,
    required Map<String, Object?> delivery,
    required CockpitBundleArtifactPaths artifactPaths,
    required List<CockpitStepRecord> steps,
  }) {
    if (!_videoEvidenceRequired(
      manifest: manifest,
      handoff: handoff,
      delivery: delivery,
      artifactPaths: artifactPaths,
      steps: steps,
    )) {
      return const <String>[];
    }
    if (manifest.deliveryVideoReady &&
        manifest.deliveryVideoFailureCodes.isEmpty) {
      return const <String>[];
    }
    final readiness = _readMap(delivery['readiness']);
    final videoReadiness = _readMap(readiness?['video']);
    final failureReason =
        _readString(handoff['recordingFailureReason']) ??
        _readString(videoReadiness?['failureReason']);
    if (failureReason != null) {
      return const <String>['recordingFailed'];
    }
    final manifestVideoFailureCodes = _actionableVideoFailureCodes(
      manifest.deliveryVideoFailureCodes,
    );
    if (manifestVideoFailureCodes.isNotEmpty) {
      return manifestVideoFailureCodes;
    }
    final deliveryVideoFailureCodes = _actionableVideoFailureCodes(
      _readStringList(delivery['videoFailureCodes']),
    );
    if (deliveryVideoFailureCodes.isNotEmpty) {
      return deliveryVideoFailureCodes;
    }
    final primaryRecordingRef = delivery['primaryRecordingRef'] as String?;
    if (primaryRecordingRef == null || primaryRecordingRef.isEmpty) {
      return const <String>['primaryRecordingMissing'];
    }
    final primaryRecordingPath = artifactPaths.primaryRecordingPath;
    if (primaryRecordingPath == null ||
        !File(primaryRecordingPath).existsSync()) {
      return const <String>['acceptanceRecordingMissing'];
    }
    return const <String>[];
  }

  bool _videoEvidenceRequired({
    required CockpitRunManifest manifest,
    required Map<String, Object?> handoff,
    required Map<String, Object?> delivery,
    required CockpitBundleArtifactPaths artifactPaths,
    required List<CockpitStepRecord> steps,
  }) {
    final primaryRecordingRef = delivery['primaryRecordingRef'] as String?;
    final readiness = _readMap(delivery['readiness']);
    final videoReadiness = _readMap(readiness?['video']);
    final failureReason =
        _readString(handoff['recordingFailureReason']) ??
        _readString(videoReadiness?['failureReason']);
    final deliveryVideoFailureCodes = _readStringList(
      delivery['videoFailureCodes'],
    );
    return manifest.deliveryVideoReady ||
        manifest.recordingCount > 0 ||
        steps.any((step) => step.actionType.startsWith('recording_')) ||
        _hasActionableVideoFailureCodes(manifest.deliveryVideoFailureCodes) ||
        artifactPaths.primaryRecordingPath != null ||
        artifactPaths.videoAttachmentPaths.isNotEmpty ||
        (primaryRecordingRef != null && primaryRecordingRef.isNotEmpty) ||
        _readStringList(delivery['videoAttachmentRefs']).isNotEmpty ||
        _hasActionableVideoFailureCodes(deliveryVideoFailureCodes) ||
        failureReason != null;
  }

  bool _hasActionableVideoFailureCodes(List<String> failureCodes) {
    return failureCodes.any((code) => code != 'primaryRecordingMissing');
  }

  List<String> _actionableVideoFailureCodes(List<String> failureCodes) {
    return failureCodes
        .where((code) => code != 'primaryRecordingMissing')
        .toList(growable: false);
  }

  Iterable<Map<String, Object?>> _deliveryAttachmentIssues({
    required String bundleDir,
    required Map<String, Object?> delivery,
  }) sync* {
    for (final ref in _readStringList(delivery['attachmentRefs'])) {
      final resolved = CockpitBundleArtifactPaths.resolveBundleArtifactPath(
        bundleDir,
        ref,
        allowedRoots: const <String>{'screenshots'},
      );
      if (resolved == null) {
        yield <String, Object?>{
          'code': 'deliveryAttachmentRefInvalid',
          'ref': ref,
        };
        continue;
      }
      if (!File(resolved).existsSync()) {
        yield <String, Object?>{
          'code': 'deliveryAttachmentMissing',
          'ref': ref,
          'path': resolved,
        };
      }
    }
    for (final ref in _readStringList(delivery['videoAttachmentRefs'])) {
      final resolved = CockpitBundleArtifactPaths.resolveBundleArtifactPath(
        bundleDir,
        ref,
        allowedRoots: const <String>{'recordings'},
      );
      if (resolved == null) {
        yield <String, Object?>{
          'code': 'deliveryVideoAttachmentRefInvalid',
          'ref': ref,
        };
        continue;
      }
      if (!File(resolved).existsSync()) {
        yield <String, Object?>{
          'code': 'deliveryVideoAttachmentMissing',
          'ref': ref,
          'path': resolved,
        };
      }
    }
  }

  Iterable<Map<String, Object?>> _manifestArtifactIssues({
    required String bundleDir,
    required CockpitRunManifest manifest,
  }) sync* {
    for (final artifact in manifest.artifactRefs) {
      final allowedRoots =
          CockpitBundleArtifactPaths.allowedRootsForArtifactRole(artifact.role);
      final resolved = CockpitBundleArtifactPaths.resolveBundleArtifactPath(
        bundleDir,
        artifact.relativePath,
        allowedRoots: allowedRoots,
      );
      if (resolved == null) {
        yield <String, Object?>{
          'code': 'manifestArtifactRefInvalid',
          'role': artifact.role,
          'ref': artifact.relativePath,
        };
        continue;
      }
      if (!File(resolved).existsSync()) {
        yield <String, Object?>{
          'code': 'manifestArtifactMissing',
          'role': artifact.role,
          'ref': artifact.relativePath,
          'path': resolved,
        };
      }
    }
  }

  bool _isReadableDiagnosticSnapshot(File file) {
    try {
      final decoded = jsonDecode(file.readAsStringSync());
      if (decoded is! Map<Object?, Object?>) {
        return false;
      }
      CockpitSnapshot.fromJson(Map<String, Object?>.from(decoded));
      return true;
    } on FormatException {
      return false;
    } on IOException {
      return false;
    } on ArgumentError {
      return false;
    } on TypeError {
      return false;
    }
  }

  List<Map<String, Object?>> _gateFailures({
    required Map<String, Object?> handoff,
    Map<String, Object?>? gateSummary,
  }) {
    final failures = <Map<String, Object?>>[];
    final gates = <String, Object?>{
      ...?_readMap(handoff['gates']),
      ...?_readMap(gateSummary?['gates']),
    };
    final failureCodes = <String, Object?>{
      ...?_readMap(handoff['gateFailureCodes']),
      ...?_readMap(gateSummary?['failureCodes']),
    };
    for (final entry in gates.entries) {
      if (entry.value != false) {
        continue;
      }
      failures.add(<String, Object?>{
        'gate': entry.key,
        'failureCodes': _readStringList(failureCodes[entry.key]),
      });
    }
    return failures.take(12).toList(growable: false);
  }

  String _recommendedNextStep({
    required List<Map<String, Object?>> failedCommands,
    required List<Map<String, Object?>> runtimeIssues,
    required List<Map<String, Object?>> networkIssues,
    required List<Map<String, Object?>> artifactIssues,
    required List<Map<String, Object?>> gateFailures,
    required String status,
  }) {
    if (failedCommands.isNotEmpty ||
        runtimeIssues.isNotEmpty ||
        networkIssues.isNotEmpty ||
        artifactIssues.isNotEmpty ||
        gateFailures.isNotEmpty ||
        status == CockpitTaskStatus.failed.name) {
      return 'inspect_issue_evidence';
    }
    return 'no_issue_evidence_needed';
  }

  Map<String, Object?>? _readMap(Object? value) {
    if (value is Map<Object?, Object?>) {
      return Map<String, Object?>.from(value);
    }
    return null;
  }

  String? _readString(Object? value) {
    if (value is String && value.isNotEmpty) {
      return value;
    }
    return null;
  }

  List<String> _readStringList(Object? value) {
    if (value is! List<Object?>) {
      return const <String>[];
    }
    return value.whereType<String>().toList(growable: false);
  }
}

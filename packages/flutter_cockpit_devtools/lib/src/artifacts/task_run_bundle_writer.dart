import 'dart:io';

import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:path/path.dart' as p;

import '../application/cockpit_bundle_artifact_paths.dart';
import '../application/cockpit_bundle_diagnostics_artifact_refs.dart';
import '../application/cockpit_compact_json.dart';
import '../application/cockpit_read_task_bundle_summary_service.dart';
import 'cockpit_recording_keyframe_extractor.dart';
import 'cockpit_timeline_video_fallback_builder.dart';

final class TaskRunBundleWriter {
  const TaskRunBundleWriter({
    CockpitRecordingKeyframeExtractor keyframeExtractor =
        const DefaultCockpitRecordingKeyframeExtractor(),
    CockpitTimelineVideoFallbackBuilder timelineVideoFallbackBuilder =
        const DefaultCockpitTimelineVideoFallbackBuilder(),
  }) : _keyframeExtractor = keyframeExtractor,
       _timelineVideoFallbackBuilder = timelineVideoFallbackBuilder;

  final CockpitRecordingKeyframeExtractor _keyframeExtractor;
  final CockpitTimelineVideoFallbackBuilder _timelineVideoFallbackBuilder;

  Future<Directory> writeBundle({
    required CockpitContextBundle bundle,
    required String outputRoot,
    Map<String, List<int>> artifactPayloads = const <String, List<int>>{},
    Map<String, String> artifactSourcePaths = const <String, String>{},
  }) async {
    final outputDirectory = Directory(
      p.join(outputRoot, _directoryNameFor(bundle.manifest)),
    );

    outputDirectory.createSync(recursive: true);
    Directory(p.join(outputDirectory.path, 'screenshots')).createSync();
    Directory(p.join(outputDirectory.path, 'recordings')).createSync();
    final diagnosticsArtifacts = _diagnosticsArtifactsFor(bundle);
    if (diagnosticsArtifacts.isNotEmpty) {
      Directory(p.join(outputDirectory.path, 'diagnostics')).createSync();
    }

    _writeArtifacts(
      outputDirectory: outputDirectory,
      artifactPayloads: artifactPayloads,
      artifactSourcePaths: artifactSourcePaths,
    );

    final timelineVideoFallback = await _buildTimelineVideoFallback(
      bundle: bundle,
      outputDirectory: outputDirectory,
    );
    if (timelineVideoFallback != null) {
      _writeArtifacts(
        outputDirectory: outputDirectory,
        artifactPayloads: const <String, List<int>>{},
        artifactSourcePaths: <String, String>{
          timelineVideoFallback.artifact.relativePath:
              timelineVideoFallback.sourceFilePath,
        },
      );
    }

    final manifest = _withTimelineVideoFallbackManifest(
      bundle.manifest,
      timelineVideoFallback,
    );
    final delivery = _withTimelineVideoFallbackDelivery(
      bundle.delivery,
      timelineVideoFallback,
    );
    final handoff = _withTimelineVideoFallbackHandoff(
      bundle.handoff,
      timelineVideoFallback,
    );
    final acceptanceMarkdown = _withTimelineVideoFallbackAcceptanceSummary(
      bundle.acceptanceMarkdown,
      timelineVideoFallback,
    );

    final keyframeExtraction = await _extractRecordingKeyframes(
      bundle: bundle,
      delivery: delivery,
      outputDirectory: outputDirectory,
    );
    final finalizedKeyframeExtraction = _supplementRecordingKeyframes(
      bundle: bundle,
      delivery: delivery,
      outputDirectory: outputDirectory,
      keyframeExtraction: keyframeExtraction,
    );
    if (finalizedKeyframeExtraction != null &&
        finalizedKeyframeExtraction.artifactPayloads.isNotEmpty) {
      _writeArtifacts(
        outputDirectory: outputDirectory,
        artifactPayloads: finalizedKeyframeExtraction.artifactPayloads,
        artifactSourcePaths: const <String, String>{},
      );
    }

    final finalizedDelivery = _withKeyframes(
      delivery,
      finalizedKeyframeExtraction,
    );
    _validateDeliveryArtifactRefs(finalizedDelivery);
    final finalizedHandoff = _withKeyframeHandoff(
      handoff,
      finalizedKeyframeExtraction,
    );
    final finalizedAcceptanceMarkdown = _withKeyframeAcceptanceSummary(
      acceptanceMarkdown,
      finalizedKeyframeExtraction,
    );
    _writeDiagnosticsArtifacts(
      outputDirectory: outputDirectory,
      diagnosticsArtifacts: diagnosticsArtifacts,
    );
    _validateManifestArtifactRefs(
      outputDirectory: outputDirectory,
      manifest: manifest,
    );
    _validateDeliveryArtifactFiles(
      outputDirectory: outputDirectory,
      delivery: finalizedDelivery,
    );

    _writeJson(
      p.join(outputDirectory.path, 'manifest.json'),
      manifest.toJson(),
    );
    _writeJson(
      p.join(outputDirectory.path, 'environment.json'),
      bundle.environment.toJson(),
    );
    _writeJson(
      p.join(outputDirectory.path, 'steps.json'),
      bundle.steps.map(_stepJsonForBundle).toList(growable: false),
    );
    _writeJson(
      p.join(outputDirectory.path, 'observations.json'),
      bundle.observations
          .map((observation) => observation.toJson())
          .toList(growable: false),
    );
    _writeJson(p.join(outputDirectory.path, 'logs.json'), _logsFor(bundle));
    _writeJson(p.join(outputDirectory.path, 'handoff.json'), finalizedHandoff);
    _writeJson(
      p.join(outputDirectory.path, 'delivery.json'),
      finalizedDelivery,
    );
    File(
      p.join(outputDirectory.path, 'acceptance.md'),
    ).writeAsStringSync(finalizedAcceptanceMarkdown);
    try {
      await _writeBundleIssueEvidence(outputDirectory);
    } finally {
      await _cleanupTimelineVideoFallback(timelineVideoFallback);
    }

    return outputDirectory;
  }

  Future<void> _writeBundleIssueEvidence(Directory outputDirectory) async {
    final summary = await const CockpitReadTaskBundleSummaryService().read(
      CockpitReadTaskBundleSummaryRequest(bundleDir: outputDirectory.path),
    );
    _writeJson(
      p.join(outputDirectory.path, 'issue_evidence.json'),
      summary.issueEvidence,
    );
  }

  void _writeJson(String path, Object payload) {
    File(path).writeAsStringSync(cockpitPrettyJsonText(payload));
  }

  Map<String, Object?> _logsFor(CockpitContextBundle bundle) {
    final entries = <String, _BundleLogEntry>{};
    for (final step in bundle.steps) {
      final runtime = step.snapshot?.runtime;
      if (runtime != null) {
        for (final event in runtime.entries) {
          entries['runtime:${event.eventId}'] = _BundleLogEntry(
            recordedAt: event.recordedAt,
            payload: <String, Object?>{'source': 'runtime', ...event.toJson()},
          );
        }
      }
      final network = step.snapshot?.network;
      if (network != null) {
        for (final entry in network.entries) {
          entries['network:${entry.requestId}'] = _BundleLogEntry(
            recordedAt: entry.startedAt,
            payload: <String, Object?>{'source': 'network', ...entry.toJson()},
          );
        }
      }
      if (step.actionType == 'runtime_event') {
        final eventId = step.actionArgs['eventId'];
        final key = eventId is String && eventId.isNotEmpty
            ? 'runtime:$eventId'
            : 'runtimeStep:${step.index}';
        entries.putIfAbsent(
          key,
          () => _BundleLogEntry(
            recordedAt:
                _parseLogTimestamp(step.actionArgs['recordedAt']) ??
                step.observedAt,
            payload: <String, Object?>{'source': 'runtime', ...step.actionArgs},
          ),
        );
      }
    }
    final ordered = entries.values.toList(growable: true)
      ..sort((left, right) => left.recordedAt.compareTo(right.recordedAt));
    final manifest = bundle.manifest;
    return <String, Object?>{
      'sessionId': manifest.sessionId,
      'taskId': manifest.taskId,
      'platform': manifest.platform,
      'runtimeEventCount': manifest.runtimeEventCount,
      'runtimeErrorCount': manifest.runtimeErrorCount,
      'runtimeWarningCount': manifest.runtimeWarningCount,
      'entryCount': ordered.length,
      'entries': ordered.map((entry) => entry.payload).toList(growable: false),
    };
  }

  DateTime? _parseLogTimestamp(Object? value) {
    if (value is! String || value.isEmpty) {
      return null;
    }
    return DateTime.tryParse(value)?.toUtc();
  }

  void _validateDeliveryArtifactRefs(Map<String, Object?> delivery) {
    _validateDeliveryRef(
      delivery['primaryScreenshotRef'],
      fieldName: 'primaryScreenshotRef',
      allowedRoots: const <String>{'screenshots'},
      message: 'Delivery screenshot refs must stay under screenshots/.',
    );
    _validateDeliveryRefList(
      delivery['attachmentRefs'],
      fieldName: 'attachmentRefs',
      allowedRoots: const <String>{'screenshots'},
      message: 'Delivery screenshot refs must stay under screenshots/.',
    );
    _validateDeliveryRef(
      delivery['primaryRecordingRef'],
      fieldName: 'primaryRecordingRef',
      allowedRoots: const <String>{'recordings'},
      message: 'Delivery recording refs must stay under recordings/.',
    );
    _validateDeliveryRefList(
      delivery['videoAttachmentRefs'],
      fieldName: 'videoAttachmentRefs',
      allowedRoots: const <String>{'recordings'},
      message: 'Delivery recording refs must stay under recordings/.',
    );
    _validateDeliveryKeyframeRefs(delivery['keyframes']);
  }

  void _validateDeliveryKeyframeRefs(Object? keyframes) {
    if (keyframes == null) {
      return;
    }
    if (keyframes is! List<Object?>) {
      throw ArgumentError.value(
        keyframes,
        'keyframes',
        'Delivery keyframes must decode to a list.',
      );
    }
    for (final keyframe in keyframes) {
      if (keyframe is! Map<Object?, Object?>) {
        throw ArgumentError.value(
          keyframe,
          'keyframes',
          'Delivery keyframe entries must decode to JSON objects.',
        );
      }
      final json = Map<String, Object?>.from(keyframe);
      _validateDeliveryRef(
        json['ref'],
        fieldName: 'keyframes.ref',
        allowedRoots: const <String>{'keyframes'},
        message: 'Delivery keyframe refs must stay under keyframes/.',
      );
      _validateDeliveryRef(
        json['linkedScreenshotRef'],
        fieldName: 'keyframes.linkedScreenshotRef',
        allowedRoots: const <String>{'screenshots'},
        message:
            'Delivery keyframe linked screenshot refs must stay under screenshots/.',
      );
    }
  }

  void _validateDeliveryRefList(
    Object? refs, {
    required String fieldName,
    required Set<String> allowedRoots,
    required String message,
  }) {
    if (refs == null) {
      return;
    }
    if (refs is! List<Object?>) {
      throw ArgumentError.value(refs, fieldName, message);
    }
    for (final ref in refs) {
      _validateDeliveryRef(
        ref,
        fieldName: fieldName,
        allowedRoots: allowedRoots,
        message: message,
      );
    }
  }

  void _validateDeliveryRef(
    Object? ref, {
    required String fieldName,
    required Set<String> allowedRoots,
    required String message,
  }) {
    if (ref == null) {
      return;
    }
    if (ref is! String || ref.isEmpty) {
      throw ArgumentError.value(ref, fieldName, message);
    }
    final resolvedPath = CockpitBundleArtifactPaths.resolveBundleArtifactPath(
      '/',
      ref,
      allowedRoots: allowedRoots,
    );
    if (resolvedPath == null) {
      throw ArgumentError.value(ref, fieldName, message);
    }
  }

  void _validateManifestArtifactRefs({
    required Directory outputDirectory,
    required CockpitRunManifest manifest,
  }) {
    for (final artifact in manifest.artifactRefs) {
      final allowedRoots =
          CockpitBundleArtifactPaths.allowedRootsForArtifactRole(artifact.role);
      final artifactPath = CockpitBundleArtifactPaths.resolveBundleArtifactPath(
        outputDirectory.path,
        artifact.relativePath,
        allowedRoots: allowedRoots,
      );
      if (artifact.relativePath.isEmpty || artifactPath == null) {
        throw ArgumentError.value(
          artifact.relativePath,
          'relativePath',
          'Manifest artifact refs must stay under their expected evidence directory.',
        );
      }
      if (!File(artifactPath).existsSync()) {
        throw StateError(
          'Manifest artifact file does not exist: ${artifact.relativePath}',
        );
      }
    }
  }

  void _validateDeliveryArtifactFiles({
    required Directory outputDirectory,
    required Map<String, Object?> delivery,
  }) {
    for (final ref in <String>[
      if (delivery['primaryScreenshotRef'] case final String ref
          when ref.isNotEmpty)
        ref,
      ..._stringRefs(delivery['attachmentRefs']),
      if (delivery['primaryRecordingRef'] case final String ref
          when ref.isNotEmpty)
        ref,
      ..._stringRefs(delivery['videoAttachmentRefs']),
    ]) {
      _validateDeliveryArtifactFileExists(
        outputDirectory: outputDirectory,
        ref: ref,
        allowedRoots: const <String>{'screenshots', 'recordings'},
      );
    }

    for (final keyframe in _keyframeJsonObjects(delivery['keyframes'])) {
      if (keyframe['ref'] case final String ref when ref.isNotEmpty) {
        _validateDeliveryArtifactFileExists(
          outputDirectory: outputDirectory,
          ref: ref,
          allowedRoots: const <String>{'keyframes'},
        );
      }
      if (keyframe['linkedScreenshotRef'] case final String ref
          when ref.isNotEmpty) {
        _validateDeliveryArtifactFileExists(
          outputDirectory: outputDirectory,
          ref: ref,
          allowedRoots: const <String>{'screenshots'},
        );
      }
    }
  }

  void _validateDeliveryArtifactFileExists({
    required Directory outputDirectory,
    required String ref,
    required Set<String> allowedRoots,
  }) {
    final artifactPath = CockpitBundleArtifactPaths.resolveBundleArtifactPath(
      outputDirectory.path,
      ref,
      allowedRoots: allowedRoots,
    );
    if (artifactPath == null || !File(artifactPath).existsSync()) {
      throw StateError('Delivery artifact file does not exist: $ref');
    }
  }

  List<Map<String, Object?>> _keyframeJsonObjects(Object? keyframes) {
    if (keyframes is! List<Object?>) {
      return const <Map<String, Object?>>[];
    }
    return keyframes
        .whereType<Map<Object?, Object?>>()
        .map((item) => Map<String, Object?>.from(item))
        .toList(growable: false);
  }

  List<String> _stringRefs(Object? refs) {
    if (refs is! List<Object?>) {
      return const <String>[];
    }
    return refs.whereType<String>().where((ref) => ref.isNotEmpty).toList();
  }

  void _writeArtifacts({
    required Directory outputDirectory,
    required Map<String, List<int>> artifactPayloads,
    required Map<String, String> artifactSourcePaths,
  }) {
    for (final entry in artifactPayloads.entries) {
      final artifactFile = File(
        _bundleArtifactPath(outputDirectory, entry.key),
      );
      artifactFile.parent.createSync(recursive: true);
      artifactFile.writeAsBytesSync(entry.value);
    }

    for (final entry in artifactSourcePaths.entries) {
      if (artifactPayloads.containsKey(entry.key)) {
        continue;
      }

      final sourceFile = File(entry.value);
      if (!sourceFile.existsSync()) {
        throw StateError('Artifact source file does not exist: ${entry.value}');
      }

      final artifactFile = File(
        _bundleArtifactPath(outputDirectory, entry.key),
      );
      artifactFile.parent.createSync(recursive: true);
      sourceFile.copySync(artifactFile.path);
    }
  }

  Future<CockpitRecordingKeyframeExtractionResult?> _extractRecordingKeyframes({
    required CockpitContextBundle bundle,
    required Map<String, Object?> delivery,
    required Directory outputDirectory,
  }) async {
    final primaryRecordingRef = delivery['primaryRecordingRef'] as String?;
    if (primaryRecordingRef == null || primaryRecordingRef.isEmpty) {
      return null;
    }
    final recordingFile = File(
      p.join(outputDirectory.path, primaryRecordingRef),
    );
    if (!recordingFile.existsSync()) {
      return const CockpitRecordingKeyframeExtractionResult(
        keyframes: <CockpitRecordingKeyframe>[],
        artifactPayloads: <String, List<int>>{},
        coverage: CockpitRecordingCoverage(
          durationMs: 0,
          hasEarlyCoverage: false,
          hasMidCoverage: false,
          hasLateCoverage: false,
        ),
        failureReason: 'recordingArtifactMissing',
      );
    }
    return _keyframeExtractor.extract(
      recordingPath: recordingFile.path,
      recordingRelativePath: primaryRecordingRef,
      steps: bundle.steps,
      bundleDirectoryPath: outputDirectory.path,
    );
  }

  CockpitRecordingKeyframeExtractionResult? _supplementRecordingKeyframes({
    required CockpitContextBundle bundle,
    required Map<String, Object?> delivery,
    required Directory outputDirectory,
    required CockpitRecordingKeyframeExtractionResult? keyframeExtraction,
  }) {
    if (keyframeExtraction == null) {
      return null;
    }
    final durationMs = keyframeExtraction.coverage.durationMs;
    if (durationMs <= 0) {
      return keyframeExtraction;
    }

    final primaryRecordingRef =
        delivery['primaryRecordingRef'] as String? ?? '';
    if (primaryRecordingRef.isEmpty) {
      return keyframeExtraction;
    }

    final recordingStarted = bundle.steps.firstWhere(
      (step) => step.actionType == 'recording_started',
      orElse: () => bundle.steps.firstWhere(
        (step) => step.actionType == 'recording_start_requested',
        orElse: () => CockpitStepRecord(
          index: -1,
          actionType: 'missing',
          actionArgs: const <String, Object?>{},
          observedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        ),
      ),
    );
    if (recordingStarted.index < 0) {
      return keyframeExtraction;
    }

    final keyframes = <CockpitRecordingKeyframe>[
      ...keyframeExtraction.keyframes,
    ]..sort((left, right) => left.offsetMs.compareTo(right.offsetMs));
    final artifactPayloads = <String, List<int>>{
      ...keyframeExtraction.artifactPayloads,
    };
    var coverage = keyframeExtraction.coverage;
    if (coverage.isReady) {
      return keyframeExtraction;
    }

    final screenshotCandidates = _screenshotKeyframeCandidates(
      bundle: bundle,
      recordingStartTime: recordingStarted.observedAt,
      durationMs: durationMs,
      recordingRelativePath: primaryRecordingRef,
    );
    for (final candidate in screenshotCandidates) {
      if (_containsEquivalentKeyframe(keyframes, candidate)) {
        continue;
      }
      if (!_candidateImprovesCoverage(
        candidate: candidate,
        coverage: coverage,
        durationMs: durationMs,
      )) {
        continue;
      }
      final screenshotRef = candidate.linkedScreenshotRef;
      if (screenshotRef == null) {
        continue;
      }
      final screenshotFile = File(p.join(outputDirectory.path, screenshotRef));
      if (!screenshotFile.existsSync()) {
        continue;
      }

      artifactPayloads[candidate.relativePath] = screenshotFile
          .readAsBytesSync();
      keyframes.add(candidate);
      keyframes.sort((left, right) => left.offsetMs.compareTo(right.offsetMs));
      coverage = _coverageForKeyframes(
        durationMs: durationMs,
        keyframes: keyframes,
      );
      if (coverage.isReady) {
        break;
      }
    }

    final failureReason = coverage.isReady
        ? null
        : keyframeExtraction.failureReason;
    return CockpitRecordingKeyframeExtractionResult(
      keyframes: List<CockpitRecordingKeyframe>.unmodifiable(keyframes),
      artifactPayloads: Map<String, List<int>>.unmodifiable(artifactPayloads),
      coverage: coverage,
      failureReason: failureReason,
    );
  }

  List<CockpitRecordingKeyframe> _screenshotKeyframeCandidates({
    required CockpitContextBundle bundle,
    required DateTime recordingStartTime,
    required int durationMs,
    required String recordingRelativePath,
  }) {
    final earlyWindowEnd = _earlyCoverageWindowMs(durationMs);
    final screenshotSteps =
        bundle.steps
            .where(
              (step) => step.captureRefs.any(
                (artifact) => artifact.role == 'screenshot',
              ),
            )
            .toList(growable: false)
          ..sort((left, right) => left.observedAt.compareTo(right.observedAt));

    final candidates = <CockpitRecordingKeyframe>[];
    for (var index = 0; index < screenshotSteps.length; index++) {
      final step = screenshotSteps[index];
      String? screenshotRef;
      for (final artifact in step.captureRefs) {
        if (artifact.role == 'screenshot') {
          screenshotRef = artifact.relativePath;
        }
      }
      if (screenshotRef == null) {
        continue;
      }
      final offsetMs = step.observedAt
          .difference(recordingStartTime)
          .inMilliseconds
          .clamp(0, durationMs);
      final label = switch (step.requestedCaptureProfile) {
        CockpitCaptureProfile.acceptance ||
        CockpitCaptureProfile.nativePreferred => 'acceptance',
        _ when index == 0 && offsetMs <= earlyWindowEnd => 'baseline',
        _ => 'step_capture_${step.index.toString().padLeft(3, '0')}',
      };
      candidates.add(
        CockpitRecordingKeyframe(
          relativePath: cockpitRecordingKeyframeRelativePathFor(
            recordingRelativePath: recordingRelativePath,
            label: label,
            offsetMs: offsetMs,
          ),
          label: label,
          offsetMs: offsetMs,
          source: CockpitRecordingKeyframeSource.stepCapture,
          linkedScreenshotRef: screenshotRef,
        ),
      );
    }

    if (candidates.isNotEmpty) {
      final midpointOffset = (durationMs * 0.5).round().clamp(0, durationMs);
      var midpointCandidate = candidates.first;
      var bestDistance = (midpointCandidate.offsetMs - midpointOffset).abs();
      for (final candidate in candidates) {
        final distance = (candidate.offsetMs - midpointOffset).abs();
        if (distance < bestDistance) {
          midpointCandidate = candidate;
          bestDistance = distance;
        }
      }
      candidates.add(
        CockpitRecordingKeyframe(
          relativePath: cockpitRecordingKeyframeRelativePathFor(
            recordingRelativePath: recordingRelativePath,
            label: 'midpoint',
            offsetMs: midpointOffset,
          ),
          label: 'midpoint',
          offsetMs: midpointOffset,
          source: CockpitRecordingKeyframeSource.stepCapture,
          linkedScreenshotRef: midpointCandidate.linkedScreenshotRef,
        ),
      );
    }
    return candidates;
  }

  Future<CockpitTimelineVideoFallbackResult?> _buildTimelineVideoFallback({
    required CockpitContextBundle bundle,
    required Directory outputDirectory,
  }) async {
    final primaryRecordingRef =
        bundle.delivery['primaryRecordingRef'] as String?;
    if (primaryRecordingRef != null && primaryRecordingRef.isNotEmpty) {
      return null;
    }
    return _timelineVideoFallbackBuilder.build(
      bundle: bundle,
      outputDirectoryPath: outputDirectory.path,
    );
  }

  CockpitRunManifest _withTimelineVideoFallbackManifest(
    CockpitRunManifest manifest,
    CockpitTimelineVideoFallbackResult? timelineVideoFallback,
  ) {
    if (timelineVideoFallback == null) {
      return manifest;
    }

    return CockpitRunManifest(
      sessionId: manifest.sessionId,
      taskId: manifest.taskId,
      platform: manifest.platform,
      status: manifest.status,
      startedAt: manifest.startedAt,
      finishedAt: manifest.finishedAt,
      artifactRefs: <CockpitArtifactRef>[
        ...manifest.artifactRefs,
        timelineVideoFallback.artifact,
      ],
      failureSummary: manifest.failureSummary,
      capabilitiesUsed: manifest.capabilitiesUsed,
      commandCount: manifest.commandCount,
      screenshotCount: manifest.screenshotCount,
      failureCount: manifest.failureCount,
      nativeScreenshotCount: manifest.nativeScreenshotCount,
      flutterScreenshotCount: manifest.flutterScreenshotCount,
      deliveryArtifactsReady: manifest.deliveryArtifactsReady,
      deliveryArtifactFailureCodes: manifest.deliveryArtifactFailureCodes,
      recordingCount: manifest.recordingCount > 0 ? manifest.recordingCount : 1,
      nativeRecordingCount: manifest.nativeRecordingCount,
      deliveryVideoReady: true,
      deliveryVideoFailureCodes: const <String>[],
      runtimeEventCount: manifest.runtimeEventCount,
      runtimeErrorCount: manifest.runtimeErrorCount,
      runtimeWarningCount: manifest.runtimeWarningCount,
    );
  }

  Map<String, Object?> _withTimelineVideoFallbackDelivery(
    Map<String, Object?> delivery,
    CockpitTimelineVideoFallbackResult? timelineVideoFallback,
  ) {
    if (timelineVideoFallback == null) {
      return delivery;
    }

    final readiness = _readJsonMap(delivery['readiness']);
    final videoReadiness = _readJsonMap(readiness['video']);
    return <String, Object?>{
      ...delivery,
      'primaryRecordingRef': timelineVideoFallback.artifact.relativePath,
      'videoAttachmentRefs': <String>[
        timelineVideoFallback.artifact.relativePath,
      ],
      'deliveryVideoReady': true,
      'deliveryVideoSynthesized': true,
      'deliveryVideoSource': 'timelineFallback',
      'deliveryVideoDurationMs': timelineVideoFallback.durationMs,
      'deliveryVideoScreenshotRefs': timelineVideoFallback.screenshotRefs,
      'videoFailureCodes': const <String>[],
      'readiness': <String, Object?>{
        ...readiness,
        'video': <String, Object?>{
          ...videoReadiness,
          'ready': true,
          'failureCodes': const <String>[],
          'source': 'timelineFallback',
        },
      },
    };
  }

  Map<String, Object?> _withTimelineVideoFallbackHandoff(
    Map<String, Object?> handoff,
    CockpitTimelineVideoFallbackResult? timelineVideoFallback,
  ) {
    if (timelineVideoFallback == null) {
      return handoff;
    }

    final gates = _readJsonMap(handoff['gates']);
    final gateFailureCodes = _readJsonMap(handoff['gateFailureCodes']);
    return <String, Object?>{
      ...handoff,
      'recordingCount': 1,
      'deliveryVideoReady': true,
      'deliveryVideoSynthesized': true,
      'deliveryVideoSource': 'timelineFallback',
      'deliveryVideoDurationMs': timelineVideoFallback.durationMs,
      'videoFailureCodes': const <String>[],
      'recordingReadyOrExplained': true,
      'deliveryValidated':
          (handoff['screenshotReady'] as bool? ?? true) && true,
      'gates': <String, Object?>{
        ...gates,
        'recordingReadyOrExplained': true,
        'deliveryValidated':
            (gates['screenshotReady'] as bool? ??
                handoff['screenshotReady'] as bool? ??
                true) &&
            true,
      },
      'gateFailureCodes': <String, Object?>{
        ...gateFailureCodes,
        'recordingReadyOrExplained': const <String>[],
        'deliveryValidated': _readStringList(
          gateFailureCodes['screenshotReady'],
        ),
      },
    };
  }

  String _withTimelineVideoFallbackAcceptanceSummary(
    String acceptanceMarkdown,
    CockpitTimelineVideoFallbackResult? timelineVideoFallback,
  ) {
    if (timelineVideoFallback == null) {
      return acceptanceMarkdown;
    }
    return '$acceptanceMarkdown\n- Synthesized delivery video: ${timelineVideoFallback.artifact.relativePath}\n';
  }

  Future<void> _cleanupTimelineVideoFallback(
    CockpitTimelineVideoFallbackResult? timelineVideoFallback,
  ) async {
    final cleanupDirectoryPath = timelineVideoFallback?.cleanupDirectoryPath;
    if (cleanupDirectoryPath == null || cleanupDirectoryPath.isEmpty) {
      return;
    }
    final directory = Directory(cleanupDirectoryPath);
    if (directory.existsSync()) {
      await directory.delete(recursive: true);
    }
  }

  CockpitRecordingCoverage _coverageForKeyframes({
    required int durationMs,
    required List<CockpitRecordingKeyframe> keyframes,
  }) {
    if (durationMs <= 0 || keyframes.isEmpty) {
      return const CockpitRecordingCoverage(
        durationMs: 0,
        hasEarlyCoverage: false,
        hasMidCoverage: false,
        hasLateCoverage: false,
      );
    }

    final hasEarlyCoverage = keyframes.any(
      (keyframe) => keyframe.offsetMs <= _earlyCoverageWindowMs(durationMs),
    );
    final needsMidCoverage = durationMs >= 3000;
    final midStart = (durationMs * 0.30).round();
    final midEnd = (durationMs * 0.70).round();
    final hasMidCoverage =
        !needsMidCoverage ||
        keyframes.any(
          (keyframe) =>
              keyframe.offsetMs >= midStart && keyframe.offsetMs <= midEnd,
        );
    final lateWindowStart = durationMs - (durationMs < 2000 ? 450 : 900);
    final hasLateCoverage = keyframes.any(
      (keyframe) =>
          keyframe.label == 'tail_consistency' ||
          keyframe.offsetMs >= lateWindowStart,
    );
    return CockpitRecordingCoverage(
      durationMs: durationMs,
      hasEarlyCoverage: hasEarlyCoverage,
      hasMidCoverage: hasMidCoverage,
      hasLateCoverage: hasLateCoverage,
    );
  }

  int _earlyCoverageWindowMs(int durationMs) {
    return (durationMs < 2400 ? 600 : durationMs * 0.22).round();
  }

  bool _candidateImprovesCoverage({
    required CockpitRecordingKeyframe candidate,
    required CockpitRecordingCoverage coverage,
    required int durationMs,
  }) {
    final lateWindowStart = durationMs - (durationMs < 2000 ? 450 : 900);
    final midStart = (durationMs * 0.30).round();
    final midEnd = (durationMs * 0.70).round();
    final fillsEarly =
        !coverage.hasEarlyCoverage &&
        candidate.offsetMs <= _earlyCoverageWindowMs(durationMs);
    final fillsMid =
        !coverage.hasMidCoverage &&
        candidate.offsetMs >= midStart &&
        candidate.offsetMs <= midEnd;
    final fillsLate =
        !coverage.hasLateCoverage &&
        (candidate.label == 'tail_consistency' ||
            candidate.offsetMs >= lateWindowStart);
    return fillsEarly || fillsMid || fillsLate;
  }

  bool _containsEquivalentKeyframe(
    List<CockpitRecordingKeyframe> existing,
    CockpitRecordingKeyframe candidate,
  ) {
    return existing.any(
      (keyframe) =>
          keyframe.relativePath == candidate.relativePath ||
          (keyframe.label == candidate.label &&
              (keyframe.offsetMs - candidate.offsetMs).abs() <= 250),
    );
  }

  Map<String, Object?> _withKeyframes(
    Map<String, Object?> delivery,
    CockpitRecordingKeyframeExtractionResult? keyframeExtraction,
  ) {
    if (keyframeExtraction == null) {
      return Map<String, Object?>.from(delivery);
    }
    return <String, Object?>{
      ...delivery,
      'keyframes': keyframeExtraction.keyframes
          .map((keyframe) => keyframe.toJson())
          .toList(growable: false),
      'keyframeCoverage': keyframeExtraction.coverage.toJson(),
      'deliveryKeyframesReady':
          keyframeExtraction.coverage.isReady &&
          keyframeExtraction.keyframes.isNotEmpty &&
          keyframeExtraction.failureReason == null,
      'keyframeFailureReason': keyframeExtraction.failureReason,
    };
  }

  Map<String, Object?> _withKeyframeHandoff(
    Map<String, Object?> handoff,
    CockpitRecordingKeyframeExtractionResult? keyframeExtraction,
  ) {
    if (keyframeExtraction == null) {
      return Map<String, Object?>.from(handoff);
    }
    return <String, Object?>{
      ...handoff,
      'keyframeCount': keyframeExtraction.keyframes.length,
      'deliveryKeyframesReady': keyframeExtraction.coverage.isReady,
      'keyframeFailureReason': keyframeExtraction.failureReason,
    };
  }

  String _withKeyframeAcceptanceSummary(
    String acceptanceMarkdown,
    CockpitRecordingKeyframeExtractionResult? keyframeExtraction,
  ) {
    if (keyframeExtraction == null) {
      return acceptanceMarkdown;
    }
    final buffer = StringBuffer(acceptanceMarkdown.trimRight());
    buffer.writeln();
    buffer.writeln();
    buffer.writeln('## Keyframes');
    buffer.writeln();
    buffer.writeln('- Keyframe count: ${keyframeExtraction.keyframes.length}');
    buffer.writeln(
      '- Coverage ready: ${keyframeExtraction.coverage.isReady ? 'yes' : 'no'}',
    );
    buffer.writeln(
      '- Coverage windows: early=${keyframeExtraction.coverage.hasEarlyCoverage}, mid=${keyframeExtraction.coverage.hasMidCoverage}, late=${keyframeExtraction.coverage.hasLateCoverage}',
    );
    if (keyframeExtraction.failureReason != null) {
      buffer.writeln('- Failure: ${keyframeExtraction.failureReason}');
    }
    return buffer.toString();
  }

  Map<String, Object?> _readJsonMap(Object? value) {
    if (value is! Map<Object?, Object?>) {
      return <String, Object?>{};
    }
    return Map<String, Object?>.from(value);
  }

  List<String> _readStringList(Object? value) {
    if (value is! List<Object?>) {
      return const <String>[];
    }
    return value.cast<String>();
  }

  Map<String, Object?> _stepJsonForBundle(CockpitStepRecord step) {
    final json = step.toJson();
    final snapshot = step.snapshot;
    if (snapshot == null || snapshot.diagnosticsArtifactRef == null) {
      return json;
    }

    json['snapshot'] = _summarizedSnapshot(snapshot).toJson();
    return json;
  }

  Map<String, CockpitSnapshot> _diagnosticsArtifactsFor(
    CockpitContextBundle bundle,
  ) {
    final diagnosticsArtifacts = <String, CockpitSnapshot>{};
    for (final step in bundle.steps) {
      final snapshot = step.snapshot;
      final diagnosticsArtifactRef = snapshot?.diagnosticsArtifactRef;
      if (snapshot == null || diagnosticsArtifactRef == null) {
        continue;
      }
      _validateDiagnosticsArtifactRef(diagnosticsArtifactRef);
      diagnosticsArtifacts[diagnosticsArtifactRef.relativePath] = snapshot;
    }
    return diagnosticsArtifacts;
  }

  void _validateDiagnosticsArtifactRef(CockpitArtifactRef artifactRef) {
    final resolvedPath = CockpitBundleDiagnosticsArtifactRefs.resolvePath(
      '/',
      artifactRef.relativePath,
    );
    if (artifactRef.role != 'diagnostics' || resolvedPath == null) {
      throw ArgumentError.value(
        artifactRef.relativePath,
        'relativePath',
        'Diagnostics artifact path must stay under diagnostics/.',
      );
    }
  }

  CockpitSnapshot _summarizedSnapshot(CockpitSnapshot snapshot) {
    return CockpitSnapshot(
      routeName: snapshot.routeName,
      visibleTargets: snapshot.visibleTargets
          .map(
            (target) => CockpitSnapshotTarget(
              registrationId: target.registrationId,
              cockpitId: target.cockpitId,
              semanticId: target.semanticId,
              text: target.text,
              tooltip: target.tooltip,
              typeName: target.typeName,
              routeName: target.routeName,
              supportedCommands: target.supportedCommands,
              content: target.content,
              layout: target.layout,
            ),
          )
          .toList(growable: false),
      diagnosticLevel: snapshot.diagnosticLevel,
      truncated: snapshot.truncated,
      diagnosticsArtifactRef: snapshot.diagnosticsArtifactRef,
      summary: snapshot.summary,
      network: snapshot.network,
      runtime: snapshot.runtime,
    );
  }

  void _writeDiagnosticsArtifacts({
    required Directory outputDirectory,
    required Map<String, CockpitSnapshot> diagnosticsArtifacts,
  }) {
    for (final entry in diagnosticsArtifacts.entries) {
      _writeJson(
        _bundleArtifactPath(outputDirectory, entry.key),
        entry.value.toJson(),
      );
    }
  }

  String _bundleArtifactPath(Directory outputDirectory, String relativePath) {
    final normalized = p.normalize(relativePath);
    final allowedRoot = normalized.split(p.separator).firstOrNull;
    const allowedRoots = <String>{
      'screenshots',
      'recordings',
      'keyframes',
      'diagnostics',
    };
    if (normalized.isEmpty ||
        p.isAbsolute(normalized) ||
        normalized == '.' ||
        normalized.startsWith('..${p.separator}') ||
        normalized == '..' ||
        !allowedRoots.contains(allowedRoot)) {
      throw ArgumentError.value(
        relativePath,
        'relativePath',
        'Artifact path must stay inside the task-run bundle under screenshots/, recordings/, keyframes/, or diagnostics/.',
      );
    }

    final outputRoot = p.canonicalize(outputDirectory.path);
    final artifactPath = p.canonicalize(p.join(outputRoot, normalized));
    if (!p.isWithin(outputRoot, artifactPath)) {
      throw ArgumentError.value(
        relativePath,
        'relativePath',
        'Artifact path must stay inside the task-run bundle under screenshots/, recordings/, keyframes/, or diagnostics/.',
      );
    }
    return artifactPath;
  }

  String _directoryNameFor(CockpitRunManifest manifest) {
    final safeTimestamp = cockpitSortableTimestampToken(manifest.startedAt);
    final safeSessionId = cockpitSanitizeArtifactNameToken(
      manifest.sessionId,
      fallback: 'session',
    );
    return '${safeTimestamp}_$safeSessionId';
  }
}

final class _BundleLogEntry {
  const _BundleLogEntry({required this.recordedAt, required this.payload});

  final DateTime recordedAt;
  final Map<String, Object?> payload;
}

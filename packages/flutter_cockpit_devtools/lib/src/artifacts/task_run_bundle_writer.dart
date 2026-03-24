import 'dart:convert';
import 'dart:io';

import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:path/path.dart' as p;

import 'cockpit_recording_keyframe_extractor.dart';
import 'cockpit_timeline_video_fallback_builder.dart';

final class TaskRunBundleWriter {
  const TaskRunBundleWriter({
    CockpitRecordingKeyframeExtractor keyframeExtractor =
        const DefaultCockpitRecordingKeyframeExtractor(),
    CockpitTimelineVideoFallbackBuilder timelineVideoFallbackBuilder =
        const DefaultCockpitTimelineVideoFallbackBuilder(),
  })  : _keyframeExtractor = keyframeExtractor,
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
    final finalizedHandoff = _withKeyframeHandoff(
      handoff,
      finalizedKeyframeExtraction,
    );
    final finalizedAcceptanceMarkdown = _withKeyframeAcceptanceSummary(
      acceptanceMarkdown,
      finalizedKeyframeExtraction,
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
    _writeJson(p.join(outputDirectory.path, 'handoff.json'), finalizedHandoff);
    _writeJson(
      p.join(outputDirectory.path, 'delivery.json'),
      finalizedDelivery,
    );
    File(
      p.join(outputDirectory.path, 'acceptance.md'),
    ).writeAsStringSync(finalizedAcceptanceMarkdown);
    _writeDiagnosticsArtifacts(
      outputDirectory: outputDirectory,
      diagnosticsArtifacts: diagnosticsArtifacts,
    );
    await _cleanupTimelineVideoFallback(timelineVideoFallback);

    return outputDirectory;
  }

  void _writeJson(String path, Object payload) {
    const encoder = JsonEncoder.withIndent('  ');
    File(path).writeAsStringSync(encoder.convert(payload));
  }

  void _writeArtifacts({
    required Directory outputDirectory,
    required Map<String, List<int>> artifactPayloads,
    required Map<String, String> artifactSourcePaths,
  }) {
    for (final entry in artifactPayloads.entries) {
      final artifactFile = File(p.join(outputDirectory.path, entry.key));
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

      final artifactFile = File(p.join(outputDirectory.path, entry.key));
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

      artifactPayloads[candidate.relativePath] =
          screenshotFile.readAsBytesSync();
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

    final failureReason =
        coverage.isReady ? null : keyframeExtraction.failureReason;
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
    final recordingBaseName = p.basenameWithoutExtension(recordingRelativePath);
    final earlyWindowEnd = _earlyCoverageWindowMs(durationMs);
    final screenshotSteps = bundle.steps
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
        CockpitCaptureProfile.nativePreferred =>
          'acceptance',
        _ when index == 0 && offsetMs <= earlyWindowEnd => 'baseline',
        _ => 'step_capture_${step.index.toString().padLeft(3, '0')}',
      };
      candidates.add(
        CockpitRecordingKeyframe(
          relativePath:
              'keyframes/${recordingBaseName}_${label}_${offsetMs.toString().padLeft(5, '0')}.png',
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
          relativePath:
              'keyframes/${recordingBaseName}_midpoint_${midpointOffset.toString().padLeft(5, '0')}.png',
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
      recordingCount: manifest.recordingCount > 0 ? manifest.recordingCount : 1,
      nativeRecordingCount: manifest.nativeRecordingCount,
      deliveryVideoReady: true,
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
    };
  }

  Map<String, Object?> _withTimelineVideoFallbackHandoff(
    Map<String, Object?> handoff,
    CockpitTimelineVideoFallbackResult? timelineVideoFallback,
  ) {
    if (timelineVideoFallback == null) {
      return handoff;
    }

    return <String, Object?>{
      ...handoff,
      'recordingCount': 1,
      'deliveryVideoReady': true,
      'deliveryVideoSynthesized': true,
      'deliveryVideoSource': 'timelineFallback',
      'deliveryVideoDurationMs': timelineVideoFallback.durationMs,
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
    final hasMidCoverage = !needsMidCoverage ||
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
    final fillsEarly = !coverage.hasEarlyCoverage &&
        candidate.offsetMs <= _earlyCoverageWindowMs(durationMs);
    final fillsMid = !coverage.hasMidCoverage &&
        candidate.offsetMs >= midStart &&
        candidate.offsetMs <= midEnd;
    final fillsLate = !coverage.hasLateCoverage &&
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
      'deliveryKeyframesReady': keyframeExtraction.coverage.isReady &&
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
      diagnosticsArtifacts[diagnosticsArtifactRef.relativePath] = snapshot;
    }
    return diagnosticsArtifacts;
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
      _writeJson(p.join(outputDirectory.path, entry.key), entry.value.toJson());
    }
  }

  String _directoryNameFor(CockpitRunManifest manifest) {
    final safeTimestamp = manifest.startedAt
        .toUtc()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '_');
    return '${safeTimestamp}_${manifest.sessionId}';
  }
}

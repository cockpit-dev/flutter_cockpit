import 'dart:convert';
import 'dart:io';

import '../artifacts/cockpit_recording_keyframe_extractor.dart';
import '../validation/cockpit_bundle_artifact_validator.dart';
import 'cockpit_bundle_artifact_paths.dart';
import 'cockpit_bundle_diagnostics_artifact_refs.dart';
import 'cockpit_read_task_bundle_summary_service.dart';
import 'cockpit_run_task_service.dart';
import 'cockpit_task_gate.dart';
import 'cockpit_task_orchestration_service.dart';

typedef CockpitValidateTaskFunction =
    Future<CockpitValidateTaskResult> Function(
      CockpitValidateTaskRequest request,
    );

enum CockpitValidationClassification {
  completed('completed'),
  failedWithEvidence('failed_with_evidence'),
  blockedByEnvironment('blocked_by_environment'),
  needsMoreWork('needs_more_work');

  const CockpitValidationClassification(this.jsonValue);

  final String jsonValue;

  static CockpitValidationClassification fromJson(Object? json) {
    return values.firstWhere(
      (value) => value.jsonValue == json,
      orElse: () => throw ArgumentError.value(
        json,
        'json',
        'Unsupported validation classification.',
      ),
    );
  }
}

final class CockpitValidationFailure {
  const CockpitValidationFailure({
    required this.code,
    required this.message,
    this.details = const <String, Object?>{},
  });

  final String code;
  final String message;
  final Map<String, Object?> details;

  Map<String, Object?> toJson() => <String, Object?>{
    'code': code,
    'message': message,
    'details': details,
  };
}

final class CockpitValidateTaskRequirements {
  const CockpitValidateTaskRequirements({
    this.expectedClassification,
    this.requireAcceptanceMarkdown = false,
    this.requireEnvironmentSnapshot = false,
    this.requirePrimaryScreenshot = false,
    this.requirePrimaryRecording = false,
    this.requireArtifactFiles = false,
    this.requireAcceptanceSemanticEvidence = false,
  });

  final CockpitRunTaskClassification? expectedClassification;
  final bool requireAcceptanceMarkdown;
  final bool requireEnvironmentSnapshot;
  final bool requirePrimaryScreenshot;
  final bool requirePrimaryRecording;
  final bool requireArtifactFiles;
  final bool requireAcceptanceSemanticEvidence;

  Map<String, Object?> toJson() => <String, Object?>{
    if (expectedClassification != null)
      'expectedClassification': expectedClassification!.jsonValue,
    'requireAcceptanceMarkdown': requireAcceptanceMarkdown,
    'requireEnvironmentSnapshot': requireEnvironmentSnapshot,
    'requirePrimaryScreenshot': requirePrimaryScreenshot,
    'requirePrimaryRecording': requirePrimaryRecording,
    'requireArtifactFiles': requireArtifactFiles,
    'requireAcceptanceSemanticEvidence': requireAcceptanceSemanticEvidence,
  };

  factory CockpitValidateTaskRequirements.fromJson(Map<String, Object?> json) {
    final expectedClassificationValue = json['expectedClassification'];
    return CockpitValidateTaskRequirements(
      expectedClassification: expectedClassificationValue == null
          ? null
          : CockpitRunTaskClassification.fromJson(expectedClassificationValue),
      requireAcceptanceMarkdown:
          _readOptionalBool(json, 'requireAcceptanceMarkdown') ?? false,
      requireEnvironmentSnapshot:
          _readOptionalBool(json, 'requireEnvironmentSnapshot') ?? false,
      requirePrimaryScreenshot:
          _readOptionalBool(json, 'requirePrimaryScreenshot') ?? false,
      requirePrimaryRecording:
          _readOptionalBool(json, 'requirePrimaryRecording') ?? false,
      requireArtifactFiles:
          _readOptionalBool(json, 'requireArtifactFiles') ?? false,
      requireAcceptanceSemanticEvidence:
          _readOptionalBool(json, 'requireAcceptanceSemanticEvidence') ?? false,
    );
  }
}

final class CockpitValidateTaskRequest {
  const CockpitValidateTaskRequest({
    required this.runTask,
    this.validation = const CockpitValidateTaskRequirements(),
  });

  final CockpitRunTaskRequest runTask;
  final CockpitValidateTaskRequirements validation;

  Map<String, Object?> toJson() => <String, Object?>{
    'runTask': runTask.toJson(),
    'validation': validation.toJson(),
  };

  factory CockpitValidateTaskRequest.fromJson(Map<String, Object?> json) {
    final runTaskJson = _readRequiredObject(json, 'runTask');
    final validationJson = _readOptionalObject(json, 'validation');
    return CockpitValidateTaskRequest(
      runTask: CockpitRunTaskRequest.fromJson(runTaskJson),
      validation: validationJson == null
          ? const CockpitValidateTaskRequirements()
          : CockpitValidateTaskRequirements.fromJson(validationJson),
    );
  }
}

final class CockpitValidateTaskResult {
  const CockpitValidateTaskResult({
    required this.classification,
    required this.recommendedNextStep,
    this.runTaskResult,
    this.bundleSummary,
    this.blockedReason,
    this.validationFailures = const <CockpitValidationFailure>[],
    this.warnings = const <String>[],
  });

  final CockpitValidationClassification classification;
  final String recommendedNextStep;
  final CockpitRunTaskResult? runTaskResult;
  final CockpitReadTaskBundleSummaryResult? bundleSummary;
  final String? blockedReason;
  final List<CockpitValidationFailure> validationFailures;
  final List<String> warnings;

  Map<String, Object?> toJson() => <String, Object?>{
    'classification': classification.jsonValue,
    'recommendedNextStep': recommendedNextStep,
    if (runTaskResult != null) 'runTaskResult': runTaskResult!.toJson(),
    if (bundleSummary != null) 'bundleSummary': bundleSummary!.toJson(),
    if (blockedReason != null) 'blockedReason': blockedReason,
    if (warnings.isNotEmpty) 'warnings': warnings,
    'validationFailures': validationFailures
        .map((failure) => failure.toJson())
        .toList(growable: false),
  };
}

final class CockpitValidateTaskService {
  CockpitValidateTaskService({
    CockpitValidateTaskFunction? validateTask,
    CockpitTaskOrchestrationService? orchestrationService,
    CockpitRunTaskService? runTaskService,
    CockpitTaskOrchestrationFunction? orchestrateTask,
    CockpitRunTaskFunction? runTask,
    CockpitBundleArtifactValidator? artifactValidator,
  }) : _validateTaskOverride = validateTask,
       _orchestrateTask = runTask == null && runTaskService == null
           ? (orchestrateTask ??
                 (orchestrationService ?? CockpitTaskOrchestrationService())
                     .orchestrate)
           : null,
       _runTask = runTask ?? runTaskService?.run,
       _artifactValidator =
           artifactValidator ?? CockpitBundleArtifactValidator();

  final CockpitValidateTaskFunction? _validateTaskOverride;
  final CockpitTaskOrchestrationFunction? _orchestrateTask;
  final CockpitRunTaskFunction? _runTask;
  final CockpitBundleArtifactValidator _artifactValidator;

  Future<CockpitValidateTaskResult> validate(
    CockpitValidateTaskRequest request,
  ) async {
    final override = _validateTaskOverride;
    if (override != null) {
      return override(request);
    }

    final runTaskResult = await _runTaskWorkflow(request.runTask);
    final bundleSummary = runTaskResult.bundleSummary;
    final validationFailures = bundleSummary == null
        ? const <CockpitValidationFailure>[]
        : await _collectValidationFailures(
            bundleSummary: bundleSummary,
            requirements: request.validation,
            actualClassification: runTaskResult.classification,
          );

    final classification = _classify(
      runTaskClassification: runTaskResult.classification,
      validationFailures: validationFailures,
    );

    return CockpitValidateTaskResult(
      classification: classification,
      recommendedNextStep: _recommendedNextStep(
        classification,
        bundleSummary: bundleSummary,
      ),
      runTaskResult: runTaskResult,
      bundleSummary: bundleSummary,
      blockedReason: runTaskResult.blockedReason,
      validationFailures: validationFailures,
      warnings: runTaskResult.warnings,
    );
  }

  Future<CockpitRunTaskResult> _runTaskWorkflow(
    CockpitRunTaskRequest request,
  ) async {
    final runTask = _runTask;
    if (runTask != null) {
      return runTask(request);
    }

    final orchestration = await _orchestrateTask!(request);
    return CockpitRunTaskResult(
      classification: orchestration.classification,
      recommendedNextStep: orchestration.recommendedNextStep,
      sessionHandle: orchestration.sessionHandle,
      preflightStatus: orchestration.preflightStatus,
      bundleSummary: orchestration.bundleSummary,
      blockedReason: orchestration.blockedReason,
      warnings: orchestration.warnings,
    );
  }

  Future<List<CockpitValidationFailure>> _collectValidationFailures({
    required CockpitReadTaskBundleSummaryResult bundleSummary,
    required CockpitValidateTaskRequirements requirements,
    required CockpitRunTaskClassification actualClassification,
  }) async {
    final failures = <CockpitValidationFailure>[];
    final validatedArtifacts = <String>{};
    final gateSummary = bundleSummary.gateSummary;

    final expectedClassification = requirements.expectedClassification;
    if (expectedClassification != null &&
        expectedClassification != actualClassification) {
      failures.add(
        CockpitValidationFailure(
          code: 'unexpectedClassification',
          message: 'Run task classification does not match the expected value.',
          details: <String, Object?>{
            'expected': expectedClassification.jsonValue,
            'actual': actualClassification.jsonValue,
          },
        ),
      );
    }

    if (requirements.requireAcceptanceMarkdown) {
      final acceptanceFile = File(
        _bundleFilePath(bundleSummary.bundleDir, 'acceptance.md'),
      );
      if (!acceptanceFile.existsSync()) {
        failures.add(
          const CockpitValidationFailure(
            code: 'acceptanceMissing',
            message: 'acceptance.md is required but missing.',
          ),
        );
      } else {
        final contents = acceptanceFile.readAsStringSync();
        if (contents.trim().isEmpty) {
          failures.add(
            const CockpitValidationFailure(
              code: 'acceptanceEmpty',
              message: 'acceptance.md is present but empty.',
            ),
          );
        }
      }
    }

    if (requirements.requireEnvironmentSnapshot) {
      final environmentFile = File(
        _bundleFilePath(bundleSummary.bundleDir, 'environment.json'),
      );
      if (!environmentFile.existsSync()) {
        failures.add(
          const CockpitValidationFailure(
            code: 'environmentMissing',
            message: 'environment.json is required but missing.',
          ),
        );
      } else {
        final decoded = jsonDecode(environmentFile.readAsStringSync());
        if (decoded is! Map<Object?, Object?> || decoded.isEmpty) {
          failures.add(
            const CockpitValidationFailure(
              code: 'environmentInvalid',
              message: 'environment.json must decode to a non-empty object.',
            ),
          );
        }
      }
    }

    if (requirements.requirePrimaryScreenshot) {
      final screenshotPath = bundleSummary.artifactPaths.primaryScreenshotPath;
      final screenshotReady =
          gateSummary.isSatisfied(CockpitTaskGate.screenshotReady) ||
          _hasPrimaryScreenshotEvidence(bundleSummary);
      if (!screenshotReady) {
        failures.add(
          _gateFailure(
            gate: CockpitTaskGate.screenshotReady,
            gateSummary: gateSummary,
            fallbackCode: 'primaryScreenshotMissing',
            message:
                'A primary screenshot is required but the screenshot gate failed.',
            details: <String, Object?>{'primaryScreenshotPath': screenshotPath},
          ),
        );
      } else if (screenshotPath != null && screenshotPath.isNotEmpty) {
        if (!File(screenshotPath).existsSync()) {
          failures.add(
            CockpitValidationFailure(
              code: 'acceptanceScreenshotMissing',
              message:
                  'The primary screenshot is referenced but missing from the bundle.',
              details: <String, Object?>{
                'primaryScreenshotPath': screenshotPath,
              },
            ),
          );
        }
        validatedArtifacts.add(screenshotPath);
        final failure = await _validateScreenshotArtifact(screenshotPath);
        if (failure != null) {
          failures.add(failure);
        }
      }
    }

    if (requirements.requirePrimaryRecording) {
      final recordingPath = bundleSummary.artifactPaths.primaryRecordingPath;
      final recordingReady =
          gateSummary.isSatisfied(CockpitTaskGate.recordingReadyOrExplained) ||
          _hasPrimaryRecordingEvidence(bundleSummary);
      if (!recordingReady) {
        failures.add(
          _gateFailure(
            gate: CockpitTaskGate.recordingReadyOrExplained,
            gateSummary: gateSummary,
            fallbackCode: 'primaryRecordingMissing',
            message:
                'A primary recording is required but the recording gate failed.',
            details: <String, Object?>{'primaryRecordingPath': recordingPath},
          ),
        );
      } else if (recordingPath != null && recordingPath.isNotEmpty) {
        if (!File(recordingPath).existsSync()) {
          failures.add(
            CockpitValidationFailure(
              code: 'acceptanceRecordingMissing',
              message:
                  'The primary recording is referenced but missing from the bundle.',
              details: <String, Object?>{'primaryRecordingPath': recordingPath},
            ),
          );
        }
        validatedArtifacts.add(recordingPath);
        final failure = await _validateRecordingArtifact(recordingPath);
        if (failure != null) {
          failures.add(failure);
        }
      }
    }

    final acceptanceComparisonFailures = _validateAcceptanceComparisonEvidence(
      bundleSummary: bundleSummary,
      requireSemanticSignals: requirements.requireAcceptanceSemanticEvidence,
    );
    failures.addAll(acceptanceComparisonFailures);

    if (requirements.requireAcceptanceSemanticEvidence) {
      final acceptanceEvidence = bundleSummary.acceptanceEvidence;
      if (acceptanceEvidence == null ||
          !acceptanceEvidence.hasSemanticSignals) {
        failures.add(
          CockpitValidationFailure(
            code: 'acceptanceSemanticEvidenceMissing',
            message: 'Semantic acceptance evidence is required but missing.',
            details: <String, Object?>{
              'hasAcceptanceEvidence': acceptanceEvidence != null,
              'diagnosticsArtifactPath':
                  acceptanceEvidence?.diagnosticsArtifactPath,
              'routeName': acceptanceEvidence?.routeName,
              'visibleTargetCount': acceptanceEvidence?.visibleTargetCount ?? 0,
              'accessibilityEntryCount':
                  acceptanceEvidence?.accessibilityEntryCount ?? 0,
            },
          ),
        );
      }
    }

    if (requirements.requireArtifactFiles) {
      final screenshotPaths = <String>[
        if (bundleSummary.artifactPaths.primaryScreenshotPath != null)
          bundleSummary.artifactPaths.primaryScreenshotPath!,
        ...bundleSummary.artifactPaths.attachmentPaths,
      ];
      for (final path in screenshotPaths) {
        if (validatedArtifacts.add(path)) {
          final failure = await _validateScreenshotArtifact(path);
          if (failure != null) {
            failures.add(failure);
          }
        }
      }

      final recordingPaths = <String>[
        if (bundleSummary.artifactPaths.primaryRecordingPath != null)
          bundleSummary.artifactPaths.primaryRecordingPath!,
        ...bundleSummary.artifactPaths.videoAttachmentPaths,
      ];
      for (final path in recordingPaths) {
        if (validatedArtifacts.add(path)) {
          final failure = await _validateRecordingArtifact(path);
          if (failure != null) {
            failures.add(failure);
          }
        }
      }
    }

    final primaryScreenshotPath =
        bundleSummary.artifactPaths.primaryScreenshotPath;
    final primaryRecordingPath =
        bundleSummary.artifactPaths.primaryRecordingPath;

    if (bundleSummary.manifest.runtimeErrorCount > 0) {
      failures.add(
        CockpitValidationFailure(
          code: 'runtimeErrorsDetected',
          message:
              'Runtime errors were captured during the task and block completion.',
          details: <String, Object?>{
            'runtimeErrorCount': bundleSummary.manifest.runtimeErrorCount,
            'runtimeEventCount': bundleSummary.manifest.runtimeEventCount,
          },
        ),
      );
    }

    failures.addAll(
      _collectPlaneAwareGateFailures(bundleSummary: bundleSummary),
    );
    failures.addAll(
      _validateDeliveryAttachmentRefs(bundleSummary: bundleSummary),
    );
    failures.addAll(
      _validateManifestArtifactRefs(bundleSummary: bundleSummary),
    );
    failures.addAll(
      _validateDiagnosticsArtifactRefs(bundleSummary: bundleSummary),
    );

    if (primaryScreenshotPath != null &&
        primaryScreenshotPath.isNotEmpty &&
        primaryRecordingPath != null &&
        primaryRecordingPath.isNotEmpty) {
      final keyframes = _readRecordingKeyframes(bundleSummary.delivery);
      if (keyframes.isEmpty) {
        failures.add(
          const CockpitValidationFailure(
            code: 'recordingKeyframesMissing',
            message:
                'A primary recording is present but no extracted keyframes were included in the delivery bundle.',
          ),
        );
      } else {
        failures.addAll(
          _validateRecordingKeyframeRefs(
            bundleSummary: bundleSummary,
            keyframes: keyframes,
          ),
        );
        for (final path in bundleSummary.artifactPaths.keyframePaths) {
          if (validatedArtifacts.add(path)) {
            final failure = await _validateScreenshotArtifact(path);
            if (failure != null) {
              failures.add(failure);
            }
          }
        }

        final coverageJson =
            bundleSummary.delivery['keyframeCoverage']
                as Map<Object?, Object?>?;
        final durationMs = coverageJson == null
            ? 0
            : (Map<String, Object?>.from(coverageJson)['durationMs'] as int? ??
                  0);
        final failure = _validateRecordingCoverage(
          durationMs: durationMs,
          keyframes: keyframes,
        );
        if (failure != null) {
          failures.add(failure);
        }
      }

      final failure = await _validateDeliveryConsistency(
        screenshotPath: primaryScreenshotPath,
        recordingPath: primaryRecordingPath,
        candidateFramePaths: _deliveryConsistencyFramePaths(
          bundleSummary: bundleSummary,
          screenshotPath: primaryScreenshotPath,
        ),
      );
      if (failure != null) {
        failures.add(failure);
      }
    }

    return List<CockpitValidationFailure>.unmodifiable(failures);
  }

  List<CockpitValidationFailure> _validateDiagnosticsArtifactRefs({
    required CockpitReadTaskBundleSummaryResult bundleSummary,
  }) {
    final failures = <CockpitValidationFailure>[];
    for (final ref in CockpitBundleDiagnosticsArtifactRefs.readBundleRefs(
      bundleSummary.bundleDir,
    )) {
      final resolvedPath = CockpitBundleDiagnosticsArtifactRefs.resolvePath(
        bundleSummary.bundleDir,
        ref.relativePath,
      );
      if (resolvedPath == null) {
        failures.add(
          CockpitValidationFailure(
            code: 'diagnosticsArtifactRefInvalid',
            message:
                'Diagnostic artifact refs must point to bundle-local files under diagnostics/.',
            details: <String, Object?>{
              'role': ref.role,
              'relativePath': ref.relativePath,
            },
          ),
        );
        continue;
      }
      if (!File(resolvedPath).existsSync()) {
        failures.add(
          CockpitValidationFailure(
            code: 'diagnosticsArtifactMissing',
            message:
                'A diagnostic artifact ref points to a file that is missing from the bundle.',
            details: <String, Object?>{
              'role': ref.role,
              'relativePath': ref.relativePath,
              'path': resolvedPath,
            },
          ),
        );
      }
    }
    return List<CockpitValidationFailure>.unmodifiable(failures);
  }

  List<CockpitValidationFailure> _validateManifestArtifactRefs({
    required CockpitReadTaskBundleSummaryResult bundleSummary,
  }) {
    final failures = <CockpitValidationFailure>[];
    for (final artifact in bundleSummary.manifest.artifactRefs) {
      if (artifact.relativePath.isEmpty) {
        failures.add(
          CockpitValidationFailure(
            code: 'manifestArtifactRefInvalid',
            message:
                'manifest.artifactRefs entries must use non-empty bundle-relative paths.',
            details: <String, Object?>{
              'role': artifact.role,
              'relativePath': artifact.relativePath,
            },
          ),
        );
        continue;
      }

      final allowedRoots =
          CockpitBundleArtifactPaths.allowedRootsForArtifactRole(artifact.role);
      final resolvedPath = CockpitBundleArtifactPaths.resolveBundleArtifactPath(
        bundleSummary.bundleDir,
        artifact.relativePath,
        allowedRoots: allowedRoots,
      );
      if (resolvedPath == null) {
        failures.add(
          CockpitValidationFailure(
            code: 'manifestArtifactRefInvalid',
            message:
                'manifest.artifactRefs entries must point to bundle-local artifact files under the expected evidence directory.',
            details: <String, Object?>{
              'role': artifact.role,
              'relativePath': artifact.relativePath,
              'allowedRoots': allowedRoots.toList(growable: false),
            },
          ),
        );
        continue;
      }
      if (!File(resolvedPath).existsSync()) {
        failures.add(
          CockpitValidationFailure(
            code: 'manifestArtifactMissing',
            message:
                'manifest.artifactRefs references a file that is missing from the bundle.',
            details: <String, Object?>{
              'role': artifact.role,
              'relativePath': artifact.relativePath,
              'path': resolvedPath,
            },
          ),
        );
      }
    }
    return List<CockpitValidationFailure>.unmodifiable(failures);
  }

  List<CockpitValidationFailure> _validateDeliveryAttachmentRefs({
    required CockpitReadTaskBundleSummaryResult bundleSummary,
  }) {
    final failures = <CockpitValidationFailure>[];
    failures.addAll(
      _validateDeliveryRefList(
        bundleDir: bundleSummary.bundleDir,
        delivery: bundleSummary.delivery,
        fieldName: 'attachmentRefs',
        codePrefix: 'deliveryAttachment',
        allowedRoots: const <String>{'screenshots'},
      ),
    );
    failures.addAll(
      _validateDeliveryRefList(
        bundleDir: bundleSummary.bundleDir,
        delivery: bundleSummary.delivery,
        fieldName: 'videoAttachmentRefs',
        codePrefix: 'deliveryVideoAttachment',
        allowedRoots: const <String>{'recordings'},
      ),
    );
    return List<CockpitValidationFailure>.unmodifiable(failures);
  }

  List<CockpitValidationFailure> _validateDeliveryRefList({
    required String bundleDir,
    required Map<String, Object?> delivery,
    required String fieldName,
    required String codePrefix,
    required Set<String> allowedRoots,
  }) {
    final rawRefs = delivery[fieldName];
    if (rawRefs == null) {
      return const <CockpitValidationFailure>[];
    }
    if (rawRefs is! List<Object?>) {
      return <CockpitValidationFailure>[
        CockpitValidationFailure(
          code: '${codePrefix}RefsInvalid',
          message: '$fieldName must be a list of bundle-relative paths.',
          details: <String, Object?>{'fieldName': fieldName},
        ),
      ];
    }

    final failures = <CockpitValidationFailure>[];
    for (final rawRef in rawRefs) {
      if (rawRef is! String || rawRef.isEmpty) {
        failures.add(
          CockpitValidationFailure(
            code: '${codePrefix}RefInvalid',
            message: '$fieldName entries must be non-empty strings.',
            details: <String, Object?>{'fieldName': fieldName, 'ref': rawRef},
          ),
        );
        continue;
      }
      final resolvedPath = CockpitBundleArtifactPaths.resolveBundleArtifactPath(
        bundleDir,
        rawRef,
        allowedRoots: allowedRoots,
      );
      if (resolvedPath == null) {
        failures.add(
          CockpitValidationFailure(
            code: '${codePrefix}RefInvalid',
            message:
                '$fieldName entries must point to bundle-local files under ${allowedRoots.join(', ')}.',
            details: <String, Object?>{
              'fieldName': fieldName,
              'ref': rawRef,
              'allowedRoots': allowedRoots.toList(growable: false),
            },
          ),
        );
        continue;
      }
      if (!File(resolvedPath).existsSync()) {
        failures.add(
          CockpitValidationFailure(
            code: '${codePrefix}Missing',
            message:
                '$fieldName references a file that is missing from the bundle.',
            details: <String, Object?>{
              'fieldName': fieldName,
              'ref': rawRef,
              'path': resolvedPath,
            },
          ),
        );
      }
    }
    return List<CockpitValidationFailure>.unmodifiable(failures);
  }

  CockpitValidationClassification _classify({
    required CockpitRunTaskClassification runTaskClassification,
    required List<CockpitValidationFailure> validationFailures,
  }) {
    final hasTargetReachabilityFailure = validationFailures.any(
      (failure) => failure.code == 'targetUnreachable',
    );
    switch (runTaskClassification) {
      case CockpitRunTaskClassification.blockedByEnvironment:
        return CockpitValidationClassification.blockedByEnvironment;
      case CockpitRunTaskClassification.failedWithEvidence:
        return CockpitValidationClassification.failedWithEvidence;
      case CockpitRunTaskClassification.needsMoreWork:
        return CockpitValidationClassification.needsMoreWork;
      case CockpitRunTaskClassification.completed:
        if (hasTargetReachabilityFailure) {
          return CockpitValidationClassification.blockedByEnvironment;
        }
        return validationFailures.isEmpty
            ? CockpitValidationClassification.completed
            : CockpitValidationClassification.needsMoreWork;
    }
  }

  String _recommendedNextStep(
    CockpitValidationClassification classification, {
    CockpitReadTaskBundleSummaryResult? bundleSummary,
  }) {
    switch (classification) {
      case CockpitValidationClassification.completed:
        final gateSummary = bundleSummary?.gateSummary;
        if (gateSummary != null &&
            gateSummary.hasGate(CockpitTaskGate.intendedPlaneWorked) &&
            !gateSummary.isSatisfied(CockpitTaskGate.intendedPlaneWorked) &&
            (!gateSummary.hasGate(CockpitTaskGate.fallbackAcceptable) ||
                gateSummary.isSatisfied(CockpitTaskGate.fallbackAcceptable))) {
          return 'review_fallbacks';
        }
        return 'delivery_ready';
      case CockpitValidationClassification.failedWithEvidence:
        return 'inspect_bundle';
      case CockpitValidationClassification.blockedByEnvironment:
        return 'needs_relaunch';
      case CockpitValidationClassification.needsMoreWork:
        return 'collect_missing_evidence';
    }
  }

  String _bundleFilePath(String bundleDir, String name) {
    return Directory(bundleDir).uri.resolve(name).toFilePath();
  }

  Future<CockpitValidationFailure?> _validateScreenshotArtifact(
    String path,
  ) async {
    final result = await _artifactValidator.validateScreenshot(path);
    if (result.isValid) {
      return null;
    }
    return CockpitValidationFailure(
      code: result.code,
      message: result.message,
      details: <String, Object?>{
        'path': path,
        'validator': result.validator,
        ...result.details,
      },
    );
  }

  Future<CockpitValidationFailure?> _validateRecordingArtifact(
    String path,
  ) async {
    final result = await _artifactValidator.validateRecording(path);
    if (result.isValid) {
      return null;
    }
    return CockpitValidationFailure(
      code: result.code,
      message: result.message,
      details: <String, Object?>{
        'path': path,
        'validator': result.validator,
        ...result.details,
      },
    );
  }

  Future<CockpitValidationFailure?> _validateDeliveryConsistency({
    required String screenshotPath,
    required String recordingPath,
    required List<String> candidateFramePaths,
  }) async {
    final result = await _artifactValidator.validateDeliveryConsistency(
      screenshotPath: screenshotPath,
      recordingPath: recordingPath,
      candidateFramePaths: candidateFramePaths,
    );
    if (result.isValid) {
      return null;
    }
    return CockpitValidationFailure(
      code: result.code,
      message: result.message,
      details: <String, Object?>{
        'screenshotPath': screenshotPath,
        'recordingPath': recordingPath,
        'validator': result.validator,
        ...result.details,
      },
    );
  }

  List<String> _deliveryConsistencyFramePaths({
    required CockpitReadTaskBundleSummaryResult bundleSummary,
    required String screenshotPath,
  }) {
    final prioritizedKeyframes = bundleSummary.evidence.keyframes.toList()
      ..sort(
        (left, right) =>
            _deliveryConsistencyPriority(
              keyframe: left,
              screenshotPath: screenshotPath,
            ).compareTo(
              _deliveryConsistencyPriority(
                keyframe: right,
                screenshotPath: screenshotPath,
              ),
            ),
      );

    final paths = <String>[];
    final seen = <String>{};
    for (final keyframe in prioritizedKeyframes) {
      if (keyframe.path.isEmpty || !seen.add(keyframe.path)) {
        continue;
      }
      paths.add(keyframe.path);
    }
    return List<String>.unmodifiable(paths);
  }

  int _deliveryConsistencyPriority({
    required CockpitBundleEvidenceKeyframe keyframe,
    required String screenshotPath,
  }) {
    if (keyframe.linkedScreenshotPath == screenshotPath) {
      return 0;
    }
    return switch (keyframe.label) {
      'acceptance' => 1,
      'tail_consistency' => 2,
      'midpoint' => 3,
      'baseline' => 4,
      _ => 5,
    };
  }

  List<CockpitRecordingKeyframe> _readRecordingKeyframes(
    Map<String, Object?> delivery,
  ) {
    final rawKeyframes = delivery['keyframes'] as List<Object?>?;
    if (rawKeyframes == null) {
      return const <CockpitRecordingKeyframe>[];
    }
    return rawKeyframes
        .whereType<Map<Object?, Object?>>()
        .map(
          (item) => CockpitRecordingKeyframe.fromJson(
            Map<String, Object?>.from(item),
          ),
        )
        .toList(growable: false);
  }

  List<CockpitValidationFailure> _validateRecordingKeyframeRefs({
    required CockpitReadTaskBundleSummaryResult bundleSummary,
    required List<CockpitRecordingKeyframe> keyframes,
  }) {
    final failures = <CockpitValidationFailure>[];
    final seenRefs = <String>{};
    for (final keyframe in keyframes) {
      final ref = keyframe.relativePath;
      if (ref.isEmpty) {
        failures.add(
          CockpitValidationFailure(
            code: 'recordingKeyframeRefMissing',
            message:
                'A recording keyframe entry is missing its bundle-relative ref.',
            details: <String, Object?>{
              'label': keyframe.label,
              'offsetMs': keyframe.offsetMs,
              'source': keyframe.source.name,
            },
          ),
        );
        continue;
      }

      final resolvedPath = CockpitBundleArtifactPaths.resolveBundleArtifactPath(
        bundleSummary.bundleDir,
        ref,
        allowedRoots: const <String>{'keyframes'},
      );
      if (resolvedPath == null) {
        failures.add(
          CockpitValidationFailure(
            code: 'recordingKeyframeRefInvalid',
            message:
                'Recording keyframe refs must point to bundle-local files under keyframes/.',
            details: <String, Object?>{
              'ref': ref,
              'label': keyframe.label,
              'offsetMs': keyframe.offsetMs,
              'source': keyframe.source.name,
            },
          ),
        );
        continue;
      }

      if (!File(resolvedPath).existsSync()) {
        failures.add(
          CockpitValidationFailure(
            code: 'recordingKeyframeMissing',
            message:
                'A recording keyframe is referenced but missing from the bundle.',
            details: <String, Object?>{
              'ref': ref,
              'path': resolvedPath,
              'label': keyframe.label,
              'offsetMs': keyframe.offsetMs,
              'source': keyframe.source.name,
            },
          ),
        );
        continue;
      }

      seenRefs.add(ref);
    }

    final indexedRefs = bundleSummary.evidence.keyframes
        .map((keyframe) => keyframe.ref)
        .where((ref) => ref.isNotEmpty)
        .toSet();
    for (final ref in seenRefs.difference(indexedRefs)) {
      failures.add(
        CockpitValidationFailure(
          code: 'recordingKeyframeNotIndexed',
          message:
              'A recording keyframe ref is not present in the sanitized bundle evidence index.',
          details: <String, Object?>{'ref': ref},
        ),
      );
    }

    return List<CockpitValidationFailure>.unmodifiable(failures);
  }

  CockpitValidationFailure? _validateRecordingCoverage({
    required int durationMs,
    required List<CockpitRecordingKeyframe> keyframes,
  }) {
    final result = _artifactValidator.validateRecordingCoverage(
      durationMs: durationMs,
      keyframes: keyframes,
    );
    if (result.isValid) {
      return null;
    }
    return CockpitValidationFailure(
      code: result.code,
      message: result.message,
      details: <String, Object?>{
        'validator': result.validator,
        ...result.details,
      },
    );
  }

  List<CockpitValidationFailure> _validateAcceptanceComparisonEvidence({
    required CockpitReadTaskBundleSummaryResult bundleSummary,
    required bool requireSemanticSignals,
  }) {
    final requiresComparison =
        (bundleSummary.artifactPaths.primaryScreenshotPath?.isNotEmpty ??
            false) ||
        requireSemanticSignals;
    if (!requiresComparison) {
      return const <CockpitValidationFailure>[];
    }

    final gateSummary = bundleSummary.gateSummary;
    final hasDirectComparisonEvidence =
        bundleSummary.baselineEvidence != null &&
        bundleSummary.acceptanceEvidence != null &&
        bundleSummary.acceptanceDelta != null;
    if (!gateSummary.isSatisfied(CockpitTaskGate.acceptanceEvidenceReadable) &&
        !hasDirectComparisonEvidence) {
      final failureCodes = gateSummary.failureCodesFor(
        CockpitTaskGate.acceptanceEvidenceReadable,
      );
      final code =
          failureCodes.any(
            (failureCode) =>
                failureCode == 'baselineEvidenceMissing' ||
                failureCode == 'acceptanceEvidenceMissing' ||
                failureCode == 'acceptanceDeltaMissing',
          )
          ? 'acceptanceComparisonEvidenceMissing'
          : 'acceptanceComparisonEvidenceInsufficient';
      return <CockpitValidationFailure>[
        CockpitValidationFailure(
          code: code,
          message:
              'AI-facing acceptance comparison evidence is incomplete for the primary delivery screenshot.',
          details: <String, Object?>{
            'gate': CockpitTaskGate.acceptanceEvidenceReadable.name,
            'failureCodes': failureCodes,
            'primaryScreenshotPath':
                bundleSummary.artifactPaths.primaryScreenshotPath,
            'hasBaselineEvidence': bundleSummary.baselineEvidence != null,
            'hasAcceptanceEvidence': bundleSummary.acceptanceEvidence != null,
            'hasAcceptanceDelta': bundleSummary.acceptanceDelta != null,
          },
        ),
      ];
    }

    final resolvedBaselineEvidence = bundleSummary.baselineEvidence!;
    final resolvedAcceptanceEvidence = bundleSummary.acceptanceEvidence!;

    if (!resolvedBaselineEvidence.hasComparableSignals ||
        !resolvedAcceptanceEvidence.hasComparableSignals) {
      return <CockpitValidationFailure>[
        CockpitValidationFailure(
          code: 'acceptanceComparisonEvidenceInsufficient',
          message:
              'Acceptance comparison evidence exists but does not provide enough bounded state for AI review.',
          details: <String, Object?>{
            'baselineRouteName': resolvedBaselineEvidence.routeName,
            'acceptanceRouteName': resolvedAcceptanceEvidence.routeName,
            'baselineVisibleTargetCount':
                resolvedBaselineEvidence.visibleTargetCount,
            'acceptanceVisibleTargetCount':
                resolvedAcceptanceEvidence.visibleTargetCount,
            'baselineAccessibilityEntryCount':
                resolvedBaselineEvidence.accessibilityEntryCount,
            'acceptanceAccessibilityEntryCount':
                resolvedAcceptanceEvidence.accessibilityEntryCount,
            'baselineHasSemanticSignals':
                resolvedBaselineEvidence.hasSemanticSignals,
            'acceptanceHasSemanticSignals':
                resolvedAcceptanceEvidence.hasSemanticSignals,
          },
        ),
      ];
    }

    return const <CockpitValidationFailure>[];
  }

  bool _hasPrimaryScreenshotEvidence(
    CockpitReadTaskBundleSummaryResult bundleSummary,
  ) {
    final screenshotPath = bundleSummary.artifactPaths.primaryScreenshotPath;
    return bundleSummary.manifest.deliveryArtifactsReady ||
        (screenshotPath != null && screenshotPath.isNotEmpty);
  }

  bool _hasPrimaryRecordingEvidence(
    CockpitReadTaskBundleSummaryResult bundleSummary,
  ) {
    final recordingPath = bundleSummary.artifactPaths.primaryRecordingPath;
    return bundleSummary.manifest.deliveryVideoReady ||
        (recordingPath != null && recordingPath.isNotEmpty);
  }

  CockpitValidationFailure _gateFailure({
    required CockpitTaskGate gate,
    required CockpitBundleGateSummary gateSummary,
    required String fallbackCode,
    required String message,
    Map<String, Object?> details = const <String, Object?>{},
  }) {
    final failureCodes = gateSummary.failureCodesFor(gate);
    return CockpitValidationFailure(
      code: failureCodes.isEmpty ? fallbackCode : failureCodes.first,
      message: message,
      details: <String, Object?>{
        'gate': gate.name,
        'failureCodes': failureCodes,
        ...details,
      },
    );
  }

  List<CockpitValidationFailure> _collectPlaneAwareGateFailures({
    required CockpitReadTaskBundleSummaryResult bundleSummary,
  }) {
    final gateSummary = bundleSummary.gateSummary;
    final failures = <CockpitValidationFailure>[];

    if (gateSummary.hasGate(CockpitTaskGate.targetReachable) &&
        !gateSummary.isSatisfied(CockpitTaskGate.targetReachable)) {
      failures.add(
        _gateFailure(
          gate: CockpitTaskGate.targetReachable,
          gateSummary: gateSummary,
          fallbackCode: 'targetUnreachable',
          message: 'The target could not be reached reliably.',
        ),
      );
    }

    if (gateSummary.hasGate(CockpitTaskGate.fallbackAcceptable) &&
        !gateSummary.isSatisfied(CockpitTaskGate.fallbackAcceptable)) {
      failures.add(
        _gateFailure(
          gate: CockpitTaskGate.fallbackAcceptable,
          gateSummary: gateSummary,
          fallbackCode: 'fallbackNotAcceptable',
          message:
              'Execution required a fallback path, but the fallback outcome is not acceptable for delivery.',
          details: <String, Object?>{
            'intendedPlaneWorked': gateSummary.isSatisfied(
              CockpitTaskGate.intendedPlaneWorked,
            ),
          },
        ),
      );
    }

    return failures;
  }
}

bool? _readOptionalBool(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is bool) {
    return value;
  }
  throw ArgumentError.value(value, key, 'Expected a boolean field.');
}

Map<String, Object?> _readRequiredObject(
  Map<String, Object?> json,
  String key,
) {
  final value = _readOptionalObject(json, key);
  if (value == null) {
    throw ArgumentError.value(json, key, 'Missing required object field.');
  }
  return value;
}

Map<String, Object?>? _readOptionalObject(
  Map<String, Object?> json,
  String key,
) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is Map<Object?, Object?>) {
    return Map<String, Object?>.from(value);
  }
  throw ArgumentError.value(value, key, 'Expected an object field.');
}

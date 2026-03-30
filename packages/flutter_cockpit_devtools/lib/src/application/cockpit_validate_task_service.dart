import 'dart:convert';
import 'dart:io';

import '../artifacts/cockpit_recording_keyframe_extractor.dart';
import '../validation/cockpit_bundle_artifact_validator.dart';
import 'cockpit_read_task_bundle_summary_service.dart';
import 'cockpit_run_task_service.dart';
import 'cockpit_task_gate.dart';
import 'cockpit_task_orchestration_service.dart';

typedef CockpitValidateTaskFunction = Future<CockpitValidateTaskResult>
    Function(
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
        'expectedClassification': expectedClassification?.jsonValue,
        'requireAcceptanceMarkdown': requireAcceptanceMarkdown,
        'requireEnvironmentSnapshot': requireEnvironmentSnapshot,
        'requirePrimaryScreenshot': requirePrimaryScreenshot,
        'requirePrimaryRecording': requirePrimaryRecording,
        'requireArtifactFiles': requireArtifactFiles,
        'requireAcceptanceSemanticEvidence': requireAcceptanceSemanticEvidence,
      };

  factory CockpitValidateTaskRequirements.fromJson(Map<String, Object?> json) {
    final expectedClassificationValue =
        json['expectedClassification'] ?? json['expected_classification'];
    return CockpitValidateTaskRequirements(
      expectedClassification: expectedClassificationValue == null
          ? null
          : CockpitRunTaskClassification.fromJson(expectedClassificationValue),
      requireAcceptanceMarkdown: _readOptionalBool(
            json,
            'requireAcceptanceMarkdown',
            'require_acceptance_markdown',
          ) ??
          false,
      requireEnvironmentSnapshot: _readOptionalBool(
            json,
            'requireEnvironmentSnapshot',
            'require_environment_snapshot',
          ) ??
          false,
      requirePrimaryScreenshot: _readOptionalBool(
            json,
            'requirePrimaryScreenshot',
            'require_primary_screenshot',
          ) ??
          false,
      requirePrimaryRecording: _readOptionalBool(
            json,
            'requirePrimaryRecording',
            'require_primary_recording',
          ) ??
          false,
      requireArtifactFiles: _readOptionalBool(
            json,
            'requireArtifactFiles',
            'require_artifact_files',
          ) ??
          false,
      requireAcceptanceSemanticEvidence: _readOptionalBool(
            json,
            'requireAcceptanceSemanticEvidence',
            'require_acceptance_semantic_evidence',
          ) ??
          false,
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
    final runTaskJson = _readRequiredObject(json, 'runTask', 'run_task');
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
  });

  final CockpitValidationClassification classification;
  final String recommendedNextStep;
  final CockpitRunTaskResult? runTaskResult;
  final CockpitReadTaskBundleSummaryResult? bundleSummary;
  final String? blockedReason;
  final List<CockpitValidationFailure> validationFailures;

  Map<String, Object?> toJson() => <String, Object?>{
        'classification': classification.jsonValue,
        'recommendedNextStep': recommendedNextStep,
        'runTaskResult': runTaskResult?.toJson(),
        'bundleSummary': bundleSummary?.toJson(),
        'blockedReason': blockedReason,
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
  })  : _validateTaskOverride = validateTask,
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
      recommendedNextStep: _recommendedNextStep(classification),
      runTaskResult: runTaskResult,
      bundleSummary: bundleSummary,
      blockedReason: runTaskResult.blockedReason,
      validationFailures: validationFailures,
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
      if (!gateSummary.isSatisfied(CockpitTaskGate.screenshotReady)) {
        failures.add(
          _gateFailure(
            gate: CockpitTaskGate.screenshotReady,
            gateSummary: gateSummary,
            fallbackCode: 'primaryScreenshotMissing',
            message:
                'A primary screenshot is required but the screenshot gate failed.',
            details: <String, Object?>{
              'primaryScreenshotPath': screenshotPath,
            },
          ),
        );
      } else if (screenshotPath != null && screenshotPath.isNotEmpty) {
        validatedArtifacts.add(screenshotPath);
        final failure = await _validateScreenshotArtifact(screenshotPath);
        if (failure != null) {
          failures.add(failure);
        }
      }
    }

    if (requirements.requirePrimaryRecording) {
      final recordingPath = bundleSummary.artifactPaths.primaryRecordingPath;
      if (!gateSummary.isSatisfied(CockpitTaskGate.recordingReadyOrExplained)) {
        failures.add(
          _gateFailure(
            gate: CockpitTaskGate.recordingReadyOrExplained,
            gateSummary: gateSummary,
            fallbackCode: 'primaryRecordingMissing',
            message:
                'A primary recording is required but the recording gate failed.',
            details: <String, Object?>{
              'primaryRecordingPath': recordingPath,
            },
          ),
        );
      } else if (recordingPath != null && recordingPath.isNotEmpty) {
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
        for (final path in bundleSummary.artifactPaths.keyframePaths) {
          if (validatedArtifacts.add(path)) {
            final failure = await _validateScreenshotArtifact(path);
            if (failure != null) {
              failures.add(failure);
            }
          }
        }

        final coverageJson = bundleSummary.delivery['keyframeCoverage']
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
      );
      if (failure != null) {
        failures.add(failure);
      }
    }

    return List<CockpitValidationFailure>.unmodifiable(failures);
  }

  CockpitValidationClassification _classify({
    required CockpitRunTaskClassification runTaskClassification,
    required List<CockpitValidationFailure> validationFailures,
  }) {
    switch (runTaskClassification) {
      case CockpitRunTaskClassification.blockedByEnvironment:
        return CockpitValidationClassification.blockedByEnvironment;
      case CockpitRunTaskClassification.failedWithEvidence:
        return CockpitValidationClassification.failedWithEvidence;
      case CockpitRunTaskClassification.needsMoreWork:
        return CockpitValidationClassification.needsMoreWork;
      case CockpitRunTaskClassification.completed:
        return validationFailures.isEmpty
            ? CockpitValidationClassification.completed
            : CockpitValidationClassification.needsMoreWork;
    }
  }

  String _recommendedNextStep(CockpitValidationClassification classification) {
    switch (classification) {
      case CockpitValidationClassification.completed:
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
  }) async {
    final result = await _artifactValidator.validateDeliveryConsistency(
      screenshotPath: screenshotPath,
      recordingPath: recordingPath,
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
    if (!gateSummary.isSatisfied(CockpitTaskGate.acceptanceEvidenceReadable)) {
      final failureCodes = gateSummary.failureCodesFor(
        CockpitTaskGate.acceptanceEvidenceReadable,
      );
      final code = failureCodes.any(
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
}

bool? _readOptionalBool(
  Map<String, Object?> json,
  String key, [
  String? alternateKey,
]) {
  final value = json[key] ?? (alternateKey == null ? null : json[alternateKey]);
  if (value == null) {
    return null;
  }
  if (value is bool) {
    return value;
  }
  throw ArgumentError.value(
    value,
    alternateKey ?? key,
    'Expected a boolean field.',
  );
}

Map<String, Object?> _readRequiredObject(
  Map<String, Object?> json,
  String key, [
  String? alternateKey,
]) {
  final value = _readOptionalObject(json, key, alternateKey);
  if (value == null) {
    throw ArgumentError.value(
      json,
      alternateKey ?? key,
      'Missing required object field.',
    );
  }
  return value;
}

Map<String, Object?>? _readOptionalObject(
  Map<String, Object?> json,
  String key, [
  String? alternateKey,
]) {
  final value = json[key] ?? (alternateKey == null ? null : json[alternateKey]);
  if (value == null) {
    return null;
  }
  if (value is Map<Object?, Object?>) {
    return Map<String, Object?>.from(value);
  }
  throw ArgumentError.value(
    value,
    alternateKey ?? key,
    'Expected an object field.',
  );
}

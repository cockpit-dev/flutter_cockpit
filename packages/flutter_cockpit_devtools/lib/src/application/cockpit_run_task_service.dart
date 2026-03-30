import 'package:flutter_cockpit/flutter_cockpit.dart';

import '../cli/cockpit_control_script.dart';
import '../session/cockpit_remote_session_handle.dart';
import 'cockpit_launch_remote_session_service.dart';
import 'cockpit_query_remote_session_service.dart';
import 'cockpit_read_task_bundle_summary_service.dart';
import 'cockpit_run_remote_control_script_service.dart';
import 'cockpit_task_orchestration_service.dart';

typedef CockpitLaunchTaskFunction = Future<CockpitLaunchRemoteSessionResult>
    Function(
  CockpitLaunchRemoteSessionRequest request,
);
typedef CockpitQueryTaskFunction = Future<CockpitQueryRemoteSessionResult>
    Function(
  CockpitQueryRemoteSessionRequest request,
);
typedef CockpitRunTaskScriptFunction
    = Future<CockpitRunRemoteControlScriptResult> Function(
  CockpitRunRemoteControlScriptRequest request,
);
typedef CockpitReadTaskSummaryFunction
    = Future<CockpitReadTaskBundleSummaryResult> Function(
  CockpitReadTaskBundleSummaryRequest request,
);
typedef CockpitRunTaskFunction = Future<CockpitRunTaskResult> Function(
    CockpitRunTaskRequest request);

enum CockpitRunTaskClassification {
  completed('completed'),
  failedWithEvidence('failed_with_evidence'),
  blockedByEnvironment('blocked_by_environment'),
  needsMoreWork('needs_more_work');

  const CockpitRunTaskClassification(this.jsonValue);

  final String jsonValue;

  static CockpitRunTaskClassification fromJson(Object? json) {
    return values.firstWhere(
      (value) => value.jsonValue == json,
      orElse: () => throw ArgumentError.value(
        json,
        'json',
        'Unsupported run task classification.',
      ),
    );
  }
}

final class CockpitRunTaskLaunchRequest {
  const CockpitRunTaskLaunchRequest({
    required this.projectDir,
    required this.platform,
    required this.deviceId,
    required this.sessionPort,
    this.target,
    this.launchTimeout = const Duration(seconds: 120),
    this.persistHandlePath,
  });

  final String projectDir;
  final String? target;
  final String platform;
  final String deviceId;
  final int sessionPort;
  final Duration launchTimeout;
  final String? persistHandlePath;

  Map<String, Object?> toJson() => <String, Object?>{
        'project_dir': projectDir,
        'target': target,
        'platform': platform,
        'device_id': deviceId,
        'session_port': sessionPort,
        'launch_timeout_seconds': launchTimeout.inSeconds,
        'persist_handle_path': persistHandlePath,
      };

  factory CockpitRunTaskLaunchRequest.fromJson(Map<String, Object?> json) {
    return CockpitRunTaskLaunchRequest(
      projectDir: _readRequiredString(json, 'projectDir', 'project_dir'),
      target: _readOptionalString(json, 'target'),
      platform: _readRequiredString(json, 'platform'),
      deviceId: _readRequiredString(json, 'deviceId', 'device_id'),
      sessionPort: _readRequiredInt(json, 'sessionPort', 'session_port'),
      launchTimeout: Duration(
        seconds: _readOptionalInt(
              json,
              'launchTimeoutSeconds',
              'launch_timeout_seconds',
            ) ??
            120,
      ),
      persistHandlePath: _readOptionalString(
        json,
        'persistHandlePath',
        'persist_handle_path',
      ),
    );
  }
}

final class CockpitRunTaskBaselineRequest {
  const CockpitRunTaskBaselineRequest({
    this.captureScreenshot = false,
    this.screenshotName = 'baseline',
    this.includeSnapshot = true,
  });

  final bool captureScreenshot;
  final String screenshotName;
  final bool includeSnapshot;

  Map<String, Object?> toJson() => <String, Object?>{
        'capture_screenshot': captureScreenshot,
        'screenshot_name': screenshotName,
        'include_snapshot': includeSnapshot,
      };

  factory CockpitRunTaskBaselineRequest.fromJson(Map<String, Object?> json) {
    return CockpitRunTaskBaselineRequest(
      captureScreenshot:
          _readOptionalBool(json, 'captureScreenshot', 'capture_screenshot') ??
              false,
      screenshotName:
          _readOptionalString(json, 'screenshotName', 'screenshot_name') ??
              'baseline',
      includeSnapshot:
          _readOptionalBool(json, 'includeSnapshot', 'include_snapshot') ??
              true,
    );
  }
}

final class CockpitRunTaskEvidenceRequirements {
  const CockpitRunTaskEvidenceRequirements({
    this.requireScreenshotEvidence = false,
    this.requireVideoEvidence = false,
  });

  final bool requireScreenshotEvidence;
  final bool requireVideoEvidence;

  Map<String, Object?> toJson() => <String, Object?>{
        'require_screenshot_evidence': requireScreenshotEvidence,
        'require_video_evidence': requireVideoEvidence,
      };

  factory CockpitRunTaskEvidenceRequirements.fromJson(
    Map<String, Object?> json,
  ) {
    return CockpitRunTaskEvidenceRequirements(
      requireScreenshotEvidence: _readOptionalBool(
            json,
            'requireScreenshotEvidence',
            'require_screenshot_evidence',
          ) ??
          false,
      requireVideoEvidence: _readOptionalBool(
            json,
            'requireVideoEvidence',
            'require_video_evidence',
          ) ??
          false,
    );
  }
}

final class CockpitRunTaskRequest {
  const CockpitRunTaskRequest({
    this.launch,
    this.sessionHandle,
    this.sessionHandlePath,
    required this.script,
    required this.outputRoot,
    this.persistScriptPath,
    this.baseline = const CockpitRunTaskBaselineRequest(),
    this.requirements = const CockpitRunTaskEvidenceRequirements(),
  });

  final CockpitRunTaskLaunchRequest? launch;
  final CockpitRemoteSessionHandle? sessionHandle;
  final String? sessionHandlePath;
  final CockpitControlScript script;
  final String outputRoot;
  final String? persistScriptPath;
  final CockpitRunTaskBaselineRequest baseline;
  final CockpitRunTaskEvidenceRequirements requirements;

  Map<String, Object?> toJson() => <String, Object?>{
        'launch': launch?.toJson(),
        'session_handle': sessionHandle?.toJson(),
        'session_handle_path': sessionHandlePath,
        'script': script.toJson(),
        'output_root': outputRoot,
        'persist_script_path': persistScriptPath,
        'baseline': baseline.toJson(),
        'requirements': requirements.toJson(),
      };

  factory CockpitRunTaskRequest.fromJson(Map<String, Object?> json) {
    final launchJson = _readOptionalObject(json, 'launch');
    final sessionHandleJson = _readOptionalObject(
      json,
      'sessionHandle',
      'session_handle',
    );
    final scriptJson = _readRequiredObject(json, 'script');
    final baselineJson = _readOptionalObject(json, 'baseline');
    final requirementsJson = _readOptionalObject(json, 'requirements');

    return CockpitRunTaskRequest(
      launch: launchJson == null
          ? null
          : CockpitRunTaskLaunchRequest.fromJson(launchJson),
      sessionHandle: sessionHandleJson == null
          ? null
          : CockpitRemoteSessionHandle.fromJson(sessionHandleJson),
      sessionHandlePath: _readOptionalString(
        json,
        'sessionHandlePath',
        'session_handle_path',
      ),
      script: CockpitControlScript.fromJson(scriptJson),
      outputRoot: _readRequiredString(json, 'outputRoot', 'output_root'),
      persistScriptPath: _readOptionalString(
        json,
        'persistScriptPath',
        'persist_script_path',
      ),
      baseline: baselineJson == null
          ? const CockpitRunTaskBaselineRequest()
          : CockpitRunTaskBaselineRequest.fromJson(baselineJson),
      requirements: requirementsJson == null
          ? const CockpitRunTaskEvidenceRequirements()
          : CockpitRunTaskEvidenceRequirements.fromJson(requirementsJson),
    );
  }
}

final class CockpitRunTaskResult {
  const CockpitRunTaskResult({
    required this.classification,
    required this.recommendedNextStep,
    this.sessionHandle,
    this.preflightStatus,
    this.bundleSummary,
    this.blockedReason,
  });

  final CockpitRunTaskClassification classification;
  final String recommendedNextStep;
  final CockpitRemoteSessionHandle? sessionHandle;
  final CockpitRemoteSessionStatus? preflightStatus;
  final CockpitReadTaskBundleSummaryResult? bundleSummary;
  final String? blockedReason;

  Map<String, Object?> toJson() => <String, Object?>{
        'classification': classification.jsonValue,
        'recommended_next_step': recommendedNextStep,
        'session_handle': sessionHandle?.toJson(),
        'preflight_status': preflightStatus?.toJson(),
        'blocked_reason': blockedReason,
        'bundle_summary': bundleSummary?.toJson(),
      };
}

final class CockpitRunTaskService {
  CockpitRunTaskService({
    CockpitRunTaskFunction? runTask,
    CockpitTaskOrchestrationService? orchestrationService,
    CockpitLaunchRemoteSessionService? launchService,
    CockpitQueryRemoteSessionService? queryService,
    CockpitRunRemoteControlScriptService? runScriptService,
    CockpitReadTaskBundleSummaryService? readSummaryService,
    CockpitTaskOrchestrationFunction? orchestrateTask,
    CockpitLaunchTaskFunction? launch,
    CockpitQueryTaskFunction? query,
    CockpitRunTaskScriptFunction? runScript,
    CockpitReadTaskSummaryFunction? readSummary,
  })  : _runTaskOverride = runTask,
        _orchestrateTask = orchestrateTask ??
            (orchestrationService ??
                    CockpitTaskOrchestrationService(
                      launchService: launchService,
                      queryService: queryService,
                      runScriptService: runScriptService,
                      readSummaryService: readSummaryService,
                      launch: launch,
                      query: query,
                      runScript: runScript,
                      readSummary: readSummary,
                    ))
                .orchestrate;

  final CockpitRunTaskFunction? _runTaskOverride;
  final CockpitTaskOrchestrationFunction _orchestrateTask;

  Future<CockpitRunTaskResult> run(CockpitRunTaskRequest request) async {
    final override = _runTaskOverride;
    if (override != null) {
      return override(request);
    }
    final orchestration = await _orchestrateTask(request);
    return CockpitRunTaskResult(
      classification: orchestration.classification,
      recommendedNextStep: orchestration.recommendedNextStep,
      sessionHandle: orchestration.sessionHandle,
      preflightStatus: orchestration.preflightStatus,
      bundleSummary: orchestration.bundleSummary,
      blockedReason: orchestration.blockedReason,
    );
  }
}

String _readRequiredString(
  Map<String, Object?> json,
  String key, [
  String? alternateKey,
]) {
  final value = _readOptionalString(json, key, alternateKey);
  if (value == null || value.isEmpty) {
    throw CockpitApplicationServiceException(
      code: 'invalidRunTaskRequest',
      message: 'Missing required string field.',
      details: <String, Object?>{'field': alternateKey ?? key},
    );
  }
  return value;
}

String? _readOptionalString(
  Map<String, Object?> json,
  String key, [
  String? alternateKey,
]) {
  final value = json[key] ?? (alternateKey == null ? null : json[alternateKey]);
  if (value == null) {
    return null;
  }
  if (value is String && value.isNotEmpty) {
    return value;
  }
  throw CockpitApplicationServiceException(
    code: 'invalidRunTaskRequest',
    message: 'Expected a non-empty string field.',
    details: <String, Object?>{'field': alternateKey ?? key},
  );
}

int _readRequiredInt(
  Map<String, Object?> json,
  String key, [
  String? alternateKey,
]) {
  final value = _readOptionalInt(json, key, alternateKey);
  if (value == null) {
    throw CockpitApplicationServiceException(
      code: 'invalidRunTaskRequest',
      message: 'Missing required integer field.',
      details: <String, Object?>{'field': alternateKey ?? key},
    );
  }
  return value;
}

int? _readOptionalInt(
  Map<String, Object?> json,
  String key, [
  String? alternateKey,
]) {
  final value = json[key] ?? (alternateKey == null ? null : json[alternateKey]);
  if (value == null) {
    return null;
  }
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  throw CockpitApplicationServiceException(
    code: 'invalidRunTaskRequest',
    message: 'Expected an integer field.',
    details: <String, Object?>{'field': alternateKey ?? key},
  );
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
  throw CockpitApplicationServiceException(
    code: 'invalidRunTaskRequest',
    message: 'Expected a boolean field.',
    details: <String, Object?>{'field': alternateKey ?? key},
  );
}

Map<String, Object?> _readRequiredObject(
  Map<String, Object?> json,
  String key, [
  String? alternateKey,
]) {
  final value = _readOptionalObject(json, key, alternateKey);
  if (value == null) {
    throw CockpitApplicationServiceException(
      code: 'invalidRunTaskRequest',
      message: 'Missing required object field.',
      details: <String, Object?>{'field': alternateKey ?? key},
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
  throw CockpitApplicationServiceException(
    code: 'invalidRunTaskRequest',
    message: 'Expected an object field.',
    details: <String, Object?>{'field': alternateKey ?? key},
  );
}

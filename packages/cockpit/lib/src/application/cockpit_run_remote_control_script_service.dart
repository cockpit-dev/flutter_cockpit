import 'dart:io';

import 'package:flutter_cockpit/flutter_cockpit.dart';

import '../adapters/cockpit_recording_adapter.dart';
import '../artifacts/task_run_bundle_writer.dart';
import '../capture/cockpit_capture_strategy_resolver.dart';
import '../cli/cockpit_control_script.dart';
import '../recording/cockpit_recording_strategy_resolver.dart';
import '../remote/cockpit_remote_automation_adapter.dart';
import '../remote/cockpit_remote_session_client.dart';
import '../runner/cockpit_control_runner.dart';
import '../session/cockpit_remote_session_handle.dart';
import 'cockpit_bundle_artifact_paths.dart';
import 'cockpit_application_service_exception.dart';
import 'cockpit_compact_json.dart';
import 'cockpit_read_task_bundle_summary_service.dart';
import 'cockpit_session_reference_resolver.dart';

final class CockpitRunRemoteControlScriptRequest {
  const CockpitRunRemoteControlScriptRequest({
    required this.script,
    required this.outputRoot,
    this.platformAppId,
    this.processId,
    this.baseUri,
    this.sessionHandle,
    this.sessionHandlePath,
    this.androidDeviceId,
    this.iosDeviceId,
    this.persistScriptPath,
    this.portForwardingHandled = false,
  });

  final CockpitControlScript script;
  final String outputRoot;
  final String? platformAppId;
  final int? processId;
  final Uri? baseUri;
  final CockpitRemoteSessionHandle? sessionHandle;
  final String? sessionHandlePath;
  final String? androidDeviceId;
  final String? iosDeviceId;
  final String? persistScriptPath;
  final bool portForwardingHandled;
}

final class CockpitRunRemoteControlScriptResult {
  const CockpitRunRemoteControlScriptResult({
    required this.sessionHandle,
    required this.bundleDir,
    required this.manifest,
    required this.handoff,
    required this.delivery,
    required this.artifactPaths,
  });

  final CockpitRemoteSessionHandle? sessionHandle;
  final Directory bundleDir;
  final CockpitRunManifest manifest;
  final Map<String, Object?> handoff;
  final Map<String, Object?> delivery;
  final CockpitBundleArtifactPaths artifactPaths;
}

final class CockpitRunRemoteControlScriptService {
  CockpitRunRemoteControlScriptService({
    CockpitSessionReferenceResolver? sessionReferenceResolver,
    CockpitCaptureStrategyResolver captureStrategyResolver =
        const CockpitCaptureStrategyResolver(),
    CockpitRecordingStrategyResolver recordingStrategyResolver =
        const CockpitRecordingStrategyResolver(),
    TaskRunBundleWriter writer = const TaskRunBundleWriter(),
    CockpitReadTaskBundleSummaryService readSummaryService =
        const CockpitReadTaskBundleSummaryService(),
    Duration environmentResolutionTimeout = const Duration(seconds: 10),
    Duration environmentResolutionRetryDelay = const Duration(
      milliseconds: 250,
    ),
  }) : _sessionReferenceResolver =
           sessionReferenceResolver ?? CockpitSessionReferenceResolver(),
       _captureStrategyResolver = captureStrategyResolver,
       _recordingStrategyResolver = recordingStrategyResolver,
       _writer = writer,
       _readSummaryService = readSummaryService,
       _environmentResolutionTimeout = environmentResolutionTimeout,
       _environmentResolutionRetryDelay = environmentResolutionRetryDelay;

  final CockpitSessionReferenceResolver _sessionReferenceResolver;
  final CockpitCaptureStrategyResolver _captureStrategyResolver;
  final CockpitRecordingStrategyResolver _recordingStrategyResolver;
  final TaskRunBundleWriter _writer;
  final CockpitReadTaskBundleSummaryService _readSummaryService;
  final Duration _environmentResolutionTimeout;
  final Duration _environmentResolutionRetryDelay;

  Future<CockpitRunRemoteControlScriptResult> run(
    CockpitRunRemoteControlScriptRequest request,
  ) async {
    final resolved = await _sessionReferenceResolver.resolve(
      baseUri: request.baseUri,
      sessionHandle: request.sessionHandle,
      sessionHandlePath: request.sessionHandlePath,
      androidDeviceId: request.portForwardingHandled
          ? null
          : request.androidDeviceId,
      iosDeviceId: request.portForwardingHandled ? null : request.iosDeviceId,
    );
    await _persistScriptIfRequested(
      path: request.persistScriptPath,
      script: request.script,
    );

    final client = CockpitRemoteSessionClient(baseUri: resolved.baseUri);
    final environment = await _resolveEnvironment(
      client: client,
      script: request.script,
      sessionHandle: resolved.sessionHandle,
    );
    final recordingAdapter = _resolvedRecordingAdapter(
      client: client,
      request: request,
      sessionHandle: resolved.sessionHandle,
    );
    final captureAdapter = _captureStrategyResolver.resolve(
      platform: request.script.platform,
      client: client,
      platformAppId:
          request.platformAppId ??
          resolved.sessionHandle?.effectivePlatformAppId,
      processId: request.processId ?? resolved.sessionHandle?.processId,
      sessionHandle: resolved.sessionHandle,
      androidDeviceId:
          request.androidDeviceId ??
          (resolved.sessionHandle?.platform == 'android'
              ? resolved.sessionHandle?.deviceId
              : null),
      iosDeviceId:
          request.iosDeviceId ??
          (resolved.sessionHandle?.platform == 'ios'
              ? resolved.sessionHandle?.deviceId
              : null),
    );
    final runner = CockpitControlRunner(
      automationAdapter: CockpitRemoteAutomationAdapter(client: client),
      captureAdapter: captureAdapter,
      recordingAdapter: recordingAdapter,
      sessionController: CockpitSessionController(
        sessionId: request.script.sessionId,
        taskId: request.script.taskId,
        platform: request.script.platform,
      ),
      failFast: request.script.failFast,
    );
    final runResult = await runner.run(
      environment: environment,
      commands: request.script.commands,
      workflowSteps: request.script.effectiveWorkflowSteps,
      recording: request.script.recording,
    );
    final bundleDir = await _writer.writeBundle(
      bundle: runResult.bundle,
      outputRoot: request.outputRoot,
      artifactPayloads: runResult.artifactPayloads,
      artifactSourcePaths: runResult.artifactSourcePaths,
    );
    final summary = await _readSummaryService.read(
      CockpitReadTaskBundleSummaryRequest(bundleDir: bundleDir.path),
    );

    return CockpitRunRemoteControlScriptResult(
      sessionHandle: resolved.sessionHandle,
      bundleDir: bundleDir,
      manifest: summary.manifest,
      handoff: summary.handoff,
      delivery: summary.delivery,
      artifactPaths: summary.artifactPaths,
    );
  }

  Future<CockpitEnvironment> _resolveEnvironment({
    required CockpitRemoteSessionClient client,
    required CockpitControlScript script,
    required CockpitRemoteSessionHandle? sessionHandle,
  }) async {
    final explicitEnvironment = script.environment;
    if (explicitEnvironment != null) {
      return explicitEnvironment;
    }

    final status = await _readStatusForEnvironment(
      client: client,
      sessionHandle: sessionHandle,
    );

    final resolvedEnvironment = status.environment;
    if (resolvedEnvironment != null) {
      return resolvedEnvironment;
    }

    throw CockpitApplicationServiceException(
      code: 'missingEnvironment',
      message:
          'Control script environment is required when remote session health does not expose environment.',
      details: <String, Object?>{
        'baseUrl': client.baseUri.toString(),
        'sessionHandle': sessionHandle?.toJson(),
        'sessionId': status.sessionId,
      },
    );
  }

  Future<CockpitRemoteSessionStatus> _readStatusForEnvironment({
    required CockpitRemoteSessionClient client,
    required CockpitRemoteSessionHandle? sessionHandle,
  }) async {
    final deadline = DateTime.now().toUtc().add(_environmentResolutionTimeout);
    var attempts = 0;
    Object? lastError;

    while (true) {
      attempts += 1;
      try {
        return await client.readStatus();
      } on Object catch (error) {
        if (!_isRemoteUnavailable(error)) {
          throw _environmentResolutionFailed(
            client: client,
            sessionHandle: sessionHandle,
            attempts: attempts,
            error: error,
          );
        }
        lastError = error;
      }

      final now = DateTime.now().toUtc();
      if (!now.isBefore(deadline)) {
        throw _environmentResolutionFailed(
          client: client,
          sessionHandle: sessionHandle,
          attempts: attempts,
          error: lastError,
        );
      }

      final remaining = deadline.difference(now);
      final delay = remaining < _environmentResolutionRetryDelay
          ? remaining
          : _environmentResolutionRetryDelay;
      if (delay > Duration.zero) {
        await Future<void>.delayed(delay);
      }
    }
  }

  CockpitApplicationServiceException _environmentResolutionFailed({
    required CockpitRemoteSessionClient client,
    required CockpitRemoteSessionHandle? sessionHandle,
    required int attempts,
    required Object error,
  }) {
    return CockpitApplicationServiceException(
      code: 'environmentResolutionFailed',
      message: 'Failed to resolve environment from remote session health.',
      details: <String, Object?>{
        'baseUrl': client.baseUri.toString(),
        'sessionHandle': sessionHandle?.toJson(),
        'attempts': attempts,
        'error': error.toString(),
      },
    );
  }

  bool _isRemoteUnavailable(Object error) =>
      error is CockpitApplicationServiceException &&
      error.code == 'remoteUnavailable';

  CockpitRecordingAdapter? _resolvedRecordingAdapter({
    required CockpitRemoteSessionClient client,
    required CockpitRunRemoteControlScriptRequest request,
    required CockpitRemoteSessionHandle? sessionHandle,
  }) {
    if (!request.script.requestsRecording) {
      return null;
    }

    return _ScriptRecordingAdapter(
      recordingStrategyResolver: _recordingStrategyResolver,
      platform: request.script.platform,
      client: client,
      sessionHandle: sessionHandle,
      androidDeviceId:
          request.androidDeviceId ??
          (sessionHandle?.platform == 'android'
              ? sessionHandle?.deviceId
              : null),
      iosDeviceId:
          request.iosDeviceId ??
          (sessionHandle?.platform == 'ios' ? sessionHandle?.deviceId : null),
      platformAppId:
          request.platformAppId ?? sessionHandle?.effectivePlatformAppId,
      processId: request.processId ?? sessionHandle?.processId,
    );
  }

  Future<void> _persistScriptIfRequested({
    required String? path,
    required CockpitControlScript script,
  }) async {
    if (path == null || path.isEmpty) {
      return;
    }

    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString(cockpitPrettyJsonText(script.toJson()));
  }
}

final class _ScriptRecordingAdapter implements CockpitRecordingAdapter {
  _ScriptRecordingAdapter({
    required CockpitRecordingStrategyResolver recordingStrategyResolver,
    required String platform,
    required CockpitRemoteSessionClient client,
    required CockpitRemoteSessionHandle? sessionHandle,
    required String? androidDeviceId,
    required String? iosDeviceId,
    required String? platformAppId,
    required int? processId,
  }) : _recordingStrategyResolver = recordingStrategyResolver,
       _platform = platform,
       _client = client,
       _sessionHandle = sessionHandle,
       _androidDeviceId = androidDeviceId,
       _iosDeviceId = iosDeviceId,
       _platformAppId = platformAppId,
       _processId = processId;

  final CockpitRecordingStrategyResolver _recordingStrategyResolver;
  final String _platform;
  final CockpitRemoteSessionClient _client;
  final CockpitRemoteSessionHandle? _sessionHandle;
  final String? _androidDeviceId;
  final String? _iosDeviceId;
  final String? _platformAppId;
  final int? _processId;
  CockpitRecordingAdapter? _activeAdapter;

  @override
  Future<CockpitRecordingSession> startRecording(
    CockpitRecordingRequest request,
  ) async {
    if (_activeAdapter != null) {
      throw StateError(
        'A script recording is already active; stop it before starting ${request.name}.',
      );
    }

    final resolution = _recordingStrategyResolver.resolveDetailed(
      platform: _platform,
      recording: request,
      client: _client,
      sessionHandle: _sessionHandle,
      androidDeviceId: _androidDeviceId,
      iosDeviceId: _iosDeviceId,
      platformAppId: _platformAppId,
      processId: _processId,
    );
    final adapter = resolution?.adapter;
    if (adapter == null) {
      throw CockpitApplicationServiceException(
        code: 'recordingStrategyUnavailable',
        message:
            resolution?.unsupportedReason ??
            'No recording strategy is available for $_platform.',
        details: <String, Object?>{
          'platform': _platform,
          'recording': request.toJson(),
        },
      );
    }

    final session = await adapter.startRecording(request);
    _activeAdapter = adapter;
    return session;
  }

  @override
  Future<CockpitRecordingResult> stopRecording() async {
    final adapter = _activeAdapter;
    if (adapter == null) {
      throw StateError('No active script recording is available to stop.');
    }

    try {
      return await adapter.stopRecording();
    } finally {
      _activeAdapter = null;
    }
  }
}

import 'dart:convert';
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
import 'cockpit_session_reference_resolver.dart';

final class CockpitRunRemoteControlScriptRequest {
  const CockpitRunRemoteControlScriptRequest({
    required this.script,
    required this.outputRoot,
    this.baseUri,
    this.sessionHandle,
    this.sessionHandlePath,
    this.androidDeviceId,
    this.iosDeviceId,
    this.persistScriptPath,
  });

  final CockpitControlScript script;
  final String outputRoot;
  final Uri? baseUri;
  final CockpitRemoteSessionHandle? sessionHandle;
  final String? sessionHandlePath;
  final String? androidDeviceId;
  final String? iosDeviceId;
  final String? persistScriptPath;
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
  })  : _sessionReferenceResolver =
            sessionReferenceResolver ?? CockpitSessionReferenceResolver(),
        _captureStrategyResolver = captureStrategyResolver,
        _recordingStrategyResolver = recordingStrategyResolver,
        _writer = writer;

  final CockpitSessionReferenceResolver _sessionReferenceResolver;
  final CockpitCaptureStrategyResolver _captureStrategyResolver;
  final CockpitRecordingStrategyResolver _recordingStrategyResolver;
  final TaskRunBundleWriter _writer;

  Future<CockpitRunRemoteControlScriptResult> run(
    CockpitRunRemoteControlScriptRequest request,
  ) async {
    final resolved = await _sessionReferenceResolver.resolve(
      baseUri: request.baseUri,
      sessionHandle: request.sessionHandle,
      sessionHandlePath: request.sessionHandlePath,
      androidDeviceId: request.androidDeviceId,
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
      sessionHandle: resolved.sessionHandle,
      androidDeviceId: request.androidDeviceId ??
          (resolved.sessionHandle?.platform == 'android'
              ? resolved.sessionHandle?.deviceId
              : null),
      iosDeviceId: request.iosDeviceId ??
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
      recording: request.script.recording,
    );
    final bundleDir = await _writer.writeBundle(
      bundle: runResult.bundle,
      outputRoot: request.outputRoot,
      artifactPayloads: runResult.artifactPayloads,
      artifactSourcePaths: runResult.artifactSourcePaths,
    );
    final artifactPaths = CockpitBundleArtifactPaths.fromDelivery(
      bundleDir: bundleDir.path,
      delivery: runResult.bundle.delivery,
    );

    return CockpitRunRemoteControlScriptResult(
      sessionHandle: resolved.sessionHandle,
      bundleDir: bundleDir,
      manifest: runResult.bundle.manifest,
      handoff: runResult.bundle.handoff,
      delivery: runResult.bundle.delivery,
      artifactPaths: artifactPaths,
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

    final CockpitRemoteSessionStatus status;
    try {
      status = await client.readStatus();
    } on Object catch (error) {
      throw CockpitApplicationServiceException(
        code: 'environmentResolutionFailed',
        message: 'Failed to resolve environment from remote session health.',
        details: <String, Object?>{
          'baseUrl': client.baseUri.toString(),
          'sessionHandle': sessionHandle?.toJson(),
          'error': error.toString(),
        },
      );
    }

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

  CockpitRecordingAdapter? _resolvedRecordingAdapter({
    required CockpitRemoteSessionClient client,
    required CockpitRunRemoteControlScriptRequest request,
    required CockpitRemoteSessionHandle? sessionHandle,
  }) {
    return _recordingStrategyResolver.resolve(
      platform: request.script.platform,
      recording: request.script.recording,
      client: client,
      sessionHandle: sessionHandle,
      androidDeviceId: request.androidDeviceId ??
          (sessionHandle?.platform == 'android'
              ? sessionHandle?.deviceId
              : null),
      iosDeviceId: request.iosDeviceId ??
          (sessionHandle?.platform == 'ios' ? sessionHandle?.deviceId : null),
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
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(script.toJson()),
    );
  }
}

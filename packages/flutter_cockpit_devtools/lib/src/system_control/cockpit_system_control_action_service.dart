import 'dart:io';

import 'package:flutter_cockpit/flutter_cockpit.dart';

import '../adapters/cockpit_capture_adapter.dart';
import '../adapters/cockpit_recording_adapter.dart';
import '../capture/cockpit_adb_capture_adapter.dart';
import '../capture/cockpit_linux_capture_adapter.dart';
import '../capture/cockpit_macos_capture_adapter.dart';
import '../capture/cockpit_simctl_capture_adapter.dart';
import '../capture/cockpit_windows_capture_adapter.dart';
import '../infrastructure/cockpit_process_manager.dart';
import '../recording/cockpit_adb_recording_adapter.dart';
import '../recording/cockpit_linux_recording_adapter.dart';
import '../recording/cockpit_macos_recording_adapter.dart';
import '../recording/cockpit_simctl_recording_adapter.dart';
import '../recording/cockpit_windows_recording_adapter.dart';
import 'cockpit_system_control_adapter.dart';
import 'cockpit_system_control_parameters.dart';
import 'cockpit_system_control_service.dart';

export 'cockpit_system_control_action.dart';
export 'cockpit_system_control_profile.dart';

typedef CockpitSystemControlRunActionFunction =
    Future<CockpitSystemControlActionResult> Function(
      CockpitSystemControlActionRequest request,
    );
typedef CockpitSystemControlCaptureAdapterFactory =
    CockpitCaptureAdapter? Function(CockpitSystemControlActionRequest request);
typedef CockpitSystemControlRecordingAdapterFactory =
    CockpitRecordingAdapter? Function(
      CockpitSystemControlActionRequest request,
    );

final class CockpitSystemControlActionService {
  CockpitSystemControlActionService({
    CockpitProcessManager? processManager,
    CockpitSystemControlRegistry registry =
        const CockpitSystemControlRegistry(),
    CockpitSystemControlService? systemControlService,
    CockpitSystemControlCaptureAdapterFactory? captureAdapterFactory,
    CockpitSystemControlRecordingAdapterFactory? recordingAdapterFactory,
  }) : _processManager = processManager ?? const LocalCockpitProcessManager(),
       _registry = registry,
       _systemControlService =
           systemControlService ??
           CockpitSystemControlService(registry: registry),
       _captureAdapterFactory =
           captureAdapterFactory ?? _defaultCaptureAdapterFor,
       _recordingAdapterFactory =
           recordingAdapterFactory ?? _defaultRecordingAdapterFor;

  final CockpitProcessManager _processManager;
  final CockpitSystemControlRegistry _registry;
  final CockpitSystemControlService _systemControlService;
  final CockpitSystemControlCaptureAdapterFactory _captureAdapterFactory;
  final CockpitSystemControlRecordingAdapterFactory _recordingAdapterFactory;

  Future<CockpitSystemControlActionResult> run(
    CockpitSystemControlActionRequest request,
  ) async {
    final describe = await _systemControlService.describe(
      CockpitSystemControlDescribeRequest(
        platform: request.platform,
        deviceId: request.deviceId,
        appId: request.appId,
        processId: request.processId,
      ),
    );
    final profile = describe.profile;
    final capability = profile.capabilityFor(request.action);
    if (capability == null) {
      return _notExecutable(
        request,
        availability: CockpitSystemControlAvailability.unsupported,
        recommendedNextStep: 'readSystemCapabilities',
        errorCode: 'unsupportedSystemAction',
        errorMessage:
            '${request.action.name} is not declared for ${profile.platform}.',
      );
    }
    if (capability.availability != CockpitSystemControlAvailability.available) {
      return _notExecutable(
        request,
        availability: capability.availability,
        recommendedNextStep: profile.recommendedNextStep,
        errorCode: 'systemActionNotAvailable',
        errorMessage:
            '${request.action.name} is ${capability.availability.name} on ${profile.platform}.',
        strategy: capability.strategy,
        requires: capability.requires,
        limitations: capability.limitations,
      );
    }
    final payloadError = _validateDeclaredPayload(request, capability);
    if (payloadError != null) {
      return payloadError;
    }

    if (request.action == CockpitSystemControlAction.captureScreenshot) {
      return _captureScreenshot(request, profile, capability);
    }
    if (request.action == CockpitSystemControlAction.startRecording) {
      return _startRecording(request, profile, capability);
    }
    if (request.action == CockpitSystemControlAction.stopRecording) {
      return _stopRecording(request, profile, capability);
    }

    final command = _registry.resolve(request.platform).resolveCommand(request);
    if (command.hasError) {
      return _notExecutable(
        request,
        availability: capability.availability,
        recommendedNextStep: _recommendedNextStepForCommandError(command),
        errorCode: command.errorCode,
        errorMessage: command.errorMessage,
        strategy: capability.strategy,
        requires: capability.requires,
        limitations: capability.limitations,
      );
    }

    final ProcessResult processResult;
    try {
      processResult = await cockpitRunManagedProcessWithTimeout(
        _processManager,
        command.executable!,
        command.arguments,
        timeout: request.timeout,
      );
    } on CockpitManagedProcessTimeoutException catch (error) {
      return CockpitSystemControlActionResult(
        platform: request.platform,
        deviceId: request.deviceId,
        appId: request.appId,
        processId: request.processId,
        action: request.action,
        availability: capability.availability,
        success: false,
        command: <String>[command.executable!, ...command.arguments],
        stdout: error.stdout.trimRight(),
        stderr: error.stderr.trimRight(),
        recommendedNextStep: 'inspectShellFailure',
        strategy: capability.strategy,
        requires: capability.requires,
        limitations: capability.limitations,
        errorCode: 'systemActionTimedOut',
        errorMessage:
            'System action command timed out after ${error.duration.inMilliseconds}ms.',
      );
    } on Object catch (error) {
      return CockpitSystemControlActionResult(
        platform: request.platform,
        deviceId: request.deviceId,
        appId: request.appId,
        processId: request.processId,
        action: request.action,
        availability: capability.availability,
        success: false,
        command: <String>[command.executable!, ...command.arguments],
        recommendedNextStep: 'inspectShellFailure',
        strategy: capability.strategy,
        requires: capability.requires,
        limitations: capability.limitations,
        errorCode: 'systemActionProcessFailed',
        errorMessage: _describeSystemControlError(error),
      );
    }
    final exitCode = processResult.exitCode;
    final success = exitCode == 0;
    return CockpitSystemControlActionResult(
      platform: request.platform,
      deviceId: request.deviceId,
      appId: request.appId,
      processId: request.processId,
      action: request.action,
      availability: capability.availability,
      success: success,
      command: <String>[command.executable!, ...command.arguments],
      exitCode: exitCode,
      stdout: '${processResult.stdout}'.trimRight(),
      stderr: '${processResult.stderr}'.trimRight(),
      recommendedNextStep: success
          ? 'readPostActionState'
          : 'inspectShellFailure',
      strategy: capability.strategy,
      requires: capability.requires,
      limitations: capability.limitations,
      errorCode: success ? null : 'systemActionFailed',
      errorMessage: success
          ? null
          : 'System action command exited with $exitCode.',
    );
  }

  CockpitSystemControlActionResult? _validateDeclaredPayload(
    CockpitSystemControlActionRequest request,
    CockpitSystemControlCapability capability,
  ) {
    final parametersByName = <String, CockpitSystemControlParameter>{
      for (final parameter in capability.parameters) parameter.name: parameter,
    };
    for (final entry in request.parameters.entries) {
      final parameter = parametersByName[entry.key];
      if (parameter == null) {
        return _notExecutable(
          request,
          availability: capability.availability,
          recommendedNextStep: 'fixActionPayload',
          errorCode: 'invalidSystemActionParameter',
          errorMessage:
              '${request.action.name} does not accept parameter ${entry.key}. Use read-system-capabilities parameters.',
          strategy: capability.strategy,
          requires: capability.requires,
          limitations: capability.limitations,
        );
      }
      final errorMessage = _validateSystemControlAllowedValue(
        request.action,
        parameter,
        entry.value,
      );
      if (errorMessage != null) {
        return _notExecutable(
          request,
          availability: capability.availability,
          recommendedNextStep: 'fixActionPayload',
          errorCode: 'invalidSystemActionParameter',
          errorMessage: errorMessage,
          strategy: capability.strategy,
          requires: capability.requires,
          limitations: capability.limitations,
        );
      }
    }
    return null;
  }

  Future<CockpitSystemControlActionResult> _captureScreenshot(
    CockpitSystemControlActionRequest request,
    CockpitSystemControlProfile profile,
    CockpitSystemControlCapability capability,
  ) async {
    final name = cockpitReadSystemControlStringParameter(
      request.parameters,
      'name',
    );
    final outputPath = cockpitReadSystemControlStringParameter(
      request.parameters,
      'outputPath',
    );
    if (name.isInvalid || outputPath.isInvalid) {
      return _invalidEvidencePayload(
        request,
        capability,
        'captureScreenshot accepts string name and outputPath parameters.',
      );
    }
    final adapter = _captureAdapterFactory(request);
    if (adapter == null) {
      return _notExecutable(
        request,
        availability: CockpitSystemControlAvailability.blocked,
        recommendedNextStep: profile.recommendedNextStep,
        errorCode: 'systemCaptureUnavailable',
        errorMessage:
            'No capture adapter is available for ${request.platform}.',
        strategy: capability.strategy,
        requires: capability.requires,
        limitations: capability.limitations,
      );
    }

    try {
      final execution = await adapter.capture(
        CockpitCommand(
          commandId: 'system-capture-screenshot',
          commandType: CockpitCommandType.captureScreenshot,
          screenshotRequest: CockpitScreenshotRequest(
            reason: CockpitScreenshotReason.acceptance,
            name: name.value ?? 'system-screenshot',
          ),
        ),
      );
      final result = execution.result;
      final artifact = result.artifacts.isEmpty ? null : result.artifacts.first;
      final sourcePath = artifact == null
          ? null
          : execution.artifactSourcePaths[artifact.relativePath];
      if (result.success && (sourcePath == null || sourcePath.isEmpty)) {
        return CockpitSystemControlActionResult(
          platform: request.platform,
          deviceId: request.deviceId,
          appId: request.appId,
          processId: request.processId,
          action: request.action,
          availability: capability.availability,
          success: false,
          recommendedNextStep: 'inspectCaptureFailure',
          errorCode: 'systemCaptureMissingArtifact',
          errorMessage:
              'Capture adapter reported success without a source artifact path.',
          strategy: capability.strategy,
          requires: capability.requires,
          limitations: capability.limitations,
          artifact: artifact?.toJson(),
        );
      }
      String? finalSourcePath = sourcePath;
      if (result.success && sourcePath != null && outputPath.value != null) {
        finalSourcePath = await _copyArtifactToOutputPath(
          sourcePath: sourcePath,
          outputPath: outputPath.value!,
        );
      }

      return CockpitSystemControlActionResult(
        platform: request.platform,
        deviceId: request.deviceId,
        appId: request.appId,
        processId: request.processId,
        action: request.action,
        availability: capability.availability,
        success: result.success,
        recommendedNextStep: result.success
            ? 'readPostActionState'
            : 'inspectCaptureFailure',
        errorCode: result.success ? null : 'systemCaptureFailed',
        errorMessage: result.error?.message,
        strategy: capability.strategy,
        requires: capability.requires,
        limitations: capability.limitations,
        artifact: artifact?.toJson(),
        sourceFilePath: finalSourcePath,
      );
    } on Object catch (error) {
      return CockpitSystemControlActionResult(
        platform: request.platform,
        deviceId: request.deviceId,
        appId: request.appId,
        processId: request.processId,
        action: request.action,
        availability: capability.availability,
        success: false,
        recommendedNextStep: 'inspectCaptureFailure',
        errorCode: 'systemCaptureFailed',
        errorMessage: _describeSystemControlError(error),
        strategy: capability.strategy,
        requires: capability.requires,
        limitations: capability.limitations,
      );
    }
  }

  Future<CockpitSystemControlActionResult> _startRecording(
    CockpitSystemControlActionRequest request,
    CockpitSystemControlProfile profile,
    CockpitSystemControlCapability capability,
  ) async {
    final recordingRequest = _recordingRequestFromParameters(
      request.parameters,
    );
    if (recordingRequest == null) {
      return _invalidEvidencePayload(
        request,
        capability,
        'startRecording accepts string name, purpose, mode, and layer parameters declared by system capabilities.',
      );
    }
    final adapter = _recordingAdapterFactory(request);
    if (adapter == null) {
      return _notExecutable(
        request,
        availability: CockpitSystemControlAvailability.blocked,
        recommendedNextStep: profile.recommendedNextStep,
        errorCode: 'systemRecordingUnavailable',
        errorMessage:
            'No recording adapter is available for ${request.platform}.',
        strategy: capability.strategy,
        requires: capability.requires,
        limitations: capability.limitations,
      );
    }

    try {
      final recordingSession = await adapter.startRecording(recordingRequest);
      return CockpitSystemControlActionResult(
        platform: request.platform,
        deviceId: request.deviceId,
        appId: request.appId,
        processId: request.processId,
        action: request.action,
        availability: capability.availability,
        success: true,
        recommendedNextStep: 'runFlowThenStopRecording',
        strategy: capability.strategy,
        requires: capability.requires,
        limitations: capability.limitations,
        recordingSession: recordingSession.toJson(),
      );
    } on Object catch (error) {
      return CockpitSystemControlActionResult(
        platform: request.platform,
        deviceId: request.deviceId,
        appId: request.appId,
        processId: request.processId,
        action: request.action,
        availability: capability.availability,
        success: false,
        recommendedNextStep: 'inspectRecordingFailure',
        errorCode: 'systemRecordingFailed',
        errorMessage: _describeSystemControlError(error),
        strategy: capability.strategy,
        requires: capability.requires,
        limitations: capability.limitations,
      );
    }
  }

  Future<CockpitSystemControlActionResult> _stopRecording(
    CockpitSystemControlActionRequest request,
    CockpitSystemControlProfile profile,
    CockpitSystemControlCapability capability,
  ) async {
    final outputPath = cockpitReadSystemControlStringParameter(
      request.parameters,
      'outputPath',
    );
    if (outputPath.isInvalid) {
      return _invalidEvidencePayload(
        request,
        capability,
        'stopRecording accepts a string outputPath parameter.',
      );
    }
    final adapter = _recordingAdapterFactory(request);
    if (adapter == null) {
      return _notExecutable(
        request,
        availability: CockpitSystemControlAvailability.blocked,
        recommendedNextStep: profile.recommendedNextStep,
        errorCode: 'systemRecordingUnavailable',
        errorMessage:
            'No recording adapter is available for ${request.platform}.',
        strategy: capability.strategy,
        requires: capability.requires,
        limitations: capability.limitations,
      );
    }

    try {
      final recordingResult = await adapter.stopRecording();
      final success = recordingResult.state == CockpitRecordingState.completed;
      var finalSourcePath = recordingResult.sourceFilePath;
      if (success && (finalSourcePath == null || finalSourcePath.isEmpty)) {
        return CockpitSystemControlActionResult(
          platform: request.platform,
          deviceId: request.deviceId,
          appId: request.appId,
          processId: request.processId,
          action: request.action,
          availability: capability.availability,
          success: false,
          recommendedNextStep: 'inspectRecordingFailure',
          errorCode: 'systemRecordingMissingArtifact',
          errorMessage:
              'Recording adapter reported completion without a source file path.',
          strategy: capability.strategy,
          requires: capability.requires,
          limitations: capability.limitations,
          artifact: recordingResult.artifact?.toJson(),
          recordingResult: recordingResult.toJson(),
        );
      }
      if (success && finalSourcePath != null && outputPath.value != null) {
        finalSourcePath = await _copyArtifactToOutputPath(
          sourcePath: finalSourcePath,
          outputPath: outputPath.value!,
        );
      }
      return CockpitSystemControlActionResult(
        platform: request.platform,
        deviceId: request.deviceId,
        appId: request.appId,
        processId: request.processId,
        action: request.action,
        availability: capability.availability,
        success: success,
        recommendedNextStep: success
            ? 'readPostActionState'
            : 'inspectRecordingFailure',
        errorCode: success ? null : 'systemRecordingFailed',
        errorMessage: recordingResult.failureReason,
        strategy: capability.strategy,
        requires: capability.requires,
        limitations: capability.limitations,
        artifact: recordingResult.artifact?.toJson(),
        sourceFilePath: finalSourcePath,
        recordingResult: finalSourcePath == recordingResult.sourceFilePath
            ? recordingResult.toJson()
            : recordingResult
                  .copyWith(sourceFilePath: finalSourcePath)
                  .toJson(),
      );
    } on Object catch (error) {
      return CockpitSystemControlActionResult(
        platform: request.platform,
        deviceId: request.deviceId,
        appId: request.appId,
        processId: request.processId,
        action: request.action,
        availability: capability.availability,
        success: false,
        recommendedNextStep: 'inspectRecordingFailure',
        errorCode: 'systemRecordingFailed',
        errorMessage: _describeSystemControlError(error),
        strategy: capability.strategy,
        requires: capability.requires,
        limitations: capability.limitations,
      );
    }
  }

  CockpitSystemControlActionResult _notExecutable(
    CockpitSystemControlActionRequest request, {
    required CockpitSystemControlAvailability availability,
    required String recommendedNextStep,
    required String? errorCode,
    required String? errorMessage,
    String? strategy,
    List<String> requires = const <String>[],
    List<String> limitations = const <String>[],
  }) {
    return CockpitSystemControlActionResult(
      platform: request.platform,
      deviceId: request.deviceId,
      appId: request.appId,
      processId: request.processId,
      action: request.action,
      availability: availability,
      success: false,
      recommendedNextStep: recommendedNextStep,
      errorCode: errorCode,
      errorMessage: errorMessage,
      strategy: strategy,
      requires: requires,
      limitations: limitations,
    );
  }
}

CockpitSystemControlActionResult _invalidEvidencePayload(
  CockpitSystemControlActionRequest request,
  CockpitSystemControlCapability capability,
  String message,
) {
  return CockpitSystemControlActionResult(
    platform: request.platform,
    deviceId: request.deviceId,
    appId: request.appId,
    processId: request.processId,
    action: request.action,
    availability: capability.availability,
    success: false,
    recommendedNextStep: 'fixActionPayload',
    errorCode: 'invalidSystemActionParameter',
    errorMessage: message,
    strategy: capability.strategy,
    requires: capability.requires,
    limitations: capability.limitations,
  );
}

String? _validateSystemControlAllowedValue(
  CockpitSystemControlAction action,
  CockpitSystemControlParameter parameter,
  Object? value,
) {
  if (parameter.allowedValues.isEmpty) {
    return null;
  }
  if (value is! String) {
    return '${action.name} requires ${parameter.name} to be one of ${parameter.allowedValues.join(", ")}.';
  }
  final normalized = value.trim();
  if (normalized.isEmpty) {
    return null;
  }
  if (!parameter.allowedValues.contains(normalized)) {
    return '${action.name} requires ${parameter.name} to be one of ${parameter.allowedValues.join(", ")}.';
  }
  return null;
}

String _recommendedNextStepForCommandError(
  CockpitResolvedSystemControlCommand command,
) {
  return switch (command.errorCode) {
    'missingSystemActionParameter' ||
    'invalidSystemActionParameter' ||
    'missingSystemActionTarget' => 'fixActionPayload',
    _ => 'unsupportedSystemAction',
  };
}

CockpitCaptureAdapter? _defaultCaptureAdapterFor(
  CockpitSystemControlActionRequest request,
) {
  final deviceId = request.deviceId;
  final appId = request.appId;
  final windowAppId = _windowAppIdFor(request);
  return switch (request.platform.trim().toLowerCase()) {
    'android' when deviceId != null && deviceId.isNotEmpty =>
      CockpitAdbCaptureAdapter(deviceId: deviceId),
    'ios' when deviceId != null && deviceId.isNotEmpty =>
      CockpitSimctlCaptureAdapter(deviceId: deviceId),
    'macos' when appId != null && appId.isNotEmpty =>
      CockpitMacosCaptureAdapter(appId: appId),
    'windows' when windowAppId != null => CockpitWindowsCaptureAdapter(
      appId: windowAppId,
      processId: request.processId,
    ),
    'linux' when windowAppId != null => CockpitLinuxCaptureAdapter(
      appId: windowAppId,
      processId: request.processId,
    ),
    _ => null,
  };
}

CockpitRecordingAdapter? _defaultRecordingAdapterFor(
  CockpitSystemControlActionRequest request,
) {
  final deviceId = request.deviceId;
  final appId = request.appId;
  final windowAppId = _windowAppIdFor(request);
  return switch (request.platform.trim().toLowerCase()) {
    'android' when deviceId != null && deviceId.isNotEmpty =>
      CockpitAdbRecordingAdapter(deviceId: deviceId),
    'ios' when deviceId != null && deviceId.isNotEmpty =>
      CockpitSimctlRecordingAdapter(deviceId: deviceId),
    'macos' when appId != null && appId.isNotEmpty =>
      CockpitMacosRecordingAdapter(appId: appId),
    'windows' when windowAppId != null => CockpitWindowsRecordingAdapter(
      appId: windowAppId,
      processId: request.processId,
    ),
    'linux' when windowAppId != null => CockpitLinuxRecordingAdapter(
      appId: windowAppId,
      processId: request.processId,
    ),
    _ => null,
  };
}

String? _windowAppIdFor(CockpitSystemControlActionRequest request) {
  final appId = request.appId;
  if (appId != null && appId.trim().isNotEmpty) {
    return appId;
  }
  final processId = request.processId;
  return processId == null ? null : 'pid-$processId';
}

CockpitRecordingRequest? _recordingRequestFromParameters(
  Map<String, Object?> parameters,
) {
  final purpose = cockpitReadSystemControlStringParameter(
    parameters,
    'purpose',
    allowedValues: _allowedRecordingValues('purpose'),
  );
  final name = cockpitReadSystemControlStringParameter(parameters, 'name');
  final mode = cockpitReadSystemControlStringParameter(
    parameters,
    'mode',
    allowedValues: _allowedRecordingValues('mode'),
  );
  final layer = cockpitReadSystemControlStringParameter(
    parameters,
    'layer',
    allowedValues: _allowedRecordingValues('layer'),
  );
  if (purpose.isInvalid ||
      name.isInvalid ||
      mode.isInvalid ||
      layer.isInvalid) {
    return null;
  }
  return CockpitRecordingRequest(
    purpose: CockpitRecordingPurpose.fromJson(purpose.value ?? 'acceptance'),
    name: name.value ?? 'system-recording',
    mode: CockpitRecordingMode.fromJson(mode.value ?? 'native'),
    layer: CockpitRecordingLayer.fromJson(layer.value ?? 'system'),
    allowFallback: false,
  );
}

List<String> _allowedRecordingValues(String name) {
  for (final parameter in CockpitSystemControlParameterSets.startRecording) {
    if (parameter.name == name) {
      return parameter.allowedValues;
    }
  }
  return const <String>[];
}

Future<String> _copyArtifactToOutputPath({
  required String sourcePath,
  required String outputPath,
}) async {
  final outputFile = File(outputPath);
  await outputFile.parent.create(recursive: true);
  final sourceFile = File(sourcePath);
  if (sourceFile.absolute.path == outputFile.absolute.path) {
    return outputFile.path;
  }
  await sourceFile.copy(outputFile.path);
  return outputFile.path;
}

String _describeSystemControlError(Object error) {
  if (error is StateError) {
    return error.message;
  }
  if (error is FileSystemException) {
    return <String>[
      error.message,
      if (error.path != null && error.path!.isNotEmpty) error.path!,
      if (error.osError != null) '${error.osError}',
    ].join(' ');
  }
  return '$error';
}

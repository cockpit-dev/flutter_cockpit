import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_cockpit_devtools/flutter_cockpit_devtools.dart';
import 'package:path/path.dart' as p;

typedef CockpitDemoPlatformDeviceProbe = Future<List<CockpitDemoHostDevice>>
    Function();
typedef CockpitDemoIosSimulatorProbe = Future<List<CockpitDemoIosSimulator>>
    Function();
typedef CockpitDemoProcessRunner = Future<ProcessResult> Function(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
});
typedef CockpitDemoWait = Future<void> Function(Duration duration);
typedef CockpitDemoClock = DateTime Function();
typedef CockpitDemoLaunchAppFunction = Future<CockpitLaunchAppResult> Function(
  CockpitLaunchAppRequest request,
);
typedef CockpitDemoReadAppFunction = Future<CockpitReadAppResult> Function(
  CockpitReadAppRequest request,
);
typedef CockpitDemoRunCommandFunction
    = Future<CockpitExecuteRemoteCommandResult> Function(
  CockpitRunCommandRequest request,
);
typedef CockpitDemoRunBatchFunction = Future<CockpitRunBatchResult> Function(
  CockpitRunBatchRequest request,
);
typedef CockpitDemoInspectUiFunction = Future<CockpitInspectUiResult> Function(
  CockpitInspectUiRequest request,
);
typedef CockpitDemoInspectSurfaceFunction = Future<CockpitInspectSurfaceResult>
    Function(
  CockpitInspectSurfaceRequest request,
);
typedef CockpitDemoWaitIdleFunction = Future<CockpitWaitIdleResult> Function(
  CockpitWaitIdleRequest request,
);
typedef CockpitDemoReadNetworkFunction = Future<CockpitReadNetworkResult>
    Function(
  CockpitReadNetworkRequest request,
);
typedef CockpitDemoReadErrorsFunction = Future<CockpitReadErrorsResult>
    Function(
  CockpitReadErrorsRequest request,
);
typedef CockpitDemoReadLogsFunction = Future<CockpitReadLogsResult> Function(
  CockpitReadLogsRequest request,
);
typedef CockpitDemoRecordingAdapterResolver = CockpitRecordingAdapter?
    Function({
  required String platform,
  required String deviceId,
  required CockpitRemoteSessionClient client,
  required CockpitRecordingRequest recording,
});
typedef CockpitDemoHotReloadFunction = Future<CockpitHotReloadResult> Function(
  CockpitHotReloadRequest request,
);
typedef CockpitDemoHotRestartFunction = Future<CockpitHotRestartResult>
    Function(
  CockpitHotRestartRequest request,
);
typedef CockpitDemoStopAppFunction = Future<CockpitStopAppResult> Function(
  CockpitStopAppRequest request,
);

const List<String> cockpitDemoDefaultVerificationPlatforms = <String>[
  'macos',
  'ios',
  'android',
];

const List<String> cockpitDemoSupportedVerificationPlatforms = <String>[
  'android',
  'ios',
  'linux',
  'macos',
  'web',
  'windows',
];

final class CockpitDemoHostDevice {
  const CockpitDemoHostDevice({
    required this.name,
    required this.deviceId,
    required this.platform,
    required this.emulator,
    required this.supported,
  });

  final String name;
  final String deviceId;
  final String platform;
  final bool emulator;
  final bool supported;

  Map<String, Object?> toJson() => <String, Object?>{
        'name': name,
        'deviceId': deviceId,
        'platform': platform,
        'emulator': emulator,
        'supported': supported,
      };

  factory CockpitDemoHostDevice.fromJson(Map<String, Object?> json) {
    final rawPlatform = '${json['targetPlatform'] ?? ''}';
    return CockpitDemoHostDevice(
      name: '${json['name'] ?? ''}',
      deviceId: '${json['id'] ?? ''}',
      platform: switch (rawPlatform) {
        final value when value.startsWith('android') => 'android',
        final value when value.startsWith('ios') => 'ios',
        final value when value.startsWith('linux') => 'linux',
        final value when value.startsWith('web') => 'web',
        final value when value.startsWith('windows') => 'windows',
        'darwin' => 'macos',
        _ => rawPlatform,
      },
      emulator: json['emulator'] as bool? ?? false,
      supported: json['isSupported'] as bool? ?? false,
    );
  }
}

final class CockpitDemoIosSimulator {
  const CockpitDemoIosSimulator({
    required this.name,
    required this.udid,
    required this.state,
    required this.available,
  });

  final String name;
  final String udid;
  final String state;
  final bool available;

  bool get booted => state == 'Booted';
  bool get isPhone => name.startsWith('iPhone');
}

final class CockpitDemoPlatformVerificationRequest {
  const CockpitDemoPlatformVerificationRequest({
    required this.projectDir,
    this.platforms = cockpitDemoDefaultVerificationPlatforms,
    this.target,
    this.outputRoot = '.dart_tool/cockpit_platforms',
    this.sessionPortBase = 58331,
    this.launchTimeout = const Duration(seconds: 180),
    this.deviceTimeout = const Duration(seconds: 420),
    this.androidEmulatorId = 'Pixel_9_Pro',
    this.allowWebHostRecordingPrerequisiteFailure = false,
    this.failFast = false,
  });

  final String projectDir;
  final List<String> platforms;
  final String? target;
  final String outputRoot;
  final int sessionPortBase;
  final Duration launchTimeout;
  final Duration deviceTimeout;
  final String androidEmulatorId;
  final bool allowWebHostRecordingPrerequisiteFailure;
  final bool failFast;
}

final class CockpitDemoPlatformVerification {
  const CockpitDemoPlatformVerification({
    required this.platform,
    required this.status,
    required this.deviceId,
    required this.bootstrappedDevice,
    required this.outputDir,
    this.appJsonPath,
    this.initialRouteName,
    this.inspectUiRouteName,
    this.postSaveRouteName,
    this.postReloadRouteName,
    this.postRestartRouteName,
    this.inspectRouteName,
    this.inspectPlane,
    this.surfaceKind,
    this.createdTaskTitle,
    this.hotReloadSucceeded = false,
    this.hotRestartSucceeded = false,
    this.reloadGeneration = 0,
    this.waitIdleSucceeded = false,
    this.waitIdleDurationMs = 0,
    this.batchCommandCount = 0,
    this.networkFailureCount = 0,
    this.runtimeErrorCount = 0,
    this.logLineCount = 0,
    this.recordingArtifactRef,
    this.recordingOutputPath,
    this.recordingDurationMs,
    this.recordingKind,
    this.recordingDriver,
    this.screenshotArtifactRef,
    this.screenshotByteLength,
    this.verifiedCommands = const <String>[],
    this.warnings = const <String>[],
    this.baseUrl,
    this.failureCode,
    this.failureMessage,
  });

  final String platform;
  final String status;
  final String deviceId;
  final bool bootstrappedDevice;
  final String outputDir;
  final String? appJsonPath;
  final String? initialRouteName;
  final String? inspectUiRouteName;
  final String? postSaveRouteName;
  final String? postReloadRouteName;
  final String? postRestartRouteName;
  final String? inspectRouteName;
  final String? inspectPlane;
  final String? surfaceKind;
  final String? createdTaskTitle;
  final bool hotReloadSucceeded;
  final bool hotRestartSucceeded;
  final int reloadGeneration;
  final bool waitIdleSucceeded;
  final int waitIdleDurationMs;
  final int batchCommandCount;
  final int networkFailureCount;
  final int runtimeErrorCount;
  final int logLineCount;
  final String? recordingArtifactRef;
  final String? recordingOutputPath;
  final int? recordingDurationMs;
  final String? recordingKind;
  final String? recordingDriver;
  final String? screenshotArtifactRef;
  final int? screenshotByteLength;
  final List<String> verifiedCommands;
  final List<String> warnings;
  final String? baseUrl;
  final String? failureCode;
  final String? failureMessage;

  bool get success => status == 'passed';

  Map<String, Object?> toJson() => <String, Object?>{
        'platform': platform,
        'status': status,
        'deviceId': deviceId,
        'bootstrappedDevice': bootstrappedDevice,
        'outputDir': outputDir,
        if (appJsonPath != null) 'appJsonPath': appJsonPath,
        if (baseUrl != null) 'baseUrl': baseUrl,
        if (initialRouteName != null) 'initialRouteName': initialRouteName,
        if (inspectUiRouteName != null)
          'inspectUiRouteName': inspectUiRouteName,
        if (postSaveRouteName != null) 'postSaveRouteName': postSaveRouteName,
        if (postReloadRouteName != null)
          'postReloadRouteName': postReloadRouteName,
        if (postRestartRouteName != null)
          'postRestartRouteName': postRestartRouteName,
        if (inspectRouteName != null) 'inspectRouteName': inspectRouteName,
        if (inspectPlane != null) 'inspectPlane': inspectPlane,
        if (surfaceKind != null) 'surfaceKind': surfaceKind,
        if (createdTaskTitle != null) 'createdTaskTitle': createdTaskTitle,
        'hotReloadSucceeded': hotReloadSucceeded,
        'hotRestartSucceeded': hotRestartSucceeded,
        'reloadGeneration': reloadGeneration,
        'waitIdleSucceeded': waitIdleSucceeded,
        'waitIdleDurationMs': waitIdleDurationMs,
        'batchCommandCount': batchCommandCount,
        'networkFailureCount': networkFailureCount,
        'runtimeErrorCount': runtimeErrorCount,
        'logLineCount': logLineCount,
        if (recordingArtifactRef != null)
          'recordingArtifactRef': recordingArtifactRef,
        if (recordingOutputPath != null)
          'recordingOutputPath': recordingOutputPath,
        if (recordingDurationMs != null)
          'recordingDurationMs': recordingDurationMs,
        if (recordingKind != null) 'recordingKind': recordingKind,
        if (recordingDriver != null) 'recordingDriver': recordingDriver,
        if (screenshotArtifactRef != null)
          'screenshotArtifactRef': screenshotArtifactRef,
        if (screenshotByteLength != null)
          'screenshotByteLength': screenshotByteLength,
        'verifiedCommands': verifiedCommands,
        if (warnings.isNotEmpty) 'warnings': warnings,
        if (failureCode != null) 'failureCode': failureCode,
        if (failureMessage != null) 'failureMessage': failureMessage,
      };
}

final class CockpitDemoPlatformVerificationResult {
  const CockpitDemoPlatformVerificationResult({
    required this.platforms,
    required this.success,
    required this.recommendedNextStep,
  });

  final List<CockpitDemoPlatformVerification> platforms;
  final bool success;
  final String recommendedNextStep;

  Map<String, Object?> toJson() => <String, Object?>{
        'success': success,
        'recommendedNextStep': recommendedNextStep,
        'platforms': platforms
            .map((platform) => platform.toJson())
            .toList(growable: false),
      };
}

final class CockpitDemoPlatformVerifier {
  CockpitDemoPlatformVerifier({
    CockpitDemoPlatformDeviceProbe? probeDevices,
    CockpitDemoIosSimulatorProbe? listIosSimulators,
    CockpitDemoProcessRunner runProcess = Process.run,
    CockpitDemoWait? wait,
    CockpitDemoClock? clock,
    CockpitDemoLaunchAppFunction? launchApp,
    CockpitDemoReadAppFunction? readApp,
    CockpitDemoRunCommandFunction? runCommand,
    CockpitDemoRunBatchFunction? runBatch,
    CockpitDemoInspectUiFunction? inspectUi,
    CockpitDemoInspectSurfaceFunction? inspectSurface,
    CockpitDemoWaitIdleFunction? waitIdle,
    CockpitDemoReadNetworkFunction? readNetwork,
    CockpitDemoReadErrorsFunction? readErrors,
    CockpitDemoReadLogsFunction? readLogs,
    CockpitDemoRecordingAdapterResolver? recordingAdapterResolver,
    CockpitDemoHotReloadFunction? hotReload,
    CockpitDemoHotRestartFunction? hotRestart,
    CockpitDemoStopAppFunction? stopApp,
  })  : _probeDevices = probeDevices ??
            (() => cockpitDemoProbeHostDevices(
                  processRunner: runProcess,
                )),
        _listIosSimulators = listIosSimulators ??
            (() => cockpitDemoListIosSimulators(
                  processRunner: runProcess,
                )),
        _processRunner = runProcess,
        _wait = wait ?? _defaultWait,
        _clock = clock ?? DateTime.now,
        _launchApp = launchApp ?? CockpitLaunchAppService().launch,
        _readApp = readApp ?? CockpitReadAppService().read,
        _runCommand = runCommand ?? CockpitRunCommandService().run,
        _runBatch = runBatch ?? CockpitRunBatchService().run,
        _inspectUi = inspectUi ?? CockpitInspectUiService().inspect,
        _inspectSurface =
            inspectSurface ?? CockpitInspectSurfaceService().inspect,
        _waitIdle = waitIdle ?? CockpitWaitIdleService().wait,
        _readNetwork = readNetwork ?? cockpitDemoReadNetwork,
        _readErrors = readErrors ?? cockpitDemoReadErrors,
        _readLogs = readLogs ?? cockpitDemoReadLogs,
        _recordingAdapterResolver =
            recordingAdapterResolver ?? cockpitDemoResolveRecordingAdapter,
        _hotReload = hotReload ?? CockpitHotReloadService().reload,
        _hotRestart = hotRestart ?? CockpitHotRestartService().restart,
        _stopApp = stopApp ?? CockpitStopAppService().stop;

  final CockpitDemoPlatformDeviceProbe _probeDevices;
  final CockpitDemoIosSimulatorProbe _listIosSimulators;
  final CockpitDemoProcessRunner _processRunner;
  final CockpitDemoWait _wait;
  final CockpitDemoClock _clock;
  final CockpitDemoLaunchAppFunction _launchApp;
  final CockpitDemoReadAppFunction _readApp;
  final CockpitDemoRunCommandFunction _runCommand;
  final CockpitDemoRunBatchFunction _runBatch;
  final CockpitDemoInspectUiFunction _inspectUi;
  final CockpitDemoInspectSurfaceFunction _inspectSurface;
  final CockpitDemoWaitIdleFunction _waitIdle;
  final CockpitDemoReadNetworkFunction _readNetwork;
  final CockpitDemoReadErrorsFunction _readErrors;
  final CockpitDemoReadLogsFunction _readLogs;
  final CockpitDemoRecordingAdapterResolver _recordingAdapterResolver;
  final CockpitDemoHotReloadFunction _hotReload;
  final CockpitDemoHotRestartFunction _hotRestart;
  final CockpitDemoStopAppFunction _stopApp;

  Future<CockpitDemoPlatformVerificationResult> verify(
    CockpitDemoPlatformVerificationRequest request,
  ) async {
    final results = <CockpitDemoPlatformVerification>[];
    final normalizedPlatforms =
        request.platforms.map(_normalizePlatform).toList(growable: false);

    for (var index = 0; index < normalizedPlatforms.length; index += 1) {
      final platform = normalizedPlatforms[index];
      final sessionPort = await cockpitDemoAllocateSessionPort(
        preferredPort: request.sessionPortBase + index,
      );
      final result = await _verifyPlatform(
        platform: platform,
        request: request,
        sessionPort: sessionPort,
      );
      results.add(result);
      if (request.failFast && !result.success) {
        break;
      }
    }

    final success =
        results.isNotEmpty && results.every((result) => result.success);
    return CockpitDemoPlatformVerificationResult(
      platforms: results,
      success: success,
      recommendedNextStep: success ? 'continue' : 'inspectPlatformFailures',
    );
  }

  Future<CockpitDemoPlatformVerification> _verifyPlatform({
    required String platform,
    required CockpitDemoPlatformVerificationRequest request,
    required int sessionPort,
  }) async {
    final outputDir = p.normalize(p.join(request.outputRoot, platform));
    final appJsonPath = p.join(outputDir, 'app.json');
    CockpitAppHandle? app;
    String? deviceId;
    var bootstrappedDevice = false;

    try {
      await Directory(outputDir).create(recursive: true);
      final resolvedDevice = await _ensureDeviceForPlatform(
        platform: platform,
        request: request,
      );
      deviceId = resolvedDevice.deviceId;
      bootstrappedDevice = resolvedDevice.bootstrapped;

      final launchResult = await _launchApp(
        CockpitLaunchAppRequest(
          projectDir: request.projectDir,
          target: request.target,
          platform: platform,
          deviceId: deviceId,
          sessionPort: sessionPort,
          launchTimeout: request.launchTimeout,
          appHandlePath: appJsonPath,
        ),
      );
      final launchedApp = launchResult.app;
      app = launchedApp;
      final resolvedAppJsonPath = launchResult.appJsonPath ?? appJsonPath;
      final appBaseUri = Uri.parse(launchedApp.baseUrl);
      final verifiedCommands = <String>[
        'launch-app',
      ];
      final warnings = <String>[];

      final initialRead = await _readApp(
        CockpitReadAppRequest(
          app: launchedApp,
          resultProfile: const CockpitInteractiveResultProfile.minimal(),
        ),
      );
      _requireRoute(
        routeName: initialRead.currentRouteName,
        expectedRoute: '/inbox',
        label: 'initial route',
        platform: platform,
      );
      verifiedCommands.add('read-app');
      final inspectUiResult = await _inspectUi(
        CockpitInspectUiRequest(
          app: launchedApp,
          resultProfile: const CockpitInteractiveResultProfile.inspect(),
        ),
      );
      _requireRoute(
        routeName: inspectUiResult.routeName,
        expectedRoute: '/inbox',
        label: 'inspect-ui route',
        platform: platform,
      );
      verifiedCommands.add('inspect-ui');

      final taskTitle =
          'Platform smoke ${platform}_${_clock().toUtc().microsecondsSinceEpoch}';
      final taskNotes =
          'Cross-platform verification for $platform with screenshot and recording coverage.';
      final recordingRequest = CockpitRecordingRequest(
        purpose: CockpitRecordingPurpose.acceptance,
        name: 'verify_${platform}_loop',
      );

      await _runRequiredCommand(
        app: launchedApp,
        command: CockpitCommand(
          commandId: 'verify-$platform-assert-new-task',
          commandType: CockpitCommandType.assertText,
          parameters: const <String, Object?>{'text': 'New task'},
        ),
      );
      final recordingAdapter = _recordingAdapterResolver(
        platform: platform,
        deviceId: deviceId,
        client: CockpitRemoteSessionClient(baseUri: appBaseUri),
        recording: recordingRequest,
      );
      if (recordingAdapter == null) {
        throw CockpitApplicationServiceException(
          code: 'recordingUnsupported',
          message: 'No recording adapter was available for this platform.',
          details: <String, Object?>{'platform': platform},
        );
      }
      var recordingStarted = false;
      String? recordingArtifactRef;
      String? recordingOutputPath;
      int? recordingDurationMs;
      String? recordingKind;
      try {
        final recordingStart = await recordingAdapter.startRecording(
          recordingRequest,
        );
        if (recordingStart.state != CockpitRecordingState.recording) {
          throw CockpitApplicationServiceException(
            code: 'recordingStartFailed',
            message: 'Recording session did not enter the recording state.',
            details: <String, Object?>{
              'platform': platform,
              'state': recordingStart.state.name,
            },
          );
        }
        recordingStarted = true;
      } on Object catch (error) {
        if (!_shouldAllowWebHostRecordingPrerequisiteFailure(
          platform: platform,
          request: request,
          error: error,
        )) {
          rethrow;
        }
        warnings.add(
          'Web host recording was skipped because the local desktop capture prerequisite is not available: $error',
        );
      }
      final batchResult = await _runBatch(
        CockpitRunBatchRequest(
          app: launchedApp,
          commands: <CockpitRunBatchCommand>[
            CockpitRunBatchCommand(
              command: CockpitCommand(
                commandId: 'verify-open-editor',
                commandType: CockpitCommandType.tap,
                locator: const CockpitLocator(
                  text: 'New task',
                  ancestor: CockpitLocator(route: '/inbox'),
                ),
              ),
            ),
            CockpitRunBatchCommand(
              command: CockpitCommand(
                commandId: 'verify-enter-title',
                commandType: CockpitCommandType.enterText,
                locator: const CockpitLocator(
                  text: 'Task title',
                  ancestor: CockpitLocator(route: '/editor'),
                ),
                parameters: <String, Object?>{'text': taskTitle},
              ),
            ),
            CockpitRunBatchCommand(
              command: CockpitCommand(
                commandId: 'verify-enter-notes',
                commandType: CockpitCommandType.enterText,
                locator: const CockpitLocator(
                  text: 'Notes',
                  ancestor: CockpitLocator(route: '/editor'),
                ),
                parameters: <String, Object?>{'text': taskNotes},
              ),
            ),
            CockpitRunBatchCommand(
              command: CockpitCommand(
                commandId: 'verify-save-task',
                commandType: CockpitCommandType.tap,
                locator: const CockpitLocator(
                  text: 'Save task',
                  ancestor: CockpitLocator(route: '/editor'),
                ),
              ),
            ),
          ],
          defaultResultProfile:
              const CockpitInteractiveResultProfile.standard(),
          failFast: true,
        ),
      );
      _requireBatchSuccess(
        platform: platform,
        result: batchResult,
        expectedCount: 4,
      );
      verifiedCommands.add('run-batch');
      if (recordingStarted) {
        verifiedCommands.add('start-recording');
      }
      if (recordingStarted) {
        try {
          final recordingStop = await recordingAdapter.stopRecording();
          if (recordingStop.state != CockpitRecordingState.completed) {
            throw CockpitApplicationServiceException(
              code: 'recordingStopFailed',
              message: 'Recording session did not complete successfully.',
              details: <String, Object?>{
                'platform': platform,
                'state': recordingStop.state.name,
                'failureReason': recordingStop.failureReason,
              },
            );
          }
          verifiedCommands.add('stop-recording');
          recordingArtifactRef = recordingStop.artifact?.relativePath;
          recordingOutputPath = await _copyArtifactToOutputDir(
            artifact: recordingStop.artifact,
            sourcePath: recordingStop.sourceFilePath,
            outputDir: outputDir,
          );
          recordingDurationMs = recordingStop.durationMs;
          recordingKind = recordingStop.recordingKind?.name;
        } on Object catch (error) {
          if (!_shouldAllowWebHostRecordingPrerequisiteFailure(
            platform: platform,
            request: request,
            error: error,
          )) {
            rethrow;
          }
          warnings.add(
            'Web host recording could not be finalized on this machine: $error',
          );
        }
      }
      final waitIdleResult = await _waitIdle(
        CockpitWaitIdleRequest(
          app: launchedApp,
          quietWindow: const Duration(milliseconds: 160),
          timeout: const Duration(seconds: 5),
        ),
      );
      if (!waitIdleResult.idle) {
        throw CockpitApplicationServiceException(
          code: 'waitIdleTimedOut',
          message: 'The example app did not reach an idle UI state in time.',
          details: <String, Object?>{
            'platform': platform,
            'durationMs': waitIdleResult.durationMs,
            'timeoutMs': waitIdleResult.timeoutMs,
          },
        );
      }
      verifiedCommands.add('wait-idle');

      final postSaveRead = await _readApp(
        CockpitReadAppRequest(
          app: launchedApp,
          resultProfile: const CockpitInteractiveResultProfile.minimal(),
        ),
      );
      _requireRoute(
        routeName: postSaveRead.currentRouteName,
        expectedRoute: '/inbox',
        label: 'post-save route',
        platform: platform,
      );
      await _runRequiredCommand(
        app: launchedApp,
        command: CockpitCommand(
          commandId: 'verify-assert-created-task',
          commandType: CockpitCommandType.assertText,
          parameters: <String, Object?>{'text': taskTitle},
        ),
      );
      final networkResult = await _readNetwork(
        CockpitReadNetworkRequest(
          appHandlePath: resolvedAppJsonPath,
          baseUri: appBaseUri,
        ),
      );
      if (!networkResult.available || networkResult.summary.failureCount > 0) {
        throw CockpitApplicationServiceException(
          code: 'unexpectedNetworkState',
          message:
              'Network telemetry reported missing availability or failures.',
          details: <String, Object?>{
            'platform': platform,
            'available': networkResult.available,
            'failureCount': networkResult.summary.failureCount,
          },
        );
      }
      verifiedCommands.add('read-network');
      final errorsResult = await _readErrors(
        CockpitReadErrorsRequest(
          appHandlePath: resolvedAppJsonPath,
          baseUri: appBaseUri,
          includeLatestTask: false,
          includeSessions: false,
        ),
      );
      if (errorsResult.hasErrors) {
        throw CockpitApplicationServiceException(
          code: 'runtimeErrorsDetected',
          message: 'Runtime errors were captured during verification.',
          details: <String, Object?>{
            'platform': platform,
            'errorCount': errorsResult.errors.length,
          },
        );
      }
      verifiedCommands.add('read-errors');
      final logsResult = await _readLogs(
        CockpitReadLogsRequest(
          appHandlePath: resolvedAppJsonPath,
          maxLines: 40,
        ),
      );
      if (!logsResult.available) {
        throw CockpitApplicationServiceException(
          code: 'logsUnavailable',
          message: 'Runtime or supervisor logs were unavailable.',
          details: <String, Object?>{
            'platform': platform,
            'missingReason': logsResult.missingReason,
          },
        );
      }
      verifiedCommands.add('read-logs');

      final inspectResult = await _inspectSurface(
        CockpitInspectSurfaceRequest(
          app: launchedApp,
          resultProfile: const CockpitInteractiveResultProfile.inspect(),
        ),
      );
      if (inspectResult.selectedPlane !=
          CockpitPlaneKind.flutterSemanticPlane) {
        throw CockpitApplicationServiceException(
          code: 'unexpectedInspectPlane',
          message: 'Expected flutterSemanticPlane during example verification.',
          details: <String, Object?>{
            'platform': platform,
            'selectedPlane': inspectResult.selectedPlane.name,
          },
        );
      }
      verifiedCommands.add('inspect-surface');
      final captureResult = await _runRequiredCommand(
        app: launchedApp,
        command: CockpitCommand(
          commandId: 'verify-capture-screenshot',
          commandType: CockpitCommandType.captureScreenshot,
          screenshotRequest: const CockpitScreenshotRequest(
            reason: CockpitScreenshotReason.acceptance,
            name: 'platform_verifier',
            includeSnapshot: true,
            attachToStep: true,
          ),
        ),
        resultProfile: const CockpitInteractiveResultProfile.evidence(),
      );
      final screenshotArtifact = captureResult.artifacts.firstWhere(
        (artifact) => artifact.role == 'screenshot',
        orElse: () => throw CockpitApplicationServiceException(
          code: 'screenshotMissing',
          message:
              'Screenshot command succeeded without returning an artifact.',
          details: <String, Object?>{'platform': platform},
        ),
      );
      verifiedCommands.add('capture-screenshot');

      final hotReloadResult = await _hotReload(
        CockpitHotReloadRequest(app: launchedApp),
      );
      if (hotReloadResult.status.lastReloadSucceeded != true) {
        throw CockpitApplicationServiceException(
          code: 'hotReloadFailed',
          message: 'Hot reload did not report a successful completion.',
          details: <String, Object?>{
            'platform': platform,
            'state': hotReloadResult.status.state.jsonValue,
          },
        );
      }
      verifiedCommands.add('hot-reload');

      final postReloadRead = await _readApp(
        CockpitReadAppRequest(
          app: launchedApp,
          resultProfile: const CockpitInteractiveResultProfile.minimal(),
        ),
      );
      _requireRoute(
        routeName: postReloadRead.currentRouteName,
        expectedRoute: '/inbox',
        label: 'post-reload route',
        platform: platform,
      );
      final hotRestartResult = await _hotRestart(
        CockpitHotRestartRequest(app: launchedApp),
      );
      if (hotRestartResult.status.lastReloadSucceeded != true) {
        throw CockpitApplicationServiceException(
          code: 'hotRestartFailed',
          message: 'Hot restart did not report a successful completion.',
          details: <String, Object?>{
            'platform': platform,
            'state': hotRestartResult.status.state.jsonValue,
          },
        );
      }
      if (hotRestartResult.status.reloadGeneration <=
          hotReloadResult.status.reloadGeneration) {
        throw CockpitApplicationServiceException(
          code: 'reloadGenerationDidNotAdvance',
          message: 'Hot restart did not advance the development generation.',
          details: <String, Object?>{
            'platform': platform,
            'hotReloadGeneration': hotReloadResult.status.reloadGeneration,
            'hotRestartGeneration': hotRestartResult.status.reloadGeneration,
          },
        );
      }
      verifiedCommands.add('hot-restart');
      final postRestartRead = await _readApp(
        CockpitReadAppRequest(
          app: hotRestartResult.app,
          resultProfile: const CockpitInteractiveResultProfile.minimal(),
        ),
      );
      _requireRoute(
        routeName: postRestartRead.currentRouteName,
        expectedRoute: '/inbox',
        label: 'post-restart route',
        platform: platform,
      );

      return CockpitDemoPlatformVerification(
        platform: platform,
        status: 'passed',
        deviceId: deviceId,
        bootstrappedDevice: bootstrappedDevice,
        outputDir: outputDir,
        appJsonPath: resolvedAppJsonPath,
        baseUrl: launchedApp.baseUrl,
        initialRouteName: initialRead.currentRouteName,
        inspectUiRouteName: inspectUiResult.routeName,
        postSaveRouteName: postSaveRead.currentRouteName,
        postReloadRouteName: postReloadRead.currentRouteName,
        postRestartRouteName: postRestartRead.currentRouteName,
        inspectRouteName: inspectResult.routeName,
        inspectPlane: inspectResult.selectedPlane.name,
        surfaceKind: inspectResult.surfaceKind.name,
        createdTaskTitle: taskTitle,
        hotReloadSucceeded: hotReloadResult.status.lastReloadSucceeded ?? false,
        hotRestartSucceeded:
            hotRestartResult.status.lastReloadSucceeded ?? false,
        reloadGeneration: hotRestartResult.status.reloadGeneration,
        waitIdleSucceeded: waitIdleResult.idle,
        waitIdleDurationMs: waitIdleResult.durationMs,
        batchCommandCount: batchResult.summary.totalCount,
        networkFailureCount: networkResult.summary.failureCount,
        runtimeErrorCount: errorsResult.errors.length,
        logLineCount: logsResult.lines.length,
        recordingArtifactRef: recordingArtifactRef,
        recordingOutputPath: recordingOutputPath,
        recordingDurationMs: recordingDurationMs,
        recordingKind: recordingKind,
        recordingDriver: cockpitDemoRecordingDriverForPlatform(platform),
        screenshotArtifactRef: screenshotArtifact.relativePath,
        screenshotByteLength: screenshotArtifact.byteLength,
        verifiedCommands: verifiedCommands,
        warnings: warnings,
      );
    } on Object catch (error) {
      return CockpitDemoPlatformVerification(
        platform: platform,
        status: 'failed',
        deviceId: deviceId ?? platform,
        bootstrappedDevice: bootstrappedDevice,
        outputDir: outputDir,
        appJsonPath: appJsonPath,
        baseUrl: app?.baseUrl,
        failureCode: error is CockpitApplicationServiceException
            ? error.code
            : error.runtimeType.toString(),
        failureMessage: '$error',
      );
    } finally {
      if (app != null) {
        try {
          await _stopApp(CockpitStopAppRequest(app: app));
        } on Object {
          // Preserve the primary verification result and avoid shadowing it.
        }
      }
      if (platform == 'android' &&
          deviceId != null &&
          deviceId.isNotEmpty &&
          deviceId != 'android') {
        await _cleanupAndroidPortForward(
          deviceId: deviceId,
          sessionPort: sessionPort,
          workingDirectory: request.projectDir,
        );
      }
    }
  }

  Future<_ResolvedDevice> _ensureDeviceForPlatform({
    required String platform,
    required CockpitDemoPlatformVerificationRequest request,
  }) async {
    final available = await _probeDevices();
    final existing = _matchingDevice(available, platform);
    if (existing != null) {
      return _ResolvedDevice(deviceId: existing.deviceId, bootstrapped: false);
    }

    switch (platform) {
      case 'macos':
        throw const CockpitApplicationServiceException(
          code: 'macosUnavailable',
          message: 'macOS is not available in flutter devices.',
        );
      case 'linux':
        throw const CockpitApplicationServiceException(
          code: 'linuxUnavailable',
          message: 'Linux desktop is not available in flutter devices.',
        );
      case 'windows':
        throw const CockpitApplicationServiceException(
          code: 'windowsUnavailable',
          message: 'Windows desktop is not available in flutter devices.',
        );
      case 'web':
        throw const CockpitApplicationServiceException(
          code: 'webUnavailable',
          message:
              'A supported web browser is not available in flutter devices.',
        );
      case 'ios':
        final simulators = await _listIosSimulators();
        final simulator = _selectIosSimulator(simulators);
        if (simulator == null) {
          throw const CockpitApplicationServiceException(
            code: 'iosSimulatorUnavailable',
            message: 'No available iOS simulator could be selected.',
          );
        }
        if (!simulator.booted) {
          await _runProcess(
            'xcrun',
            <String>['simctl', 'boot', simulator.udid],
            workingDirectory: request.projectDir,
          );
        }
        await _runProcess(
          'xcrun',
          <String>['simctl', 'bootstatus', simulator.udid, '-b'],
          workingDirectory: request.projectDir,
        );
        return _waitForDevice(
          platform: platform,
          timeout: request.deviceTimeout,
        );
      case 'android':
        await _runProcess(
          'flutter',
          <String>['emulators', '--launch', request.androidEmulatorId],
          workingDirectory: request.projectDir,
        );
        return _waitForDevice(
          platform: platform,
          timeout: request.deviceTimeout,
        );
    }
    throw CockpitApplicationServiceException(
      code: 'unsupportedVerificationPlatform',
      message:
          'Only android, ios, linux, macos, web, and windows are supported.',
      details: <String, Object?>{'platform': platform},
    );
  }

  Future<_ResolvedDevice> _waitForDevice({
    required String platform,
    required Duration timeout,
  }) async {
    final deadline = _clock().add(timeout);
    while (!_clock().isAfter(deadline)) {
      final devices = await _probeDevices();
      final device = _matchingDevice(devices, platform);
      if (device != null) {
        return _ResolvedDevice(deviceId: device.deviceId, bootstrapped: true);
      }
      await _wait(const Duration(seconds: 2));
    }
    throw CockpitApplicationServiceException(
      code: 'deviceBootstrapTimeout',
      message: 'Timed out waiting for $platform to become available.',
      details: <String, Object?>{'platform': platform},
    );
  }

  CockpitDemoHostDevice? _matchingDevice(
    List<CockpitDemoHostDevice> devices,
    String platform,
  ) {
    for (final device in devices) {
      if (!device.supported || device.platform != platform) {
        continue;
      }
      if (_isDesktopVerificationPlatform(platform) || device.emulator) {
        return device;
      }
    }
    return null;
  }

  CockpitDemoIosSimulator? _selectIosSimulator(
    List<CockpitDemoIosSimulator> simulators,
  ) {
    final available = simulators.where((simulator) => simulator.available);
    return available.firstWhere(
      (simulator) => simulator.booted && simulator.isPhone,
      orElse: () => available.firstWhere(
        (simulator) => simulator.isPhone,
        orElse: () => available.firstWhere(
          (_) => true,
          orElse: () => throw const CockpitApplicationServiceException(
            code: 'iosSimulatorUnavailable',
            message: 'No available iOS simulator could be selected.',
          ),
        ),
      ),
    );
  }

  void _requireBatchSuccess({
    required String platform,
    required CockpitRunBatchResult result,
    required int expectedCount,
  }) {
    if (result.summary.failureCount == 0 &&
        !result.summary.stoppedEarly &&
        result.summary.totalCount == expectedCount &&
        result.results.every((entry) => entry.command.success)) {
      return;
    }
    final failedCommand = result.results
        .map((entry) => entry.command)
        .firstWhere(
          (command) => !command.success,
          orElse: () => throw CockpitApplicationServiceException(
            code: 'invalidBatchSummary',
            message: 'Batch verification summary did not match expectations.',
            details: <String, Object?>{
              'platform': platform,
              'totalCount': result.summary.totalCount,
              'failureCount': result.summary.failureCount,
              'stoppedEarly': result.summary.stoppedEarly,
            },
          ),
        );
    throw CockpitApplicationServiceException(
      code: 'exampleBatchFailed',
      message: 'A required example batch command failed.',
      details: <String, Object?>{
        'platform': platform,
        'commandId': failedCommand.commandId,
        'commandType': failedCommand.commandType,
      },
    );
  }

  Future<CockpitExecuteRemoteCommandResult> _runRequiredCommand({
    required CockpitAppHandle app,
    required CockpitCommand command,
    CockpitInteractiveResultProfile resultProfile =
        const CockpitInteractiveResultProfile.standard(),
  }) async {
    final result = await _runCommand(
      CockpitRunCommandRequest(
        app: app,
        command: command,
        resultProfile: resultProfile,
      ),
    );
    if (!result.command.success) {
      throw CockpitApplicationServiceException(
        code: 'exampleCommandFailed',
        message: 'A required example verification command failed.',
        details: <String, Object?>{
          'commandId': command.commandId,
          'commandType': command.commandType.name,
        },
      );
    }
    return result;
  }

  Future<String?> _copyArtifactToOutputDir({
    required CockpitArtifactRef? artifact,
    required String? sourcePath,
    required String outputDir,
  }) async {
    final relativePath = artifact?.relativePath;
    if (sourcePath == null ||
        sourcePath.isEmpty ||
        relativePath == null ||
        relativePath.isEmpty) {
      return null;
    }
    final sourceFile = File(sourcePath);
    if (!sourceFile.existsSync()) {
      return null;
    }
    final destinationPath = p.join(outputDir, relativePath);
    final destinationFile = File(destinationPath);
    await destinationFile.parent.create(recursive: true);
    await sourceFile.copy(destinationFile.path);
    return p.normalize(destinationFile.path);
  }

  Future<ProcessResult> _runProcess(
    String executable,
    List<String> arguments, {
    required String workingDirectory,
  }) async {
    final result = await _processRunner(
      executable,
      arguments,
      workingDirectory: workingDirectory,
    );
    if (result.exitCode != 0) {
      throw CockpitApplicationServiceException(
        code: 'processFailed',
        message: 'External command failed during platform verification.',
        details: <String, Object?>{
          'command': <String>[executable, ...arguments],
          'exitCode': result.exitCode,
          'stderr': '${result.stderr}',
        },
      );
    }
    return result;
  }

  void _requireRoute({
    required String? routeName,
    required String expectedRoute,
    required String label,
    required String platform,
  }) {
    if (routeName == expectedRoute) {
      return;
    }
    throw CockpitApplicationServiceException(
      code: 'unexpectedRoute',
      message: 'The example app did not land on the expected route.',
      details: <String, Object?>{
        'platform': platform,
        'label': label,
        'expectedRoute': expectedRoute,
        'actualRoute': routeName,
      },
    );
  }

  Future<void> _cleanupAndroidPortForward({
    required String deviceId,
    required int sessionPort,
    required String workingDirectory,
  }) async {
    try {
      await _processRunner(
        'adb',
        <String>[
          '-s',
          deviceId,
          'forward',
          '--remove',
          'tcp:$sessionPort',
        ],
        workingDirectory: workingDirectory,
      );
    } on Object {
      // Best effort cleanup to avoid stale forwards across verification runs.
    }
  }
}

Future<List<CockpitDemoHostDevice>> cockpitDemoProbeHostDevices({
  CockpitDemoProcessRunner processRunner = Process.run,
  String? workingDirectory,
}) async {
  final result = await processRunner(
    'flutter',
    const <String>['devices', '--machine'],
    workingDirectory: workingDirectory,
  );
  if (result.exitCode != 0) {
    throw CockpitApplicationServiceException(
      code: 'deviceProbeFailed',
      message: 'Unable to read flutter devices for example verification.',
      details: <String, Object?>{
        'stderr': '${result.stderr}',
        'exitCode': result.exitCode,
      },
    );
  }
  final decoded = jsonDecode('${result.stdout}');
  if (decoded is! List<Object?>) {
    throw const CockpitApplicationServiceException(
      code: 'invalidDeviceProbeJson',
      message: 'flutter devices --machine must return a JSON array.',
    );
  }
  return decoded
      .whereType<Map<Object?, Object?>>()
      .map(
        (device) => CockpitDemoHostDevice.fromJson(
          Map<String, Object?>.from(device),
        ),
      )
      .toList(growable: false);
}

Future<List<CockpitDemoIosSimulator>> cockpitDemoListIosSimulators({
  CockpitDemoProcessRunner processRunner = Process.run,
  String? workingDirectory,
}) async {
  final result = await processRunner(
    'xcrun',
    const <String>['simctl', 'list', 'devices', '--json'],
    workingDirectory: workingDirectory,
  );
  if (result.exitCode != 0) {
    throw CockpitApplicationServiceException(
      code: 'iosSimulatorProbeFailed',
      message: 'Unable to read iOS simulator metadata.',
      details: <String, Object?>{
        'stderr': '${result.stderr}',
        'exitCode': result.exitCode,
      },
    );
  }
  final decoded = jsonDecode('${result.stdout}');
  if (decoded is! Map<Object?, Object?>) {
    throw const CockpitApplicationServiceException(
      code: 'invalidSimulatorJson',
      message: 'simctl list devices --json must return an object.',
    );
  }
  final devices = decoded['devices'];
  if (devices is! Map<Object?, Object?>) {
    throw const CockpitApplicationServiceException(
      code: 'invalidSimulatorJson',
      message: 'simctl device payload is missing the devices map.',
    );
  }
  final simulators = <CockpitDemoIosSimulator>[];
  for (final entry in devices.values.whereType<List<Object?>>()) {
    for (final simulator in entry.whereType<Map<Object?, Object?>>()) {
      simulators.add(
        CockpitDemoIosSimulator(
          name: '${simulator['name'] ?? ''}',
          udid: '${simulator['udid'] ?? ''}',
          state: '${simulator['state'] ?? ''}',
          available: simulator['isAvailable'] as bool? ?? false,
        ),
      );
    }
  }
  return simulators;
}

Future<int> cockpitDemoAllocateSessionPort({required int preferredPort}) async {
  try {
    final preferredSocket = await ServerSocket.bind(
      InternetAddress.loopbackIPv4,
      preferredPort,
    );
    try {
      return preferredSocket.port;
    } finally {
      await preferredSocket.close();
    }
  } on SocketException {
    final fallbackSocket = await ServerSocket.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    try {
      return fallbackSocket.port;
    } finally {
      await fallbackSocket.close();
    }
  }
}

Future<CockpitReadNetworkResult> cockpitDemoReadNetwork(
  CockpitReadNetworkRequest request,
) async {
  final resolved = await _resolveRemoteReference(
    appId: request.appId,
    appHandlePath: request.appHandlePath,
    baseUri: request.baseUri,
  );
  final snapshot = (await resolved.client.readSnapshotDetailed(
    options: CockpitSnapshotOptions(
      includeNetworkActivity: true,
      maxNetworkEntries: request.maxEntries <= 0 ? 8 : request.maxEntries,
      networkQuery: request.networkQuery,
    ),
  ))
      .snapshot;
  final network = snapshot.network;
  if (network == null) {
    return CockpitReadNetworkResult(
      appId: resolved.appId,
      source: 'app_snapshot',
      available: true,
      routeName: snapshot.routeName,
      summary: CockpitReadNetworkSummary(
        totalEntryCount: 0,
        failureCount: 0,
        capturedEntryCount: 0,
        inFlightCount: 0,
        truncated: false,
        query: request.networkQuery,
      ),
      endpointSummaries: const <CockpitNetworkEndpointSummary>[],
      endpointSummariesTruncated: false,
      recentFailures: const <CockpitNetworkEntry>[],
      entries: request.includeEntries ? const <CockpitNetworkEntry>[] : null,
    );
  }

  final maxEndpointSummaries =
      request.maxEndpointSummaries <= 0 ? 8 : request.maxEndpointSummaries;
  final endpointSummaries =
      network.endpointSummaries.length > maxEndpointSummaries
          ? network.endpointSummaries.sublist(0, maxEndpointSummaries)
          : network.endpointSummaries;
  final recentFailures =
      network.entries.where((entry) => entry.isFailure).toList(growable: false);

  return CockpitReadNetworkResult(
    appId: resolved.appId,
    source: 'app_snapshot',
    available: true,
    routeName: snapshot.routeName,
    summary: CockpitReadNetworkSummary(
      totalEntryCount: network.totalEntryCount,
      failureCount: network.failureCount,
      capturedEntryCount: network.capturedEntryCount,
      inFlightCount: network.inFlightCount,
      truncated: network.truncated,
      query: network.query,
    ),
    endpointSummaries:
        List<CockpitNetworkEndpointSummary>.unmodifiable(endpointSummaries),
    endpointSummariesTruncated:
        network.endpointSummaries.length > endpointSummaries.length,
    recentFailures: List<CockpitNetworkEntry>.unmodifiable(recentFailures),
    entries: request.includeEntries
        ? List<CockpitNetworkEntry>.unmodifiable(network.entries)
        : null,
  );
}

Future<CockpitReadErrorsResult> cockpitDemoReadErrors(
  CockpitReadErrorsRequest request,
) async {
  final resolved = await _resolveRemoteReference(
    appId: request.appId,
    appHandlePath: request.appHandlePath,
    baseUri: request.baseUri,
  );
  final snapshot = (await resolved.client.readSnapshotDetailed(
    options: CockpitSnapshotOptions(
      profile: CockpitSnapshotProfile.investigate,
      includeRuntimeActivity: true,
      maxRuntimeEntries: request.maxErrors <= 0 ? 20 : request.maxErrors,
      runtimeQuery: const CockpitRuntimeQuery(onlyErrors: true),
    ),
  ))
      .snapshot;
  final runtime = snapshot.runtime;
  final errors = runtime == null
      ? const <CockpitErrorEntry>[]
      : runtime.entries
          .map(
            (entry) => CockpitErrorEntry(
              source: 'app_snapshot',
              message: entry.message,
              recordedAt: entry.recordedAt,
              kind: entry.kind.jsonValue,
              routeName: entry.routeName ?? snapshot.routeName,
            ),
          )
          .toList(growable: false);
  return CockpitReadErrorsResult(
    appId: resolved.appId,
    routeName: snapshot.routeName,
    source: 'app_snapshot',
    errors: errors,
  );
}

Future<CockpitReadLogsResult> cockpitDemoReadLogs(
  CockpitReadLogsRequest request,
) async {
  final resolved = await _resolveRemoteReference(
    appId: request.appId,
    appHandlePath: request.appHandlePath,
    baseUri: null,
  );
  final maxLines = request.maxLines <= 0 ? 200 : request.maxLines;
  try {
    final snapshot = (await resolved.client.readSnapshotDetailed(
      options: CockpitSnapshotOptions(
        includeRuntimeActivity: true,
        maxRuntimeEntries: maxLines,
      ),
    ))
        .snapshot;
    final runtime = snapshot.runtime;
    return CockpitReadLogsResult(
      appId: resolved.appId,
      source: 'app_snapshot',
      available: true,
      routeName: snapshot.routeName,
      lines: runtime == null
          ? const <String>[]
          : List<String>.unmodifiable(
              runtime.entries.map(_formatRuntimeLogLine),
            ),
      truncated: runtime?.truncated ?? false,
    );
  } on Object {
    final supervisorLogPath = resolved.app?.supervisorLogPath;
    if (supervisorLogPath == null || supervisorLogPath.isEmpty) {
      return CockpitReadLogsResult(
        appId: resolved.appId,
        source: 'supervisor',
        available: false,
        lines: const <String>[],
        truncated: false,
        missingReason: 'log_unavailable',
      );
    }
    final file = File(supervisorLogPath);
    if (!file.existsSync()) {
      return CockpitReadLogsResult(
        appId: resolved.appId,
        source: 'supervisor',
        available: false,
        logPath: supervisorLogPath,
        lines: const <String>[],
        truncated: false,
        missingReason: 'log_file_missing',
      );
    }
    final lines = await file.readAsLines();
    final truncated = lines.length > maxLines;
    final visibleLines =
        truncated ? lines.sublist(lines.length - maxLines) : lines;
    return CockpitReadLogsResult(
      appId: resolved.appId,
      source: 'supervisor',
      available: true,
      logPath: supervisorLogPath,
      lines: List<String>.unmodifiable(visibleLines),
      truncated: truncated,
    );
  }
}

CockpitRecordingAdapter? cockpitDemoResolveRecordingAdapter({
  required String platform,
  required String deviceId,
  required CockpitRemoteSessionClient client,
  required CockpitRecordingRequest recording,
}) {
  return const CockpitRecordingStrategyResolver().resolve(
    platform: platform,
    recording: recording,
    client: client,
    androidDeviceId: platform == 'android' ? deviceId : null,
    iosDeviceId: platform == 'ios' ? deviceId : null,
  );
}

String cockpitDemoRecordingDriverForPlatform(String platform) {
  return switch (platform) {
    'android' => 'adb',
    'ios' => 'simctl',
    'web' => 'browser-host',
    _ => 'remote',
  };
}

Future<_ResolvedRemoteReference> _resolveRemoteReference({
  required String? appId,
  required String? appHandlePath,
  required Uri? baseUri,
}) async {
  CockpitAppHandle? app;
  if (appHandlePath != null && appHandlePath.isNotEmpty) {
    final payload = jsonDecode(await File(appHandlePath).readAsString());
    if (payload is! Map<Object?, Object?>) {
      throw const CockpitApplicationServiceException(
        code: 'invalidAppHandleJson',
        message: 'App handle JSON must decode to an object.',
      );
    }
    app = CockpitAppHandle.fromJson(Map<String, Object?>.from(payload));
  }
  final resolvedBaseUri = baseUri ?? app?.baseUri;
  if (resolvedBaseUri == null) {
    throw const CockpitApplicationServiceException(
      code: 'appReferenceRequired',
      message: 'A base URI or app handle is required for remote verification.',
    );
  }
  return _ResolvedRemoteReference(
    appId: app?.appId ?? appId ?? 'unknown',
    app: app,
    client: CockpitRemoteSessionClient(baseUri: resolvedBaseUri),
  );
}

String _formatRuntimeLogLine(CockpitRuntimeEvent entry) {
  final parts = <String>[
    entry.severity.jsonValue,
    entry.kind.jsonValue,
    if (entry.source != null && entry.source!.isNotEmpty) entry.source!,
  ];
  return '${parts.join(' ')}: ${entry.message}';
}

String _normalizePlatform(String platform) {
  return switch (platform) {
    'android' || 'ios' || 'linux' || 'macos' || 'web' || 'windows' => platform,
    _ => throw CockpitApplicationServiceException(
        code: 'unsupportedVerificationPlatform',
        message:
            'Only android, ios, linux, macos, web, and windows are supported.',
        details: <String, Object?>{'platform': platform},
      ),
  };
}

bool _isDesktopVerificationPlatform(String platform) {
  return switch (platform) {
    'linux' || 'macos' || 'web' || 'windows' => true,
    _ => false,
  };
}

Future<void> _defaultWait(Duration duration) => Future<void>.delayed(duration);

bool _shouldAllowWebHostRecordingPrerequisiteFailure({
  required String platform,
  required CockpitDemoPlatformVerificationRequest request,
  required Object error,
}) {
  if (platform != 'web' || !request.allowWebHostRecordingPrerequisiteFailure) {
    return false;
  }

  final message = '$error';
  return message.contains('Remote session request failed: 412') ||
      message.contains('"error":"recordingStartFailed"') ||
      message.contains('Screen Recording permission') ||
      message.contains('desktop capture prerequisite');
}

final class _ResolvedRemoteReference {
  const _ResolvedRemoteReference({
    required this.appId,
    required this.client,
    this.app,
  });

  final String appId;
  final CockpitAppHandle? app;
  final CockpitRemoteSessionClient client;
}

final class _ResolvedDevice {
  const _ResolvedDevice({
    required this.deviceId,
    required this.bootstrapped,
  });

  final String deviceId;
  final bool bootstrapped;
}

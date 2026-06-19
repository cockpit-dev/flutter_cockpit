import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:cockpit/cockpit.dart';
import 'package:cockpit/src/platform/ios/cockpit_ios_device_connection.dart';
import 'package:path/path.dart' as p;

import 'cockpit_demo_sync_lab_verification.dart';

typedef CockpitDemoPlatformDeviceProbe =
    Future<List<CockpitDemoHostDevice>> Function();
typedef CockpitDemoIosSimulatorProbe =
    Future<List<CockpitDemoIosSimulator>> Function();
typedef CockpitDemoProcessRunner =
    Future<ProcessResult> Function(
      String executable,
      List<String> arguments, {
      String? workingDirectory,
    });
typedef CockpitDemoWait = Future<void> Function(Duration duration);
typedef CockpitDemoClock = DateTime Function();
typedef CockpitDemoLaunchAppFunction =
    Future<CockpitLaunchAppResult> Function(CockpitLaunchAppRequest request);
typedef CockpitDemoReadAppFunction =
    Future<CockpitReadAppResult> Function(CockpitReadAppRequest request);
typedef CockpitDemoRunCommandFunction =
    Future<CockpitExecuteRemoteCommandResult> Function(
      CockpitRunCommandRequest request,
    );
typedef CockpitDemoRunBatchFunction =
    Future<CockpitRunBatchResult> Function(CockpitRunBatchRequest request);
typedef CockpitDemoInspectUiFunction =
    Future<CockpitInspectUiResult> Function(CockpitInspectUiRequest request);
typedef CockpitDemoInspectSurfaceFunction =
    Future<CockpitInspectSurfaceResult> Function(
      CockpitInspectSurfaceRequest request,
    );
typedef CockpitDemoWaitIdleFunction =
    Future<CockpitWaitIdleResult> Function(CockpitWaitIdleRequest request);
typedef CockpitDemoReadNetworkFunction =
    Future<CockpitReadNetworkResult> Function(
      CockpitReadNetworkRequest request,
    );
typedef CockpitDemoReadErrorsFunction =
    Future<CockpitReadErrorsResult> Function(CockpitReadErrorsRequest request);
typedef CockpitDemoReadLogsFunction =
    Future<CockpitReadLogsResult> Function(CockpitReadLogsRequest request);
typedef CockpitDemoRecordingAdapterResolver =
    CockpitRecordingAdapter? Function({
      required String platform,
      required String deviceId,
      required CockpitAppHandle app,
      required CockpitRemoteSessionClient client,
      required CockpitRecordingRequest recording,
    });
typedef CockpitDemoHotReloadFunction =
    Future<CockpitHotReloadResult> Function(CockpitHotReloadRequest request);
typedef CockpitDemoHotRestartFunction =
    Future<CockpitHotRestartResult> Function(CockpitHotRestartRequest request);
typedef CockpitDemoStopAppFunction =
    Future<CockpitStopAppResult> Function(CockpitStopAppRequest request);
typedef CockpitDemoTimelineRecordingProcessRunner =
    Future<ProcessResult> Function(String executable, List<String> arguments);
typedef CockpitDemoSystemControlDescribeFunction =
    Future<CockpitSystemControlDescribeResult> Function(
      CockpitSystemControlDescribeRequest request,
    );
typedef CockpitDemoSystemControlRunActionFunction =
    Future<CockpitSystemControlActionResult> Function(
      CockpitSystemControlActionRequest request,
    );
typedef CockpitDemoVerificationProgressSink =
    void Function(CockpitDemoVerificationProgressEvent event);

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

const int cockpitDemoExpectedBatchCommandCount = 31;
const int cockpitDemoMinimumAutoScreenshotCount = 18;
const CockpitInteractiveResultProfile _artifactEvidenceProfile =
    CockpitInteractiveResultProfile(
      name: CockpitInteractiveResultProfileName.standard,
      ui: CockpitInteractiveUiLevel.summary,
      diagnostics: CockpitInteractiveDiagnosticsLevel.none,
      artifacts: CockpitInteractiveArtifactLevel.metadata,
      includeDelta: false,
      includeRuntimeSteps: false,
      emitSnapshotRef: true,
      snapshotProfile: CockpitSnapshotProfile.baseline,
    );

final class CockpitDemoVerificationProgressEvent {
  const CockpitDemoVerificationProgressEvent({
    required this.platform,
    required this.stage,
    required this.message,
    required this.timestamp,
  });

  final String platform;
  final String stage;
  final String message;
  final DateTime timestamp;

  Map<String, Object?> toJson() => <String, Object?>{
    'platform': platform,
    'stage': stage,
    'message': message,
    'timestamp': timestamp.toUtc().toIso8601String(),
  };

  String toAiLine() {
    return '[${timestamp.toUtc().toIso8601String()}] '
        'platform=$platform stage=$stage $message';
  }
}

String cockpitDemoDefaultProjectDir({
  required String currentDirectory,
  String? scriptPath,
}) {
  final fallback = p.normalize(currentDirectory);
  if (scriptPath == null || scriptPath.isEmpty) {
    return fallback;
  }

  final candidate = p.normalize(
    p.join(p.dirname(p.normalize(scriptPath)), '..'),
  );
  return p.basename(candidate) == 'cockpit_demo' ? candidate : fallback;
}

String cockpitDemoResolveArtifactOutputPath({
  required String outputDir,
  required String relativePath,
}) {
  final normalizedRelativePath = p.normalize(relativePath);
  if (normalizedRelativePath.isEmpty ||
      normalizedRelativePath == '.' ||
      p.isAbsolute(normalizedRelativePath)) {
    throw CockpitApplicationServiceException(
      code: 'invalidArtifactPath',
      message: 'Artifact paths must be relative paths inside the output root.',
      details: <String, Object?>{'artifactPath': relativePath},
    );
  }

  final outputRoot = p.normalize(p.absolute(outputDir));
  final destinationPath = p.normalize(
    p.join(outputRoot, normalizedRelativePath),
  );
  if (!p.isWithin(outputRoot, destinationPath)) {
    throw CockpitApplicationServiceException(
      code: 'invalidArtifactPath',
      message: 'Artifact path escapes the output root.',
      details: <String, Object?>{
        'artifactPath': relativePath,
        'outputRoot': outputRoot,
      },
    );
  }
  return destinationPath;
}

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
    this.strictWebHostRecording = false,
    this.exhaustiveSystemControl = false,
    this.failFast = false,
    this.progressSink,
  });

  final String projectDir;
  final List<String> platforms;
  final String? target;
  final String outputRoot;
  final int sessionPortBase;
  final Duration launchTimeout;
  final Duration deviceTimeout;
  final String androidEmulatorId;
  final bool strictWebHostRecording;
  final bool exhaustiveSystemControl;
  final bool failFast;
  final CockpitDemoVerificationProgressSink? progressSink;
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
    this.autoScreenshotCount = 0,
    this.exportedScreenshotCount = 0,
    this.networkFailureCount = 0,
    this.runtimeErrorCount = 0,
    this.logLineCount = 0,
    this.recordingArtifactRef,
    this.recordingOutputPath,
    this.recordingDurationMs,
    this.recordingKind,
    this.recordingDriver,
    this.screenshotArtifactRef,
    this.screenshotOutputPath,
    this.screenshotByteLength,
    this.systemControlAdapter,
    this.systemAvailableActions = const <String>[],
    this.systemVerifiedActions = const <String>[],
    this.systemSkippedActions = const <String>[],
    this.verifiedCommands = const <String>[],
    this.warnings = const <String>[],
    this.baseUrl,
    this.failureCode,
    this.failureMessage,
    this.failureDetails = const <String, Object?>{},
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
  final int autoScreenshotCount;
  final int exportedScreenshotCount;
  final int networkFailureCount;
  final int runtimeErrorCount;
  final int logLineCount;
  final String? recordingArtifactRef;
  final String? recordingOutputPath;
  final int? recordingDurationMs;
  final String? recordingKind;
  final String? recordingDriver;
  final String? screenshotArtifactRef;
  final String? screenshotOutputPath;
  final int? screenshotByteLength;
  final String? systemControlAdapter;
  final List<String> systemAvailableActions;
  final List<String> systemVerifiedActions;
  final List<String> systemSkippedActions;
  final List<String> verifiedCommands;
  final List<String> warnings;
  final String? baseUrl;
  final String? failureCode;
  final String? failureMessage;
  final Map<String, Object?> failureDetails;

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
    if (inspectUiRouteName != null) 'inspectUiRouteName': inspectUiRouteName,
    if (postSaveRouteName != null) 'postSaveRouteName': postSaveRouteName,
    if (postReloadRouteName != null) 'postReloadRouteName': postReloadRouteName,
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
    'autoScreenshotCount': autoScreenshotCount,
    'exportedScreenshotCount': exportedScreenshotCount,
    'networkFailureCount': networkFailureCount,
    'runtimeErrorCount': runtimeErrorCount,
    'logLineCount': logLineCount,
    if (recordingArtifactRef != null)
      'recordingArtifactRef': recordingArtifactRef,
    if (recordingOutputPath != null) 'recordingOutputPath': recordingOutputPath,
    if (recordingDurationMs != null) 'recordingDurationMs': recordingDurationMs,
    if (recordingKind != null) 'recordingKind': recordingKind,
    if (recordingDriver != null) 'recordingDriver': recordingDriver,
    if (screenshotArtifactRef != null)
      'screenshotArtifactRef': screenshotArtifactRef,
    if (screenshotOutputPath != null)
      'screenshotOutputPath': screenshotOutputPath,
    if (screenshotByteLength != null)
      'screenshotByteLength': screenshotByteLength,
    if (systemControlAdapter != null)
      'systemControlAdapter': systemControlAdapter,
    'systemAvailableActions': systemAvailableActions,
    'systemVerifiedActions': systemVerifiedActions,
    'systemSkippedActions': systemSkippedActions,
    'verifiedCommands': verifiedCommands,
    if (warnings.isNotEmpty) 'warnings': warnings,
    if (failureCode != null) 'failureCode': failureCode,
    if (failureMessage != null) 'failureMessage': failureMessage,
    if (failureDetails.isNotEmpty) 'failureDetails': failureDetails,
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
    CockpitDemoTimelineRecordingProcessRunner? timelineRecordingProcessRunner,
    CockpitDemoSystemControlDescribeFunction? describeSystemControl,
    CockpitDemoSystemControlRunActionFunction? runSystemAction,
    bool? isWindows,
  }) : _probeDevices =
           probeDevices ??
           (() => cockpitDemoProbeHostDevices(
             processRunner: runProcess,
             isWindows: isWindows,
           )),
       _listIosSimulators =
           listIosSimulators ??
           (() => cockpitDemoListIosSimulators(processRunner: runProcess)),
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
       _stopApp = stopApp ?? CockpitStopAppService().stop,
       _timelineRecordingProcessRunner =
           timelineRecordingProcessRunner ?? Process.run,
       _describeSystemControl =
           describeSystemControl ?? CockpitSystemControlService().describe,
       _runSystemAction =
           runSystemAction ?? CockpitSystemControlActionService().run,
       _isWindows = isWindows ?? Platform.isWindows;

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
  final CockpitDemoTimelineRecordingProcessRunner
  _timelineRecordingProcessRunner;
  final CockpitDemoSystemControlDescribeFunction _describeSystemControl;
  final CockpitDemoSystemControlRunActionFunction _runSystemAction;
  final bool _isWindows;

  Future<CockpitDemoPlatformVerificationResult> verify(
    CockpitDemoPlatformVerificationRequest request,
  ) async {
    final results = <CockpitDemoPlatformVerification>[];
    final normalizedPlatforms = request.platforms
        .map(cockpitDemoNormalizeVerificationPlatform)
        .toList(growable: false);

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
    CockpitRecordingAdapter? activeRecordingAdapter;
    String? deviceId;
    var bootstrappedDevice = false;
    var recordingStarted = false;

    try {
      await Directory(outputDir).create(recursive: true);
      _reportProgress(
        request: request,
        platform: platform,
        stage: 'device',
        message: 'resolving verification target',
      );
      final resolvedDevice = await _ensureDeviceForPlatform(
        platform: platform,
        request: request,
      );
      deviceId = resolvedDevice.deviceId;
      bootstrappedDevice = resolvedDevice.bootstrapped;
      _reportProgress(
        request: request,
        platform: platform,
        stage: 'device',
        message: 'using deviceId=$deviceId bootstrapped=$bootstrappedDevice',
      );
      _reportProgress(
        request: request,
        platform: platform,
        stage: 'cleanup',
        message: 'clearing example local state',
      );
      await _cleanupExampleLocalState(
        platform: platform,
        deviceId: deviceId,
        workingDirectory: request.projectDir,
      );

      _reportProgress(
        request: request,
        platform: platform,
        stage: 'launch',
        message:
            'starting Flutter development session timeout=${request.launchTimeout.inSeconds}s',
      );
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
      final verifiedCommands = <String>['launch-app'];
      final warnings = <String>[];
      var autoScreenshotCount = 0;
      var exportedScreenshotCount = 0;
      _reportProgress(
        request: request,
        platform: platform,
        stage: 'launch',
        message: 'app ready baseUrl=${launchedApp.baseUrl}',
      );

      final initialRead = await _readAppWithRetry(
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
      final systemControl = await _verifySystemControlPlane(
        platform: platform,
        deviceId: deviceId,
        app: launchedApp,
        request: request,
        outputDir: outputDir,
      );
      verifiedCommands.add('read-system-capabilities');
      verifiedCommands.addAll(
        systemControl.verifiedActions.map(
          (action) => 'run-system-action:$action',
        ),
      );

      final taskTitle =
          'Platform sync conflict ${platform}_${_clock().toUtc().microsecondsSinceEpoch}';
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
        app: launchedApp,
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
      String? recordingArtifactRef;
      String? recordingOutputPath;
      int? recordingDurationMs;
      String? recordingKind;
      var recordingFallbackUsed = false;
      Object? recordingFallbackReason;
      activeRecordingAdapter = recordingAdapter;
      _reportProgress(
        request: request,
        platform: platform,
        stage: 'recording',
        message:
            'starting recording driver=${cockpitDemoRecordingDriverForPlatform(platform: platform, deviceId: deviceId)}',
      );
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
        if (!_shouldAllowHostRecordingPrerequisiteFailure(
          platform: platform,
          request: request,
          error: error,
        )) {
          rethrow;
        }
        recordingFallbackReason = error;
        warnings.add(
          'Host recording could not be started on this machine; a timeline recording will be synthesized from exported key-step screenshots: $error',
        );
      }
      final batchResult = await _runBatchWithRetry(
        CockpitRunBatchRequest(
          app: launchedApp,
          commands: _batchCommandsFromJson(
            buildSyncLabCreateTaskBatch(taskTitle: taskTitle, notes: taskNotes),
          ),
          defaultResultProfile: _artifactEvidenceProfile,
          failFast: true,
        ),
      );
      await _requireBatchSuccess(
        platform: platform,
        result: batchResult,
        expectedCount: 8,
        outputDir: outputDir,
      );
      autoScreenshotCount += _autoScreenshotCount(batchResult);
      exportedScreenshotCount += await _exportScreenshotArtifacts(
        platform: platform,
        result: batchResult,
        outputDir: outputDir,
      );
      verifiedCommands.add('run-batch');
      _reportProgress(
        request: request,
        platform: platform,
        stage: 'commands',
        message:
            'created sync task commands=${batchResult.summary.totalCount} autoScreenshots=$autoScreenshotCount exportedScreenshots=$exportedScreenshotCount',
      );
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
          recordingStarted = false;
          recordingArtifactRef = recordingStop.artifact?.relativePath;
          recordingOutputPath = await _copyRequiredArtifactToOutputDir(
            platform: platform,
            recordingResult: recordingStop,
            outputDir: outputDir,
          );
          recordingDurationMs = recordingStop.durationMs;
          recordingKind = recordingStop.recordingKind?.name;
        } on Object catch (error) {
          if (!_shouldAllowHostRecordingPrerequisiteFailure(
            platform: platform,
            request: request,
            error: error,
          )) {
            rethrow;
          }
          final timelineRecording = await _buildTimelineRecordingFallback(
            platform: platform,
            outputDir: outputDir,
            recordingName: recordingRequest.name,
          );
          if (timelineRecording == null) {
            rethrow;
          }
          recordingStarted = false;
          recordingFallbackUsed = true;
          recordingArtifactRef = timelineRecording.relativePath;
          recordingOutputPath = timelineRecording.outputPath;
          recordingDurationMs = timelineRecording.durationMs;
          recordingKind = timelineRecording.kind;
          verifiedCommands.add('stop-recording');
          verifiedCommands.add('timeline-recording-fallback');
          warnings.add(
            'Host recording could not be finalized on this machine; synthesized a timeline recording from exported key-step screenshots: $error',
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

      final postSaveRead = await _readAppWithRetry(
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
      final syncLabConflictBatchResult = await _runBatchWithRetry(
        CockpitRunBatchRequest(
          app: launchedApp,
          commands: _batchCommandsFromJson(buildSyncLabConflictSyncBatch()),
          defaultResultProfile: _artifactEvidenceProfile,
          failFast: true,
        ),
      );
      await _requireBatchSuccess(
        platform: platform,
        result: syncLabConflictBatchResult,
        expectedCount: 5,
        outputDir: outputDir,
      );
      autoScreenshotCount += _autoScreenshotCount(syncLabConflictBatchResult);
      exportedScreenshotCount += await _exportScreenshotArtifacts(
        platform: platform,
        result: syncLabConflictBatchResult,
        outputDir: outputDir,
      );
      _reportProgress(
        request: request,
        platform: platform,
        stage: 'commands',
        message:
            'simulated sync conflict autoScreenshots=$autoScreenshotCount exportedScreenshots=$exportedScreenshotCount',
      );
      final postConflictSyncIdleResult = await _waitIdle(
        CockpitWaitIdleRequest(
          app: launchedApp,
          quietWindow: const Duration(milliseconds: 160),
          timeout: const Duration(seconds: 5),
        ),
      );
      if (!postConflictSyncIdleResult.idle) {
        throw CockpitApplicationServiceException(
          code: 'waitIdleTimedOut',
          message: 'The example app did not settle after conflict sync.',
          details: <String, Object?>{
            'platform': platform,
            'durationMs': postConflictSyncIdleResult.durationMs,
            'timeoutMs': postConflictSyncIdleResult.timeoutMs,
          },
        );
      }
      final syncLabOpenConflictBatchResult = await _runBatchWithRetry(
        CockpitRunBatchRequest(
          app: launchedApp,
          commands: _batchCommandsFromJson(<Map<String, Object?>>[
            ...buildSyncLabOpenConflictBatch(taskTitle: taskTitle),
            buildSyncLabRevealConflictResolutionCommand(),
            buildSyncLabOpenConflictResolutionCommand(),
          ]),
          defaultResultProfile: _artifactEvidenceProfile,
          failFast: true,
        ),
      );
      await _requireBatchSuccess(
        platform: platform,
        result: syncLabOpenConflictBatchResult,
        expectedCount: 6,
        outputDir: outputDir,
      );
      autoScreenshotCount += _autoScreenshotCount(
        syncLabOpenConflictBatchResult,
      );
      exportedScreenshotCount += await _exportScreenshotArtifacts(
        platform: platform,
        result: syncLabOpenConflictBatchResult,
        outputDir: outputDir,
      );
      _reportProgress(
        request: request,
        platform: platform,
        stage: 'commands',
        message:
            'opened conflict workflow autoScreenshots=$autoScreenshotCount exportedScreenshots=$exportedScreenshotCount',
      );
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
      final revealKeepLocalResult = await _runRequiredCommand(
        app: launchedApp,
        command: _commandFromJson(
          buildSyncLabRevealKeepLocalResolutionCommand(),
        ),
        resultProfile: _artifactEvidenceProfile,
      );
      autoScreenshotCount += _autoScreenshotCountFromResult(
        revealKeepLocalResult,
      );
      exportedScreenshotCount += await _exportScreenshotArtifactsFromResult(
        platform: platform,
        result: revealKeepLocalResult,
        outputDir: outputDir,
      );
      final keepLocalResult = await _runRequiredCommand(
        app: launchedApp,
        command: _commandFromJson(buildSyncLabKeepLocalResolutionCommand()),
        resultProfile: _artifactEvidenceProfile,
      );
      autoScreenshotCount += _autoScreenshotCountFromResult(keepLocalResult);
      exportedScreenshotCount += await _exportScreenshotArtifactsFromResult(
        platform: platform,
        result: keepLocalResult,
        outputDir: outputDir,
      );
      final syncRecoveryBatchResult = await _runBatchWithRetry(
        CockpitRunBatchRequest(
          app: launchedApp,
          commands: _batchCommandsFromJson(buildSyncLabRecoverySyncBatch()),
          defaultResultProfile: _artifactEvidenceProfile,
          failFast: true,
        ),
      );
      await _requireBatchSuccess(
        platform: platform,
        result: syncRecoveryBatchResult,
        expectedCount: 7,
        outputDir: outputDir,
      );
      autoScreenshotCount += _autoScreenshotCount(syncRecoveryBatchResult);
      exportedScreenshotCount += await _exportScreenshotArtifacts(
        platform: platform,
        result: syncRecoveryBatchResult,
        outputDir: outputDir,
      );
      final syncRecoveryVerificationBatchResult = await _runBatchWithRetry(
        CockpitRunBatchRequest(
          app: launchedApp,
          commands: _batchCommandsFromJson(
            buildSyncLabRecoveryVerificationBatch(taskTitle: taskTitle),
          ),
          defaultResultProfile: _artifactEvidenceProfile,
          failFast: true,
        ),
      );
      await _requireBatchSuccess(
        platform: platform,
        result: syncRecoveryVerificationBatchResult,
        expectedCount: 5,
        outputDir: outputDir,
      );
      autoScreenshotCount += _autoScreenshotCount(
        syncRecoveryVerificationBatchResult,
      );
      exportedScreenshotCount += await _exportScreenshotArtifacts(
        platform: platform,
        result: syncRecoveryVerificationBatchResult,
        outputDir: outputDir,
      );
      final returnFromDetailResult = await _runRequiredCommand(
        app: launchedApp,
        command: CockpitCommand(
          commandId: 'verify-return-from-detail-after-recovery',
          commandType: CockpitCommandType.tap,
          locator: CockpitLocator(
            tooltip: 'Back',
            ancestor: CockpitLocator(route: '/detail'),
          ),
        ),
        resultProfile: _artifactEvidenceProfile,
      );
      autoScreenshotCount += _autoScreenshotCountFromResult(
        returnFromDetailResult,
      );
      exportedScreenshotCount += await _exportScreenshotArtifactsFromResult(
        platform: platform,
        result: returnFromDetailResult,
        outputDir: outputDir,
      );
      _reportProgress(
        request: request,
        platform: platform,
        stage: 'commands',
        message:
            'verified sync recovery autoScreenshots=$autoScreenshotCount exportedScreenshots=$exportedScreenshotCount',
      );
      if (autoScreenshotCount < cockpitDemoMinimumAutoScreenshotCount) {
        throw CockpitApplicationServiceException(
          code: 'autoScreenshotsMissing',
          message:
              'Verifier did not produce enough automatic key-operation screenshots.',
          details: <String, Object?>{
            'platform': platform,
            'autoScreenshotCount': autoScreenshotCount,
            'minimumAutoScreenshotCount': cockpitDemoMinimumAutoScreenshotCount,
          },
        );
      }
      if (exportedScreenshotCount < autoScreenshotCount) {
        throw CockpitApplicationServiceException(
          code: 'autoScreenshotArtifactsMissing',
          message:
              'Verifier produced automatic screenshots that were not exported to output artifacts.',
          details: <String, Object?>{
            'platform': platform,
            'autoScreenshotCount': autoScreenshotCount,
            'exportedScreenshotCount': exportedScreenshotCount,
          },
        );
      }
      verifiedCommands.add('sync_lab_conflict_recovery');
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
      _requireNonEmptyScreenshotArtifact(
        platform: platform,
        artifact: screenshotArtifact,
      );
      final screenshotOutputPath = await _exportScreenshotArtifact(
        platform: platform,
        artifact: screenshotArtifact,
        outputDir: outputDir,
      );
      verifiedCommands.add('capture-screenshot');
      _reportProgress(
        request: request,
        platform: platform,
        stage: 'artifacts',
        message:
            'exported screenshots=$exportedScreenshotCount explicitScreenshot=$screenshotOutputPath',
      );

      if (recordingFallbackReason != null) {
        final timelineRecording = await _buildTimelineRecordingFallback(
          platform: platform,
          outputDir: outputDir,
          recordingName: recordingRequest.name,
        );
        if (timelineRecording == null) {
          throw CockpitApplicationServiceException(
            code: 'recordingFallbackFailed',
            message:
                'Host recording failed and screenshot timeline fallback could not be produced.',
            details: <String, Object?>{
              'platform': platform,
              'reason': '$recordingFallbackReason',
              'outputDir': outputDir,
            },
          );
        }
        recordingFallbackUsed = true;
        recordingArtifactRef = timelineRecording.relativePath;
        recordingOutputPath = timelineRecording.outputPath;
        recordingDurationMs = timelineRecording.durationMs;
        recordingKind = timelineRecording.kind;
        verifiedCommands.add('timeline-recording-fallback');
        warnings.add(
          'Synthesized a timeline recording from exported key-step screenshots after host recording startup failed.',
        );
      }

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
      _reportProgress(
        request: request,
        platform: platform,
        stage: 'reload',
        message:
            'hot reload succeeded generation=${hotReloadResult.status.reloadGeneration}',
      );

      final postReloadRead = await _readAppWithRetry(
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
      _reportProgress(
        request: request,
        platform: platform,
        stage: 'reload',
        message:
            'hot restart succeeded generation=${hotRestartResult.status.reloadGeneration}',
      );
      final postRestartRead = await _readAppWithRetry(
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
        batchCommandCount:
            batchResult.summary.totalCount +
            syncLabConflictBatchResult.summary.totalCount +
            syncLabOpenConflictBatchResult.summary.totalCount +
            syncRecoveryBatchResult.summary.totalCount +
            syncRecoveryVerificationBatchResult.summary.totalCount,
        autoScreenshotCount: autoScreenshotCount,
        exportedScreenshotCount: exportedScreenshotCount,
        networkFailureCount: networkResult.summary.failureCount,
        runtimeErrorCount: errorsResult.errors.length,
        logLineCount: logsResult.lines.length,
        recordingArtifactRef: recordingArtifactRef,
        recordingOutputPath: recordingOutputPath,
        recordingDurationMs: recordingDurationMs,
        recordingKind: recordingKind,
        recordingDriver: _recordingDriverForVerification(
          platform: platform,
          deviceId: deviceId,
          fallbackUsed: recordingFallbackUsed,
        ),
        screenshotArtifactRef: screenshotArtifact.relativePath,
        screenshotOutputPath: screenshotOutputPath,
        screenshotByteLength: screenshotArtifact.byteLength,
        systemControlAdapter: systemControl.adapter,
        systemAvailableActions: systemControl.availableActions,
        systemVerifiedActions: systemControl.verifiedActions,
        systemSkippedActions: systemControl.skippedActions,
        verifiedCommands: verifiedCommands,
        warnings: warnings,
      );
    } on Object catch (error) {
      _reportProgress(
        request: request,
        platform: platform,
        stage: 'failed',
        message: '$error',
      );
      final serviceError = error is CockpitApplicationServiceException
          ? error
          : null;
      return CockpitDemoPlatformVerification(
        platform: platform,
        status: 'failed',
        deviceId: deviceId ?? platform,
        bootstrappedDevice: bootstrappedDevice,
        outputDir: outputDir,
        appJsonPath: appJsonPath,
        baseUrl: app?.baseUrl,
        failureCode: serviceError?.code ?? error.runtimeType.toString(),
        failureMessage: '$error',
        failureDetails: await _failureDetailsWithDiagnostics(
          serviceError?.details,
          app: app,
          errorMessage: '$error',
        ),
      );
    } finally {
      if (recordingStarted && activeRecordingAdapter != null) {
        try {
          await activeRecordingAdapter.stopRecording();
        } on Object {
          // Preserve the primary verification result and avoid shadowing it.
        }
      }
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

  void _reportProgress({
    required CockpitDemoPlatformVerificationRequest request,
    required String platform,
    required String stage,
    required String message,
  }) {
    request.progressSink?.call(
      CockpitDemoVerificationProgressEvent(
        platform: platform,
        stage: stage,
        message: message,
        timestamp: _clock().toUtc(),
      ),
    );
  }

  Future<_SystemControlVerification> _verifySystemControlPlane({
    required String platform,
    required String deviceId,
    required CockpitAppHandle app,
    required CockpitDemoPlatformVerificationRequest request,
    required String outputDir,
  }) async {
    _reportProgress(
      request: request,
      platform: platform,
      stage: 'system-control',
      message: 'reading system capability matrix',
    );
    final describe = await _describeSystemControl(
      CockpitSystemControlDescribeRequest(
        platform: platform,
        deviceId: deviceId,
        appId: app.platformAppId,
        processId: app.processId,
      ),
    );
    final profile = describe.profile;
    final availableActions = profile.availableActions
        .map((action) => action.name)
        .toList(growable: false);
    final verifiedActions = <String>[];
    final skippedActions = <String>[];

    Future<CockpitSystemControlActionResult> runAndRequireSuccess({
      required CockpitSystemControlAction action,
      Map<String, Object?> parameters = const <String, Object?>{},
      Duration timeout = const Duration(seconds: 15),
    }) async {
      final result = await _runSystemAction(
        CockpitSystemControlActionRequest(
          platform: platform,
          deviceId: deviceId,
          appId: app.platformAppId,
          processId: app.processId,
          action: action,
          parameters: parameters,
          timeout: timeout,
        ),
      );
      if (!result.success) {
        throw CockpitApplicationServiceException(
          code: 'systemControlActionFailed',
          message: 'System ${action.name} action failed during verification.',
          details: <String, Object?>{
            'platform': platform,
            'action': result.action.name,
            'errorCode': result.errorCode,
            'errorMessage': result.errorMessage,
            'availability': result.availability.name,
            'requires': result.requires,
            'limitations': result.limitations,
          },
        );
      }
      verifiedActions.add(action.name);
      return result;
    }

    Future<void> runOptionalProbe({
      required CockpitSystemControlAction action,
      Map<String, Object?> parameters = const <String, Object?>{},
      Duration timeout = const Duration(seconds: 15),
    }) async {
      final result = await _runSystemAction(
        CockpitSystemControlActionRequest(
          platform: platform,
          deviceId: deviceId,
          appId: app.platformAppId,
          processId: app.processId,
          action: action,
          parameters: parameters,
          timeout: timeout,
        ),
      );
      if (result.success) {
        verifiedActions.add(action.name);
        return;
      }
      if (!_shouldSkipOptionalExhaustiveSystemProbeFailure(
        platform: platform,
        action: action,
        result: result,
      )) {
        throw CockpitApplicationServiceException(
          code: 'systemControlActionFailed',
          message: 'System ${action.name} action failed during verification.',
          details: <String, Object?>{
            'platform': platform,
            'action': result.action.name,
            'errorCode': result.errorCode,
            'errorMessage': result.errorMessage,
            'availability': result.availability.name,
            'requires': result.requires,
            'limitations': result.limitations,
          },
        );
      }
      skippedActions.add(action.name);
      _reportProgress(
        request: request,
        platform: platform,
        stage: 'system-control',
        message:
            'optional ${action.name} skipped error=${result.errorCode ?? "unknown"}',
      );
    }

    if (profile.availableActions.contains(
      CockpitSystemControlAction.readSystemState,
    )) {
      await runAndRequireSuccess(
        action: CockpitSystemControlAction.readSystemState,
      );
    }

    if (profile.availableActions.contains(
      CockpitSystemControlAction.readProcessList,
    )) {
      await runAndRequireSuccess(
        action: CockpitSystemControlAction.readProcessList,
      );
    }

    if (platform == 'android') {
      if (profile.availableActions.contains(
        CockpitSystemControlAction.setNetworkSpeed,
      )) {
        await runAndRequireSuccess(
          action: CockpitSystemControlAction.setNetworkSpeed,
          parameters: const <String, Object?>{'networkSpeed': 'full'},
        );
      }
      if (profile.availableActions.contains(
        CockpitSystemControlAction.setNetworkDelay,
      )) {
        await runAndRequireSuccess(
          action: CockpitSystemControlAction.setNetworkDelay,
          parameters: const <String, Object?>{'networkDelay': 'none'},
        );
      }
    }

    if (platform == 'ios') {
      if (profile.availableActions.contains(
        CockpitSystemControlAction.setStatusBar,
      )) {
        await runAndRequireSuccess(
          action: CockpitSystemControlAction.setStatusBar,
          parameters: const <String, Object?>{
            'time': '09:41',
            'dataNetwork': 'wifi',
            'wifiMode': 'active',
            'wifiBars': 3,
            'batteryState': 'charged',
            'batteryLevel': 100,
          },
        );
      }
      if (profile.availableActions.contains(
        CockpitSystemControlAction.clearStatusBar,
      )) {
        await runAndRequireSuccess(
          action: CockpitSystemControlAction.clearStatusBar,
        );
      }
    }

    if ((platform == 'ios' || request.exhaustiveSystemControl) &&
        profile.availableActions.contains(
          CockpitSystemControlAction.setClipboard,
        ) &&
        profile.availableActions.contains(
          CockpitSystemControlAction.getClipboard,
        )) {
      final clipboardText =
          'flutter_cockpit_${platform}_${_clock().toUtc().microsecondsSinceEpoch}';
      await runAndRequireSuccess(
        action: CockpitSystemControlAction.setClipboard,
        parameters: <String, Object?>{'text': clipboardText},
      );

      final getResult = await _runSystemAction(
        CockpitSystemControlActionRequest(
          platform: platform,
          deviceId: deviceId,
          appId: app.platformAppId,
          processId: app.processId,
          action: CockpitSystemControlAction.getClipboard,
          timeout: const Duration(seconds: 15),
        ),
      );
      if (!getResult.success || (getResult.stdout ?? '') != clipboardText) {
        throw CockpitApplicationServiceException(
          code: 'systemControlActionFailed',
          message: 'System getClipboard action failed during verification.',
          details: <String, Object?>{
            'platform': platform,
            'action': getResult.action.name,
            'errorCode': getResult.errorCode,
            'errorMessage': getResult.errorMessage,
            'stdout': getResult.stdout,
          },
        );
      }
      verifiedActions.add(CockpitSystemControlAction.getClipboard.name);
    }
    if (request.exhaustiveSystemControl) {
      for (final entry in _buildExhaustiveSystemControlActions(
        platform: platform,
        outputDir: outputDir,
      )) {
        final action = entry.action;
        if (verifiedActions.contains(action.name)) continue;
        if (!profile.availableActions.contains(action)) continue;
        if (_isOptionalExhaustiveSystemProbe(
          platform: platform,
          action: action,
        )) {
          await runOptionalProbe(
            action: action,
            parameters: entry.parameters,
            timeout: entry.timeout,
          );
          continue;
        }
        await runAndRequireSuccess(
          action: action,
          parameters: entry.parameters,
          timeout: entry.timeout,
        );
      }
    }

    if (availableActions.isEmpty && platform != 'web') {
      throw CockpitApplicationServiceException(
        code: 'systemControlUnavailable',
        message: 'No system control actions were available for platform.',
        details: <String, Object?>{
          'platform': platform,
          'adapter': profile.adapter,
          'blockedActions': profile.blockedActions
              .map((action) => action.name)
              .toList(growable: false),
        },
      );
    }

    _reportProgress(
      request: request,
      platform: platform,
      stage: 'system-control',
      message:
          'adapter=${profile.adapter} available=${availableActions.length} verified=${verifiedActions.join(",")} optionalSkipped=${skippedActions.join(",")}',
    );
    return _SystemControlVerification(
      adapter: profile.adapter,
      availableActions: availableActions,
      verifiedActions: List<String>.unmodifiable(verifiedActions),
      skippedActions: List<String>.unmodifiable(skippedActions),
    );
  }

  bool _isOptionalExhaustiveSystemProbe({
    required String platform,
    required CockpitSystemControlAction action,
  }) {
    return platform == 'ios' &&
        (action == CockpitSystemControlAction.addMedia ||
            action == CockpitSystemControlAction.readSystemLogs);
  }

  bool _shouldSkipOptionalExhaustiveSystemProbeFailure({
    required String platform,
    required CockpitSystemControlAction action,
    required CockpitSystemControlActionResult result,
  }) {
    return _isOptionalExhaustiveSystemProbe(
          platform: platform,
          action: action,
        ) &&
        result.errorCode == 'systemActionTimedOut';
  }

  List<_SystemControlActionProbe> _buildExhaustiveSystemControlActions({
    required String platform,
    required String outputDir,
  }) {
    final tempRoot = Directory(p.join(outputDir, 'system-control-probes'))
      ..createSync(recursive: true);
    final pushSource = File(p.join(tempRoot.path, 'push.txt'))
      ..writeAsStringSync('push');
    final pulledDestination = p.join(tempRoot.path, 'pulled.txt');
    final mediaSource = File(p.join(tempRoot.path, 'media.png'))
      ..writeAsBytesSync(_minimalPngBytes, flush: true);
    final deviceProbePath = switch (platform) {
      'android' => '/sdcard/Download/flutter_cockpit_probe.txt',
      'ios' => 'Documents/flutter_cockpit_probe.txt',
      _ => p.join(tempRoot.path, 'device-probe.txt'),
    };
    if (platform != 'android' && platform != 'ios') {
      File(deviceProbePath).writeAsStringSync('device-probe');
    }
    return <_SystemControlActionProbe>[
      const _SystemControlActionProbe(
        CockpitSystemControlAction.readDeviceInfo,
      ),
      const _SystemControlActionProbe(
        CockpitSystemControlAction.readFocusState,
      ),
      const _SystemControlActionProbe(
        CockpitSystemControlAction.readSystemLogs,
      ),
      const _SystemControlActionProbe(CockpitSystemControlAction.readWindows),
      _SystemControlActionProbe(
        CockpitSystemControlAction.pushFile,
        parameters: <String, Object?>{
          'sourcePath': pushSource.path,
          'destinationPath': deviceProbePath,
        },
      ),
      _SystemControlActionProbe(
        CockpitSystemControlAction.pullFile,
        parameters: <String, Object?>{
          'sourcePath': deviceProbePath,
          'destinationPath': pulledDestination,
        },
      ),
      _SystemControlActionProbe(
        CockpitSystemControlAction.addMedia,
        parameters: <String, Object?>{'sourcePath': mediaSource.path},
        timeout: platform == 'ios'
            ? const Duration(seconds: 60)
            : const Duration(seconds: 15),
      ),
      _SystemControlActionProbe(
        CockpitSystemControlAction.runShell,
        parameters: <String, Object?>{
          'command': _systemControlProbeShellCommand(platform),
        },
      ),
    ];
  }

  List<String> _systemControlProbeShellCommand(String platform) {
    return switch (platform) {
      'windows' => const <String>['cmd', '/c', 'echo', 'cockpit-exhaustive'],
      _ => const <String>['echo', 'cockpit-exhaustive'],
    };
  }

  Future<_ResolvedDevice> _ensureDeviceForPlatform({
    required String platform,
    required CockpitDemoPlatformVerificationRequest request,
  }) async {
    final available = await _probeDevices();
    final existing = cockpitDemoMatchingVerificationDevice(
      devices: available,
      platform: platform,
    );
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
        final simulator = cockpitDemoSelectIosSimulator(simulators);
        if (!simulator.booted) {
          await _runProcess('xcrun', <String>[
            'simctl',
            'boot',
            simulator.udid,
          ], workingDirectory: request.projectDir);
        }
        await _runProcess('xcrun', <String>[
          'simctl',
          'bootstatus',
          simulator.udid,
          '-b',
        ], workingDirectory: request.projectDir);
        return _waitForDevice(
          platform: platform,
          timeout: request.deviceTimeout,
        );
      case 'android':
        await _runProcess(
          cockpitFlutterExecutable(isWindows: _isWindows),
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
      final device = cockpitDemoMatchingVerificationDevice(
        devices: devices,
        platform: platform,
      );
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

  Future<void> _requireBatchSuccess({
    required String platform,
    required CockpitRunBatchResult result,
    required int expectedCount,
    required String outputDir,
  }) async {
    if (result.summary.failureCount == 0 &&
        !result.summary.stoppedEarly &&
        result.summary.totalCount == expectedCount &&
        result.results.every((entry) => entry.command.success)) {
      return;
    }
    final failedResult = result.results.firstWhere(
      (entry) => !entry.command.success,
      orElse: () => throw CockpitApplicationServiceException(
        code: 'invalidBatchSummary',
        message: 'Batch verification summary did not match expectations.',
        details: <String, Object?>{
          'platform': platform,
          'expectedCount': expectedCount,
          'totalCount': result.summary.totalCount,
          'failureCount': result.summary.failureCount,
          'stoppedEarly': result.summary.stoppedEarly,
          'completedCommands': result.results
              .map((entry) => entry.command.commandId)
              .toList(growable: false),
        },
      ),
    );
    await _preserveFailureScreenshotArtifacts(
      platform: platform,
      results: result.results,
      outputDir: outputDir,
    );
    throw CockpitApplicationServiceException(
      code: 'exampleBatchFailed',
      message: 'A required example batch command failed.',
      details: _failedCommandDetails(
        platform: platform,
        expectedCount: expectedCount,
        totalCount: result.summary.totalCount,
        failureCount: result.summary.failureCount,
        stoppedEarly: result.summary.stoppedEarly,
        result: failedResult,
        completedResults: result.results,
      ),
    );
  }

  Future<void> _preserveFailureScreenshotArtifacts({
    required String platform,
    required List<CockpitExecuteRemoteCommandResult> results,
    required String outputDir,
  }) async {
    for (final result in results) {
      for (final artifact in result.artifacts) {
        if (artifact.role != 'screenshot') {
          continue;
        }
        try {
          await _exportScreenshotArtifact(
            platform: platform,
            artifact: artifact,
            outputDir: outputDir,
          );
        } on Object {
          // Preserve the original verifier failure; diagnostic export is best effort.
        }
      }
    }
  }

  List<CockpitRunBatchCommand> _batchCommandsFromJson(
    List<Map<String, Object?>> commands,
  ) {
    return commands
        .map(
          (command) =>
              CockpitRunBatchCommand(command: _commandFromJson(command)),
        )
        .toList(growable: false);
  }

  int _autoScreenshotCount(CockpitRunBatchResult result) {
    return result.results.fold<int>(0, (count, entry) {
      return count + _autoScreenshotCountFromResult(entry);
    });
  }

  int _autoScreenshotCountFromResult(CockpitExecuteRemoteCommandResult result) {
    final commandType = CockpitCommandType.fromJson(result.command.commandType);
    if (!cockpitCommandTypeIsAiEvidenceKeyOperation(commandType)) {
      return 0;
    }
    final screenshotCount = result.artifacts
        .where((artifact) => artifact.role == 'screenshot')
        .length;
    if (screenshotCount == 0) {
      throw CockpitApplicationServiceException(
        code: 'autoScreenshotArtifactMissing',
        message:
            'AI evidence key operation did not produce an automatic screenshot artifact.',
        details: <String, Object?>{
          'commandId': result.command.commandId,
          'commandType': result.command.commandType,
        },
      );
    }
    return screenshotCount;
  }

  Future<int> _exportScreenshotArtifacts({
    required String platform,
    required CockpitRunBatchResult result,
    required String outputDir,
  }) async {
    var exportedCount = 0;
    for (final entry in result.results) {
      exportedCount += await _exportScreenshotArtifactsFromResult(
        platform: platform,
        result: entry,
        outputDir: outputDir,
      );
    }
    return exportedCount;
  }

  Future<int> _exportScreenshotArtifactsFromResult({
    required String platform,
    required CockpitExecuteRemoteCommandResult result,
    required String outputDir,
  }) async {
    final commandType = CockpitCommandType.fromJson(result.command.commandType);
    if (!cockpitCommandTypeIsAiEvidenceKeyOperation(commandType)) {
      return 0;
    }
    final screenshotArtifacts = result.artifacts
        .where((artifact) => artifact.role == 'screenshot')
        .toList(growable: false);
    if (screenshotArtifacts.isEmpty) {
      throw CockpitApplicationServiceException(
        code: 'autoScreenshotArtifactMissing',
        message:
            'AI evidence key operation did not include an exportable screenshot artifact.',
        details: <String, Object?>{
          'platform': platform,
          'commandId': result.command.commandId,
          'commandType': result.command.commandType,
        },
      );
    }
    var exportedCount = 0;
    for (final artifact in screenshotArtifacts) {
      await _exportScreenshotArtifact(
        platform: platform,
        artifact: artifact,
        outputDir: outputDir,
      );
      exportedCount += 1;
    }
    return exportedCount;
  }

  CockpitCommand _commandFromJson(Map<String, Object?> command) {
    return CockpitCommand.fromJson(command);
  }

  Future<CockpitExecuteRemoteCommandResult> _runRequiredCommand({
    required CockpitAppHandle app,
    required CockpitCommand command,
    CockpitInteractiveResultProfile resultProfile =
        const CockpitInteractiveResultProfile.standard(),
  }) async {
    final result = await _runCommandWithRetry(
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
        details: _failedCommandDetails(result: result),
      );
    }
    return result;
  }

  Map<String, Object?> _failedCommandDetails({
    String? platform,
    int? expectedCount,
    int? totalCount,
    int? failureCount,
    bool? stoppedEarly,
    required CockpitExecuteRemoteCommandResult result,
    List<CockpitExecuteRemoteCommandResult> completedResults =
        const <CockpitExecuteRemoteCommandResult>[],
  }) {
    final command = result.command;
    final details = <String, Object?>{
      'platform': ?platform,
      'expectedCount': ?expectedCount,
      'totalCount': ?totalCount,
      'failureCount': ?failureCount,
      'stoppedEarly': ?stoppedEarly,
      'commandId': command.commandId,
      'commandType': command.commandType,
      'recommendedNextStep': result.recommendedNextStep,
      'selectedPlane': result.selectedPlane.name,
    };
    if (command.error != null) {
      details['error'] = _compactJsonValue(command.error!.toJson());
    }
    if (command.locatorResolution != null) {
      details['locatorResolution'] = _compactJsonValue(
        command.locatorResolution!.toJson(),
      );
    }
    if (result.fallbackTrail.isNotEmpty) {
      details['fallbackTrail'] = result.fallbackTrail
          .map((planeKind) => planeKind.name)
          .toList();
    }
    if (result.whatChanged != null) {
      details['whatChanged'] = _compactString(result.whatChanged!);
    }
    if (result.whatMatters != null) {
      details['whatMatters'] = _compactString(result.whatMatters!);
    }
    if (result.uiSummary != null) {
      details['uiSummary'] = _compactUiSummary(result.uiSummary!);
    }
    if (result.diagnostics != null) {
      details['diagnostics'] = _compactJsonValue(result.diagnostics);
    }
    if (result.snapshotRef != null) {
      details['snapshotRef'] = result.snapshotRef;
    }
    if (completedResults.isNotEmpty) {
      details['completedCommandTrail'] = completedResults
          .map(_compactCompletedCommand)
          .toList(growable: false);
    }
    return details;
  }

  Map<String, Object?> _compactCompletedCommand(
    CockpitExecuteRemoteCommandResult result,
  ) {
    final command = result.command;
    final snapshot = result.snapshot;
    return <String, Object?>{
      'commandId': command.commandId,
      'commandType': command.commandType,
      'success': command.success,
      'durationMs': command.durationMs,
      if (snapshot?.routeName != null) 'routeName': snapshot!.routeName,
      if (command.locatorResolution != null)
        'locatorResolution': _compactJsonValue(
          command.locatorResolution!.toJson(),
        ),
      if (command.error != null)
        'error': _compactJsonValue(command.error!.toJson()),
      if (result.whatChanged != null)
        'whatChanged': _compactString(result.whatChanged!),
      if (result.whatMatters != null)
        'whatMatters': _compactString(result.whatMatters!),
      if (result.snapshotRef != null) 'snapshotRef': result.snapshotRef,
      if (result.artifacts.isNotEmpty)
        'artifacts': result.artifacts
            .map(
              (artifact) => <String, Object?>{
                'role': artifact.role,
                'relativePath': artifact.relativePath,
              },
            )
            .toList(growable: false),
    };
  }

  Map<String, Object?> _compactUiSummary(
    CockpitInteractiveSnapshotSummary summary,
  ) {
    return <String, Object?>{
      if (summary.routeName != null) 'routeName': summary.routeName,
      'diagnosticLevel': summary.diagnosticLevel,
      'truncated': summary.truncated,
      'visibleTargetCount': summary.visibleTargetCount,
      'targetsWithCockpitIdCount': summary.targetsWithCockpitIdCount,
      'targetsWithTextCount': summary.targetsWithTextCount,
      'networkFailureCount': summary.networkFailureCount,
      'runtimeErrorCount': summary.runtimeErrorCount,
      'accessibilityTargetCount': summary.accessibilityTargetCount,
      'textPreviews': summary.textPreviews.take(8).toList(growable: false),
    };
  }

  Object? _compactJsonValue(Object? value, {int depth = 0}) {
    if (value == null || value is num || value is bool) {
      return value;
    }
    if (value is String) {
      return _compactString(value);
    }
    if (depth >= 3) {
      return '<omitted>';
    }
    if (value is Map) {
      final entries = value.entries.take(8);
      return <String, Object?>{
        for (final entry in entries)
          '${entry.key}': _compactJsonValue(entry.value, depth: depth + 1),
      };
    }
    if (value is Iterable) {
      return value
          .take(8)
          .map((entry) => _compactJsonValue(entry, depth: depth + 1))
          .toList(growable: false);
    }
    return _compactString('$value');
  }

  String _compactString(String value) {
    const maxLength = 512;
    if (value.length <= maxLength) {
      return value;
    }
    return '${value.substring(0, maxLength)}...';
  }

  Future<CockpitExecuteRemoteCommandResult> _runCommandWithRetry(
    CockpitRunCommandRequest request,
  ) async {
    for (var attempt = 0; attempt < 2; attempt += 1) {
      try {
        return await _runCommand(request);
      } on CockpitApplicationServiceException catch (error) {
        final shouldRetry =
            error.code == 'remoteUnavailable' && attempt + 1 < 2;
        if (!shouldRetry) {
          rethrow;
        }
        await _wait(Duration(milliseconds: 400 * (attempt + 1)));
      }
    }
    throw StateError('Unreachable command retry state.');
  }

  Future<CockpitReadAppResult> _readAppWithRetry(
    CockpitReadAppRequest request,
  ) async {
    for (var attempt = 0; attempt < 5; attempt += 1) {
      try {
        return await _readApp(request);
      } on CockpitApplicationServiceException catch (error) {
        final shouldRetry =
            error.code == 'remoteUnavailable' && attempt + 1 < 5;
        if (!shouldRetry) {
          rethrow;
        }
        await _wait(Duration(milliseconds: 400 * (attempt + 1)));
      }
    }
    throw StateError('Unreachable read-app retry state.');
  }

  Future<CockpitRunBatchResult> _runBatchWithRetry(
    CockpitRunBatchRequest request,
  ) async {
    return _runBatch(request);
  }

  Future<String> _copyRequiredArtifactToOutputDir({
    required String platform,
    required CockpitRecordingResult recordingResult,
    required String outputDir,
  }) async {
    final artifact = recordingResult.artifact;
    final relativePath = artifact?.relativePath;
    if (relativePath == null || relativePath.isEmpty) {
      throw CockpitApplicationServiceException(
        code: 'recordingArtifactUnavailable',
        message: 'Recording completed without an artifact reference.',
        details: <String, Object?>{'platform': platform},
      );
    }
    final destinationPath = cockpitDemoResolveArtifactOutputPath(
      outputDir: outputDir,
      relativePath: relativePath,
    );
    final destinationFile = File(destinationPath);
    await destinationFile.parent.create(recursive: true);

    final bytes = recordingResult.bytes;
    if (bytes != null) {
      if (bytes.isEmpty) {
        throw CockpitApplicationServiceException(
          code: 'recordingArtifactEmpty',
          message: 'Recording artifact bytes are empty.',
          details: <String, Object?>{
            'platform': platform,
            'artifactPath': relativePath,
            'byteLength': 0,
          },
        );
      }
      await destinationFile.writeAsBytes(bytes, flush: true);
      return p.normalize(destinationFile.path);
    }

    final sourcePath = recordingResult.sourceFilePath;
    if (sourcePath == null || sourcePath.isEmpty) {
      throw CockpitApplicationServiceException(
        code: 'recordingArtifactUnavailable',
        message: 'Recording completed without a downloadable artifact file.',
        details: <String, Object?>{
          'platform': platform,
          'artifactPath': relativePath,
        },
      );
    }
    final sourceFile = File(sourcePath);
    if (!sourceFile.existsSync()) {
      throw CockpitApplicationServiceException(
        code: 'recordingArtifactUnavailable',
        message: 'Recording artifact source file does not exist.',
        details: <String, Object?>{
          'platform': platform,
          'artifactPath': relativePath,
          'sourcePath': sourcePath,
        },
      );
    }
    final byteLength = sourceFile.lengthSync();
    if (byteLength <= 0) {
      throw CockpitApplicationServiceException(
        code: 'recordingArtifactEmpty',
        message: 'Recording artifact source file is empty.',
        details: <String, Object?>{
          'platform': platform,
          'artifactPath': relativePath,
          'sourcePath': sourcePath,
          'byteLength': byteLength,
        },
      );
    }
    await sourceFile.copy(destinationFile.path);
    return p.normalize(destinationFile.path);
  }

  Future<_TimelineRecordingFallback?> _buildTimelineRecordingFallback({
    required String platform,
    required String outputDir,
    required String recordingName,
  }) async {
    if (!_canBuildTimelineRecordingFallback(platform)) {
      return null;
    }
    final screenshotsDir = Directory(p.join(outputDir, 'screenshots'));
    if (!screenshotsDir.existsSync()) {
      return null;
    }
    final screenshots =
        screenshotsDir
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => p.extension(file.path).toLowerCase() == '.png')
            .toList(growable: false)
          ..sort((left, right) => left.path.compareTo(right.path));
    if (screenshots.isEmpty) {
      return null;
    }

    final workingDirectory = await Directory.systemTemp.createTemp(
      'cockpit_demo_timeline_recording_',
    );
    try {
      final framesDirectory = Directory(p.join(workingDirectory.path, 'frames'))
        ..createSync(recursive: true);
      var frameIndex = 0;
      for (final screenshot in screenshots) {
        for (var copyIndex = 0; copyIndex < 8; copyIndex += 1) {
          final framePath = p.join(
            framesDirectory.path,
            'frame_${frameIndex.toString().padLeft(4, '0')}.png',
          );
          await screenshot.copy(framePath);
          frameIndex += 1;
        }
      }
      if (frameIndex == 0) {
        return null;
      }

      final relativePath =
          'recordings/${_sanitizeTimelineRecordingName(recordingName)}_timeline_fallback.mp4';
      final outputPath = cockpitDemoResolveArtifactOutputPath(
        outputDir: outputDir,
        relativePath: relativePath,
      );
      final outputFile = File(outputPath);
      await outputFile.parent.create(recursive: true);
      if (outputFile.existsSync()) {
        outputFile.deleteSync();
      }

      final result = await _timelineRecordingProcessRunner('ffmpeg', <String>[
        '-y',
        '-framerate',
        '8',
        '-i',
        p.join(framesDirectory.path, 'frame_%04d.png'),
        '-vf',
        'scale=trunc(iw/2)*2:trunc(ih/2)*2,format=yuv420p',
        '-c:v',
        'libx264',
        '-movflags',
        '+faststart',
        outputFile.path,
      ]);
      if (result.exitCode != 0 ||
          !outputFile.existsSync() ||
          outputFile.lengthSync() <= 0) {
        return null;
      }

      return _TimelineRecordingFallback(
        relativePath: relativePath,
        outputPath: p.normalize(outputFile.path),
        durationMs: screenshots.length * 1000,
        kind: 'timelineScreenshotFallback',
      );
    } finally {
      if (workingDirectory.existsSync()) {
        await workingDirectory.delete(recursive: true);
      }
    }
  }

  bool _canBuildTimelineRecordingFallback(String platform) {
    return switch (platform) {
      'linux' || 'macos' || 'web' || 'windows' => true,
      _ => false,
    };
  }

  String _sanitizeTimelineRecordingName(String value) {
    final sanitized = value
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return sanitized.isEmpty ? 'recording' : sanitized;
  }

  Future<String> _exportScreenshotArtifact({
    required String platform,
    required CockpitInteractiveArtifactDescriptor artifact,
    required String outputDir,
  }) async {
    _requireNonEmptyScreenshotArtifact(platform: platform, artifact: artifact);
    final sourcePath = artifact.sourcePath;
    if (sourcePath == null || sourcePath.isEmpty) {
      throw CockpitApplicationServiceException(
        code: 'screenshotArtifactUnavailable',
        message: 'Screenshot evidence did not include a source file path.',
        details: <String, Object?>{
          'platform': platform,
          'artifactPath': artifact.relativePath,
          'byteLength': ?artifact.byteLength,
        },
      );
    }

    final sourceFile = File(sourcePath);
    if (!sourceFile.existsSync()) {
      throw CockpitApplicationServiceException(
        code: 'screenshotArtifactUnavailable',
        message: 'Screenshot artifact source file does not exist.',
        details: <String, Object?>{
          'platform': platform,
          'artifactPath': artifact.relativePath,
          'sourcePath': sourcePath,
        },
      );
    }
    final byteLength = sourceFile.lengthSync();
    if (byteLength <= 0) {
      throw CockpitApplicationServiceException(
        code: 'screenshotArtifactEmpty',
        message: 'Screenshot artifact source file is empty.',
        details: <String, Object?>{
          'platform': platform,
          'artifactPath': artifact.relativePath,
          'sourcePath': sourcePath,
          'byteLength': byteLength,
        },
      );
    }

    final destinationPath = cockpitDemoResolveArtifactOutputPath(
      outputDir: outputDir,
      relativePath: artifact.relativePath,
    );
    final destinationFile = File(destinationPath);
    await destinationFile.parent.create(recursive: true);
    await sourceFile.copy(destinationFile.path);
    return p.normalize(destinationFile.path);
  }

  void _requireNonEmptyScreenshotArtifact({
    required String platform,
    required CockpitInteractiveArtifactDescriptor artifact,
  }) {
    final byteLength = artifact.byteLength;
    if (byteLength != null && byteLength > 0) {
      return;
    }
    final sourcePath = artifact.sourcePath;
    if (sourcePath != null && sourcePath.isNotEmpty) {
      try {
        final file = File(sourcePath);
        if (file.existsSync() && file.lengthSync() > 0) {
          return;
        }
      } on Object {
        // Fall through to the structured verifier failure below.
      }
    }
    throw CockpitApplicationServiceException(
      code: 'screenshotArtifactEmpty',
      message: 'Screenshot command did not produce non-empty evidence.',
      details: <String, Object?>{
        'platform': platform,
        'artifactPath': artifact.relativePath,
        'byteLength': ?byteLength,
        'sourcePath': ?sourcePath,
      },
    );
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
    return cockpitDemoCleanupAndroidPortForward(
      deviceId: deviceId,
      sessionPort: sessionPort,
      workingDirectory: workingDirectory,
      processRunner: _processRunner,
    );
  }

  Future<void> _cleanupExampleLocalState({
    required String platform,
    required String? deviceId,
    required String workingDirectory,
  }) async {
    return cockpitDemoCleanupExampleLocalState(
      platform: platform,
      deviceId: deviceId,
      workingDirectory: workingDirectory,
      processRunner: _processRunner,
    );
  }

  Future<Map<String, Object?>> _failureDetailsWithDiagnostics(
    Map<String, Object?>? details, {
    CockpitAppHandle? app,
    String? errorMessage,
  }) async {
    final merged = <String, Object?>{...?details};
    final appLogPath = app?.supervisorLogPath;
    if (appLogPath != null &&
        appLogPath.isNotEmpty &&
        merged['supervisorLogPath'] is! String) {
      merged['supervisorLogPath'] = appLogPath;
    }
    final messageLogPath = _extractSupervisorLogPath(errorMessage);
    if (messageLogPath != null &&
        messageLogPath.isNotEmpty &&
        merged['supervisorLogPath'] is! String) {
      merged['supervisorLogPath'] = messageLogPath;
    }
    final logPath = merged['supervisorLogPath'];
    if (logPath is String && logPath.isNotEmpty) {
      final tail = await _readTextTail(logPath, maxLines: 80);
      if (tail != null && tail.isNotEmpty) {
        merged['supervisorLogTail'] = tail;
      }
    }
    return merged;
  }

  String? _extractSupervisorLogPath(String? message) {
    if (message == null || message.isEmpty) {
      return null;
    }
    final marker = 'supervisorLogPath:';
    final markerIndex = message.indexOf(marker);
    if (markerIndex < 0) {
      return null;
    }
    final valueStart = markerIndex + marker.length;
    final rest = message.substring(valueStart).trimLeft();
    if (rest.isEmpty) {
      return null;
    }
    final delimiters = <String>[
      ', supervisorLogTail:',
      ', lastSupervisorStatus:',
      '}',
      '\n',
      '\r',
    ];
    var valueEnd = rest.length;
    for (final delimiter in delimiters) {
      final delimiterIndex = rest.indexOf(delimiter);
      if (delimiterIndex >= 0 && delimiterIndex < valueEnd) {
        valueEnd = delimiterIndex;
      }
    }
    final extracted = _trimWrappingQuotes(rest.substring(0, valueEnd).trim());
    return extracted.isEmpty ? null : extracted;
  }

  String _trimWrappingQuotes(String value) {
    var trimmed = value;
    while (trimmed.isNotEmpty &&
        (trimmed.startsWith('`') ||
            trimmed.startsWith('"') ||
            trimmed.startsWith("'"))) {
      trimmed = trimmed.substring(1).trimLeft();
    }
    while (trimmed.isNotEmpty &&
        (trimmed.endsWith('`') ||
            trimmed.endsWith('"') ||
            trimmed.endsWith("'"))) {
      trimmed = trimmed.substring(0, trimmed.length - 1).trimRight();
    }
    return trimmed;
  }

  Future<String?> _readTextTail(String path, {required int maxLines}) async {
    try {
      final lines = await File(path).readAsLines();
      final tail = lines.length <= maxLines
          ? lines
          : lines.sublist(lines.length - maxLines);
      return tail.join('\n');
    } on Object {
      return null;
    }
  }
}

const String _iosExampleBundleId = 'com.iota9star.fluttercockpit.cockpitdemo';
const String _macosExampleBundleId = 'dev.cockpit.cockpitDemo';
const String _androidExampleApplicationId = 'dev.cockpit.cockpit_demo';

const List<String> _iosExampleBundleIds = <String>[
  _iosExampleBundleId,
  // Keep cleanup compatible with containers created before the iOS bundle id
  // diverged from the macOS bundle id.
  _macosExampleBundleId,
];

Future<List<CockpitDemoHostDevice>> cockpitDemoProbeHostDevices({
  CockpitDemoProcessRunner processRunner = Process.run,
  String? workingDirectory,
  bool? isWindows,
}) async {
  final result = await processRunner(
    cockpitFlutterExecutable(isWindows: isWindows),
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
        (device) =>
            CockpitDemoHostDevice.fromJson(Map<String, Object?>.from(device)),
      )
      .toList(growable: false);
}

Future<List<CockpitDemoIosSimulator>> cockpitDemoListIosSimulators({
  CockpitDemoProcessRunner processRunner = Process.run,
  String? workingDirectory,
}) async {
  final result = await processRunner('xcrun', const <String>[
    'simctl',
    'list',
    'devices',
    '--json',
  ], workingDirectory: workingDirectory);
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

String cockpitDemoNormalizeVerificationPlatform(String platform) {
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

CockpitDemoHostDevice? cockpitDemoMatchingVerificationDevice({
  required List<CockpitDemoHostDevice> devices,
  required String platform,
}) {
  for (final device in devices) {
    if (!device.supported || device.platform != platform) {
      continue;
    }
    if (cockpitDemoIsDesktopVerificationPlatform(platform) || device.emulator) {
      return device;
    }
  }
  return null;
}

CockpitDemoIosSimulator cockpitDemoSelectIosSimulator(
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

bool cockpitDemoIsDesktopVerificationPlatform(String platform) {
  return switch (platform) {
    'linux' || 'macos' || 'web' || 'windows' => true,
    _ => false,
  };
}

Future<void> cockpitDemoCleanupAndroidPortForward({
  required String deviceId,
  required int sessionPort,
  required String workingDirectory,
  required CockpitDemoProcessRunner processRunner,
}) async {
  try {
    await processRunner('adb', <String>[
      '-s',
      deviceId,
      'forward',
      '--remove',
      'tcp:$sessionPort',
    ], workingDirectory: workingDirectory);
  } on Object {
    // Best effort cleanup to avoid stale forwards across verification runs.
  }
}

Future<void> cockpitDemoCleanupExampleLocalState({
  required String platform,
  required String? deviceId,
  required String workingDirectory,
  required CockpitDemoProcessRunner processRunner,
}) async {
  try {
    switch (platform) {
      case 'android':
        if (deviceId == null || deviceId.isEmpty) {
          return;
        }
        await processRunner('adb', <String>[
          '-s',
          deviceId,
          'shell',
          'am',
          'force-stop',
          _androidExampleApplicationId,
        ], workingDirectory: workingDirectory);
        await processRunner('adb', <String>[
          '-s',
          deviceId,
          'shell',
          'pm',
          'clear',
          _androidExampleApplicationId,
        ], workingDirectory: workingDirectory);
        await processRunner('adb', <String>[
          '-s',
          deviceId,
          'shell',
          'run-as',
          _androidExampleApplicationId,
          'rm',
          '-f',
          'app_flutter/cockpit_demo.sqlite',
          'app_flutter/cockpit_demo.sqlite-shm',
          'app_flutter/cockpit_demo.sqlite-wal',
        ], workingDirectory: workingDirectory);
      case 'ios':
        if (deviceId == null || deviceId.isEmpty) {
          return;
        }
        for (final bundleId in _iosExampleBundleIds) {
          final containerResult = await processRunner('xcrun', <String>[
            'simctl',
            'get_app_container',
            deviceId,
            bundleId,
            'data',
          ], workingDirectory: workingDirectory);
          if (containerResult.exitCode != 0) {
            continue;
          }
          final containerPath = '${containerResult.stdout}'.trim();
          if (containerPath.isEmpty) {
            continue;
          }
          await _deleteExampleDatabaseArtifacts(
            p.join(containerPath, 'Documents'),
          );
        }
      case 'macos':
        final home = Platform.environment['HOME'];
        if (home == null || home.isEmpty) {
          return;
        }
        await _deleteExampleDatabaseArtifacts(
          p.join(
            home,
            'Library',
            'Containers',
            _macosExampleBundleId,
            'Data',
            'Documents',
          ),
        );
      case 'linux':
      case 'web':
      case 'windows':
        return;
    }
  } on Object {
    // Verification should stay best-effort when cleanup cannot run.
  }
}

Future<void> _deleteExampleDatabaseArtifacts(String directoryPath) async {
  final filenames = <String>[
    'cockpit_demo.sqlite',
    'cockpit_demo.sqlite-shm',
    'cockpit_demo.sqlite-wal',
  ];
  for (final filename in filenames) {
    final file = File(p.join(directoryPath, filename));
    if (!file.existsSync()) {
      continue;
    }
    await file.delete();
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
  final snapshot = (await _readSnapshotDetailedWithRetry(
    resolved.client,
    options: CockpitSnapshotOptions(
      includeNetworkActivity: true,
      maxNetworkEntries: request.maxEntries <= 0 ? 8 : request.maxEntries,
      networkQuery: request.networkQuery,
    ),
  )).snapshot;
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

  final maxEndpointSummaries = request.maxEndpointSummaries <= 0
      ? 8
      : request.maxEndpointSummaries;
  final endpointSummaries =
      network.endpointSummaries.length > maxEndpointSummaries
      ? network.endpointSummaries.sublist(0, maxEndpointSummaries)
      : network.endpointSummaries;
  final recentFailures = network.entries
      .where((entry) => entry.isFailure)
      .toList(growable: false);

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
    endpointSummaries: List<CockpitNetworkEndpointSummary>.unmodifiable(
      endpointSummaries,
    ),
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
  final snapshot = (await _readSnapshotDetailedWithRetry(
    resolved.client,
    options: CockpitSnapshotOptions(
      profile: CockpitSnapshotProfile.investigate,
      includeRuntimeActivity: true,
      maxRuntimeEntries: request.maxErrors <= 0 ? 20 : request.maxErrors,
      runtimeQuery: const CockpitRuntimeQuery(onlyErrors: true),
    ),
  )).snapshot;
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
    final snapshot = (await _readSnapshotDetailedWithRetry(
      resolved.client,
      options: CockpitSnapshotOptions(
        includeRuntimeActivity: true,
        maxRuntimeEntries: maxLines,
      ),
    )).snapshot;
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
    final visibleLines = truncated
        ? lines.sublist(lines.length - maxLines)
        : lines;
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

Future<CockpitRemoteSnapshotResponse> _readSnapshotDetailedWithRetry(
  CockpitRemoteSessionClient client, {
  required CockpitSnapshotOptions options,
}) async {
  const maxAttempts = 5;
  for (var attempt = 0; attempt < maxAttempts; attempt += 1) {
    try {
      return await client.readSnapshotDetailed(options: options);
    } on CockpitApplicationServiceException catch (error) {
      final shouldRetry =
          attempt + 1 < maxAttempts &&
          (error.code == 'remoteUnavailable' ||
              (error.code == 'serverError' &&
                  error.message.contains('FlutterCockpitRoot is not mounted')));
      if (!shouldRetry) {
        rethrow;
      }
      await Future<void>.delayed(Duration(milliseconds: 400 * (attempt + 1)));
    }
  }
  throw StateError('Unreachable snapshot retry state.');
}

CockpitRecordingAdapter? cockpitDemoResolveRecordingAdapter({
  required String platform,
  required String deviceId,
  required CockpitAppHandle app,
  required CockpitRemoteSessionClient client,
  required CockpitRecordingRequest recording,
}) {
  return const CockpitRecordingStrategyResolver().resolve(
    platform: platform,
    recording: recording,
    client: client,
    sessionHandle: app.remoteSession,
    androidDeviceId: platform == 'android' ? deviceId : null,
    iosDeviceId: platform == 'ios' ? deviceId : null,
    platformAppId:
        app.platformAppId ?? app.remoteSession?.effectivePlatformAppId,
    processId: app.processId ?? app.remoteSession?.processId,
  );
}

String cockpitDemoRecordingDriverForPlatform({
  required String platform,
  required String? deviceId,
}) {
  return switch (platform) {
    'android' => 'adb',
    'ios' =>
      deviceId != null &&
              deviceId.isNotEmpty &&
              cockpitLooksLikeIosSimulatorDeviceId(deviceId)
          ? 'simctl'
          : 'remote',
    'macos' => 'macos-host',
    'linux' => 'linux-host',
    'windows' => 'windows-host',
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

Future<void> _defaultWait(Duration duration) => Future<void>.delayed(duration);

String _recordingDriverForVerification({
  required String platform,
  required String deviceId,
  required bool fallbackUsed,
}) {
  final driver = cockpitDemoRecordingDriverForPlatform(
    platform: platform,
    deviceId: deviceId,
  );
  return fallbackUsed ? '$driver-fallback' : driver;
}

bool _shouldAllowHostRecordingPrerequisiteFailure({
  required String platform,
  required CockpitDemoPlatformVerificationRequest request,
  required Object error,
}) {
  if (!_canSynthesizeHostRecordingFallback(
    platform: platform,
    request: request,
  )) {
    return false;
  }

  if (error is CockpitApplicationServiceException) {
    final statusCode = error.details['statusCode'];
    if (error.code == 'recordingStartFailed' && statusCode == 412) {
      return true;
    }
    if (error.code == 'recordingStopFailed') {
      return true;
    }
  }

  final message = '$error';
  return message.contains('Remote session request failed: 412') ||
      message.contains(
        'CockpitApplicationServiceException(recordingStartFailed)',
      ) ||
      message.contains('"error":"recordingStartFailed"') ||
      message.contains('recordingStopFailed') ||
      message.contains('did not confirm startup or produce output') ||
      message.contains('ffmpeg never confirmed') ||
      message.contains('startup/output evidence') ||
      message.contains('Screen Recording permission') ||
      message.contains('recording output file was missing or empty') ||
      message.contains('desktop capture prerequisite');
}

bool _canSynthesizeHostRecordingFallback({
  required String platform,
  required CockpitDemoPlatformVerificationRequest request,
}) {
  return switch (platform) {
    'linux' || 'macos' || 'windows' => true,
    'web' => !request.strictWebHostRecording,
    _ => false,
  };
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

final class _TimelineRecordingFallback {
  const _TimelineRecordingFallback({
    required this.relativePath,
    required this.outputPath,
    required this.durationMs,
    required this.kind,
  });

  final String relativePath;
  final String outputPath;
  final int durationMs;
  final String kind;
}

final class _SystemControlVerification {
  const _SystemControlVerification({
    required this.adapter,
    required this.availableActions,
    required this.verifiedActions,
    required this.skippedActions,
  });

  final String adapter;
  final List<String> availableActions;
  final List<String> verifiedActions;
  final List<String> skippedActions;
}

final class _SystemControlActionProbe {
  const _SystemControlActionProbe(
    this.action, {
    this.parameters = const <String, Object?>{},
    this.timeout = const Duration(seconds: 15),
  });

  final CockpitSystemControlAction action;
  final Map<String, Object?> parameters;
  final Duration timeout;
}

final class _ResolvedDevice {
  const _ResolvedDevice({required this.deviceId, required this.bootstrapped});

  final String deviceId;
  final bool bootstrapped;
}

const List<int> _minimalPngBytes = <int>[
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0A,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
];

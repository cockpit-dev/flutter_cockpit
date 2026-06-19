import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:cockpit/cockpit.dart';
import 'package:path/path.dart' as p;

import 'cockpit_demo_platform_verifier.dart';

typedef CockpitDemoRapidLaunchAppFunction =
    Future<CockpitLaunchAppResult> Function(CockpitLaunchAppRequest request);
typedef CockpitDemoRapidReadAppFunction =
    Future<CockpitReadAppResult> Function(CockpitReadAppRequest request);
typedef CockpitDemoRapidRunBatchFunction =
    Future<CockpitRunBatchResult> Function(CockpitRunBatchRequest request);
typedef CockpitDemoRapidCaptureScreenshotFunction =
    Future<CockpitCaptureScreenshotResult> Function(
      CockpitCaptureScreenshotRequest request,
    );
typedef CockpitDemoRapidWaitIdleFunction =
    Future<CockpitWaitIdleResult> Function(CockpitWaitIdleRequest request);
typedef CockpitDemoRapidHotReloadFunction =
    Future<CockpitHotReloadResult> Function(CockpitHotReloadRequest request);
typedef CockpitDemoRapidReadErrorsFunction =
    Future<CockpitReadErrorsResult> Function(CockpitReadErrorsRequest request);
typedef CockpitDemoRapidStopAppFunction =
    Future<CockpitStopAppResult> Function(CockpitStopAppRequest request);

const List<String> cockpitDemoRapidDefaultPlatforms = <String>[
  'macos',
  'ios',
  'android',
];

final class CockpitDemoRapidVerificationRequest {
  const CockpitDemoRapidVerificationRequest({
    required this.projectDir,
    this.platforms = cockpitDemoRapidDefaultPlatforms,
    this.target,
    this.outputRoot = '.dart_tool/cockpit_rapid_dev',
    this.sessionPortBase = 58431,
    this.launchTimeout = const Duration(seconds: 180),
    this.deviceTimeout = const Duration(seconds: 420),
    this.androidEmulatorId = 'Pixel_9_Pro',
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
  final bool failFast;
}

final class CockpitDemoRapidPlatformVerification {
  const CockpitDemoRapidPlatformVerification({
    required this.platform,
    required this.status,
    required this.deviceId,
    required this.bootstrappedDevice,
    required this.outputDir,
    required this.verifiedCommands,
    this.appJsonPath,
    this.baseUrl,
    this.initialRouteName,
    this.postCreateRouteName,
    this.postReloadRouteName,
    this.createdTaskTitle,
    this.queueBrief,
    this.hotReloadSucceeded = false,
    this.reloadGeneration = 0,
    this.waitIdleSucceeded = false,
    this.runtimeErrorCount = 0,
    this.screenshotArtifactRef,
    this.screenshotByteLength,
    this.failureCode,
    this.failureMessage,
    this.failureDetails,
    this.runtimeErrorPreviews = const <Map<String, Object?>>[],
  });

  final String platform;
  final String status;
  final String deviceId;
  final bool bootstrappedDevice;
  final String outputDir;
  final List<String> verifiedCommands;
  final String? appJsonPath;
  final String? baseUrl;
  final String? initialRouteName;
  final String? postCreateRouteName;
  final String? postReloadRouteName;
  final String? createdTaskTitle;
  final String? queueBrief;
  final bool hotReloadSucceeded;
  final int reloadGeneration;
  final bool waitIdleSucceeded;
  final int runtimeErrorCount;
  final String? screenshotArtifactRef;
  final int? screenshotByteLength;
  final String? failureCode;
  final String? failureMessage;
  final Map<String, Object?>? failureDetails;
  final List<Map<String, Object?>> runtimeErrorPreviews;

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
    if (postCreateRouteName != null) 'postCreateRouteName': postCreateRouteName,
    if (postReloadRouteName != null) 'postReloadRouteName': postReloadRouteName,
    if (createdTaskTitle != null) 'createdTaskTitle': createdTaskTitle,
    if (queueBrief != null) 'queueBrief': queueBrief,
    'hotReloadSucceeded': hotReloadSucceeded,
    'reloadGeneration': reloadGeneration,
    'waitIdleSucceeded': waitIdleSucceeded,
    'runtimeErrorCount': runtimeErrorCount,
    if (screenshotArtifactRef != null)
      'screenshotArtifactRef': screenshotArtifactRef,
    if (screenshotByteLength != null)
      'screenshotByteLength': screenshotByteLength,
    'verifiedCommands': verifiedCommands,
    if (failureCode != null) 'failureCode': failureCode,
    if (failureMessage != null) 'failureMessage': failureMessage,
    if (failureDetails != null) 'failureDetails': failureDetails,
    if (runtimeErrorPreviews.isNotEmpty)
      'runtimeErrorPreviews': runtimeErrorPreviews,
  };
}

final class CockpitDemoRapidVerificationResult {
  const CockpitDemoRapidVerificationResult({
    required this.platforms,
    required this.success,
    required this.recommendedNextStep,
  });

  final List<CockpitDemoRapidPlatformVerification> platforms;
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

final class CockpitDemoRapidDevVerifier {
  CockpitDemoRapidDevVerifier({
    CockpitDemoPlatformDeviceProbe? probeDevices,
    CockpitDemoIosSimulatorProbe? listIosSimulators,
    CockpitDemoProcessRunner runProcess = Process.run,
    CockpitDemoWait? wait,
    CockpitDemoClock? clock,
    CockpitDemoRapidLaunchAppFunction? launchApp,
    CockpitDemoRapidReadAppFunction? readApp,
    CockpitDemoRapidRunBatchFunction? runBatch,
    CockpitDemoRapidCaptureScreenshotFunction? captureScreenshot,
    CockpitDemoRapidWaitIdleFunction? waitIdle,
    CockpitDemoRapidHotReloadFunction? hotReload,
    CockpitDemoRapidReadErrorsFunction? readErrors,
    CockpitDemoRapidStopAppFunction? stopApp,
  }) : _probeDevices =
           probeDevices ??
           (() => cockpitDemoProbeHostDevices(processRunner: runProcess)),
       _listIosSimulators =
           listIosSimulators ??
           (() => cockpitDemoListIosSimulators(processRunner: runProcess)),
       _processRunner = runProcess,
       _wait = wait ?? _defaultWait,
       _clock = clock ?? DateTime.now,
       _launchApp = launchApp ?? CockpitLaunchAppService().launch,
       _readApp = readApp ?? CockpitReadAppService().read,
       _runBatch = runBatch ?? CockpitRunBatchService().run,
       _captureScreenshot =
           captureScreenshot ?? CockpitCaptureScreenshotService().capture,
       _waitIdle = waitIdle ?? CockpitWaitIdleService().wait,
       _hotReload = hotReload ?? CockpitHotReloadService().reload,
       _readErrors = readErrors ?? cockpitDemoReadErrors,
       _stopApp = stopApp ?? CockpitStopAppService().stop;

  final CockpitDemoPlatformDeviceProbe _probeDevices;
  final CockpitDemoIosSimulatorProbe _listIosSimulators;
  final CockpitDemoProcessRunner _processRunner;
  final CockpitDemoWait _wait;
  final CockpitDemoClock _clock;
  final CockpitDemoRapidLaunchAppFunction _launchApp;
  final CockpitDemoRapidReadAppFunction _readApp;
  final CockpitDemoRapidRunBatchFunction _runBatch;
  final CockpitDemoRapidCaptureScreenshotFunction _captureScreenshot;
  final CockpitDemoRapidWaitIdleFunction _waitIdle;
  final CockpitDemoRapidHotReloadFunction _hotReload;
  final CockpitDemoRapidReadErrorsFunction _readErrors;
  final CockpitDemoRapidStopAppFunction _stopApp;

  Future<CockpitDemoRapidVerificationResult> verify(
    CockpitDemoRapidVerificationRequest request,
  ) async {
    final results = <CockpitDemoRapidPlatformVerification>[];
    final platforms = request.platforms
        .map(cockpitDemoNormalizeVerificationPlatform)
        .toList(growable: false);

    for (var index = 0; index < platforms.length; index += 1) {
      final platform = platforms[index];
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
    return CockpitDemoRapidVerificationResult(
      platforms: results,
      success: success,
      recommendedNextStep: success
          ? 'continueRapidDevelopment'
          : 'inspectRapidLoopFailure',
    );
  }

  Future<CockpitDemoRapidPlatformVerification> _verifyPlatform({
    required String platform,
    required CockpitDemoRapidVerificationRequest request,
    required int sessionPort,
  }) async {
    final outputDir = p.normalize(p.join(request.outputRoot, platform));
    final appJsonPath = p.join(outputDir, 'app.json');
    CockpitAppHandle? app;
    String? deviceId;
    var bootstrappedDevice = false;
    String? resolvedAppJsonPath;
    String? initialRouteName;
    String? postCreateRouteName;
    String? postReloadRouteName;
    String? createdTaskTitle;
    String? queueBrief;
    var hotReloadSucceeded = false;
    var reloadGeneration = 0;
    var waitIdleSucceeded = false;
    var runtimeErrorCount = 0;
    String? screenshotArtifactRef;
    int? screenshotByteLength;
    var runtimeErrorPreviews = const <Map<String, Object?>>[];
    final verifiedCommands = <String>[];

    try {
      await Directory(outputDir).create(recursive: true);
      final resolvedDevice = await _ensureDeviceForPlatform(
        platform: platform,
        request: request,
      );
      deviceId = resolvedDevice.deviceId;
      bootstrappedDevice = resolvedDevice.bootstrapped;
      await cockpitDemoCleanupExampleLocalState(
        platform: platform,
        deviceId: deviceId,
        workingDirectory: request.projectDir,
        processRunner: _processRunner,
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
      resolvedAppJsonPath = launchResult.appJsonPath ?? appJsonPath;
      final appBaseUri = Uri.parse(launchedApp.baseUrl);
      verifiedCommands.add('launch-app');

      final initialRead = await _readAppWithRetry(
        CockpitReadAppRequest(
          app: launchedApp,
          resultProfile: const CockpitInteractiveResultProfile.minimal(),
        ),
      );
      initialRouteName = initialRead.currentRouteName;
      _requireRoute(
        routeName: initialRouteName,
        expectedRoute: '/inbox',
        platform: platform,
        label: 'initial route',
      );
      verifiedCommands.add('read-app');

      final taskTitle =
          'Rapid AI loop ${platform}_${_clock().toUtc().microsecondsSinceEpoch}';
      createdTaskTitle = taskTitle;
      final createResult = await _runBatchWithRetry(
        CockpitRunBatchRequest(
          app: launchedApp,
          commands: _batchCommandsFromJson(
            _buildRapidCreateTaskBatch(taskTitle: taskTitle),
          ),
          defaultResultProfile: const CockpitInteractiveResultProfile.minimal(),
          finalSnapshotProfile:
              const CockpitInteractiveResultProfile.standard(),
          failFast: true,
        ),
      );
      _requireBatchSuccess(
        result: createResult,
        expectedCount: 13,
        platform: platform,
      );
      queueBrief =
          'Queue brief: 1 active / 1 due today / 1 priority / 0 conflicts';
      verifiedCommands.add('run-batch');

      final waitIdleResult = await _waitIdle(
        CockpitWaitIdleRequest(
          app: launchedApp,
          quietWindow: const Duration(milliseconds: 120),
          timeout: const Duration(seconds: 4),
        ),
      );
      waitIdleSucceeded = waitIdleResult.idle;
      if (!waitIdleResult.idle) {
        throw CockpitApplicationServiceException(
          code: 'waitIdleTimedOut',
          message: 'Rapid verifier did not reach an idle UI state.',
          details: <String, Object?>{
            'platform': platform,
            'durationMs': waitIdleResult.durationMs,
            'timeoutMs': waitIdleResult.timeoutMs,
          },
        );
      }
      verifiedCommands.add('wait-idle');

      final postCreateRead = await _readAppWithRetry(
        CockpitReadAppRequest(
          app: launchedApp,
          resultProfile: const CockpitInteractiveResultProfile.minimal(),
        ),
      );
      postCreateRouteName = postCreateRead.currentRouteName;
      _requireRoute(
        routeName: postCreateRouteName,
        expectedRoute: '/inbox',
        platform: platform,
        label: 'post-create route',
      );

      final hotReloadResult = await _hotReload(
        CockpitHotReloadRequest(app: launchedApp),
      );
      if (hotReloadResult.status.lastReloadSucceeded != true) {
        throw CockpitApplicationServiceException(
          code: 'hotReloadFailed',
          message: 'Rapid verifier hot reload did not succeed.',
          details: <String, Object?>{
            'platform': platform,
            'state': hotReloadResult.status.state.jsonValue,
          },
        );
      }
      hotReloadSucceeded = hotReloadResult.status.lastReloadSucceeded ?? false;
      reloadGeneration = hotReloadResult.status.reloadGeneration;
      verifiedCommands.add('hot-reload');

      final postReloadRead = await _readAppWithRetry(
        CockpitReadAppRequest(
          app: hotReloadResult.app,
          resultProfile: const CockpitInteractiveResultProfile.standard(),
        ),
      );
      postReloadRouteName = postReloadRead.currentRouteName;
      _requireRoute(
        routeName: postReloadRouteName,
        expectedRoute: '/inbox',
        platform: platform,
        label: 'post-reload route',
      );
      _requireReadAppText(
        result: postReloadRead,
        expectedText: taskTitle,
        platform: platform,
        label: 'created task',
      );
      _requireReadAppText(
        result: postReloadRead,
        expectedText: 'HIGH',
        platform: platform,
        label: 'priority chip',
      );

      final captureResult = await _captureScreenshotWithRetry(
        CockpitCaptureScreenshotRequest(
          app: hotReloadResult.app,
          appHandlePath: resolvedAppJsonPath,
          name: 'rapid_queue_brief',
          reason: CockpitScreenshotReason.acceptance,
          includeSnapshot: true,
          attachToStep: true,
          resultProfile: const CockpitInteractiveResultProfile.evidence(),
          defaultCommandTimeout: const Duration(seconds: 30),
        ),
      );
      _requireCaptureScreenshotSuccess(
        result: captureResult,
        platform: platform,
      );
      final screenshotArtifact = captureResult.artifacts.firstWhere(
        (artifact) => artifact.role == 'screenshot',
        orElse: () => throw CockpitApplicationServiceException(
          code: 'screenshotMissing',
          message: 'Rapid verifier screenshot command returned no artifact.',
          details: <String, Object?>{'platform': platform},
        ),
      );
      screenshotArtifactRef = screenshotArtifact.relativePath;
      screenshotByteLength = await _exportScreenshotArtifact(
        platform: platform,
        artifact: screenshotArtifact,
        outputDir: outputDir,
      );
      verifiedCommands.add('capture-screenshot');

      final errorsResult = await _readErrors(
        CockpitReadErrorsRequest(
          appHandlePath: resolvedAppJsonPath,
          baseUri: appBaseUri,
          includeLatestTask: false,
          includeSessions: false,
        ),
      );
      runtimeErrorCount = errorsResult.errors.length;
      runtimeErrorPreviews = _runtimeErrorPreviews(errorsResult.errors);
      if (errorsResult.hasErrors) {
        throw CockpitApplicationServiceException(
          code: 'runtimeErrorsDetected',
          message: 'Runtime errors were captured during rapid verification.',
          details: <String, Object?>{
            'platform': platform,
            'errorCount': errorsResult.errors.length,
            'runtimeErrorPreviews': runtimeErrorPreviews,
          },
        );
      }
      verifiedCommands.add('read-errors');

      return CockpitDemoRapidPlatformVerification(
        platform: platform,
        status: 'passed',
        deviceId: deviceId,
        bootstrappedDevice: bootstrappedDevice,
        outputDir: outputDir,
        appJsonPath: resolvedAppJsonPath,
        baseUrl: launchedApp.baseUrl,
        initialRouteName: initialRouteName,
        postCreateRouteName: postCreateRouteName,
        postReloadRouteName: postReloadRouteName,
        createdTaskTitle: createdTaskTitle,
        queueBrief: queueBrief,
        hotReloadSucceeded: hotReloadSucceeded,
        reloadGeneration: reloadGeneration,
        waitIdleSucceeded: waitIdleSucceeded,
        runtimeErrorCount: runtimeErrorCount,
        screenshotArtifactRef: screenshotArtifactRef,
        screenshotByteLength: screenshotByteLength,
        verifiedCommands: verifiedCommands,
      );
    } on Object catch (error) {
      final failureDetails = error is CockpitApplicationServiceException
          ? error.details
          : <String, Object?>{
              'errorType': error.runtimeType.toString(),
              'message': '$error',
            };
      return CockpitDemoRapidPlatformVerification(
        platform: platform,
        status: 'failed',
        deviceId: deviceId ?? platform,
        bootstrappedDevice: bootstrappedDevice,
        outputDir: outputDir,
        appJsonPath: resolvedAppJsonPath ?? appJsonPath,
        baseUrl: app?.baseUrl,
        initialRouteName: initialRouteName,
        postCreateRouteName: postCreateRouteName,
        postReloadRouteName: postReloadRouteName,
        createdTaskTitle: createdTaskTitle,
        queueBrief: queueBrief,
        hotReloadSucceeded: hotReloadSucceeded,
        reloadGeneration: reloadGeneration,
        waitIdleSucceeded: waitIdleSucceeded,
        runtimeErrorCount: runtimeErrorCount,
        screenshotArtifactRef: screenshotArtifactRef,
        screenshotByteLength: screenshotByteLength,
        verifiedCommands: List<String>.unmodifiable(verifiedCommands),
        failureCode: error is CockpitApplicationServiceException
            ? error.code
            : error.runtimeType.toString(),
        failureMessage: '$error',
        failureDetails: failureDetails,
        runtimeErrorPreviews: runtimeErrorPreviews,
      );
    } finally {
      if (app != null) {
        try {
          await _stopApp(CockpitStopAppRequest(app: app));
        } on Object {
          // Preserve the primary verification result.
        }
      }
      if (platform == 'android' &&
          deviceId != null &&
          deviceId.isNotEmpty &&
          deviceId != 'android') {
        await cockpitDemoCleanupAndroidPortForward(
          deviceId: deviceId,
          sessionPort: sessionPort,
          workingDirectory: request.projectDir,
          processRunner: _processRunner,
        );
      }
    }
  }

  Future<_ResolvedRapidDevice> _ensureDeviceForPlatform({
    required String platform,
    required CockpitDemoRapidVerificationRequest request,
  }) async {
    final available = await _probeDevices();
    final existing = cockpitDemoMatchingVerificationDevice(
      devices: available,
      platform: platform,
    );
    if (existing != null) {
      return _ResolvedRapidDevice(
        deviceId: existing.deviceId,
        bootstrapped: false,
      );
    }

    switch (platform) {
      case 'macos':
      case 'linux':
      case 'windows':
      case 'web':
        throw CockpitApplicationServiceException(
          code: '${platform}Unavailable',
          message: '$platform is not available in flutter devices.',
        );
      case 'ios':
        final simulator = cockpitDemoSelectIosSimulator(
          await _listIosSimulators(),
        );
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
        await _runProcess('flutter', <String>[
          'emulators',
          '--launch',
          request.androidEmulatorId,
        ], workingDirectory: request.projectDir);
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

  Future<_ResolvedRapidDevice> _waitForDevice({
    required String platform,
    required Duration timeout,
  }) async {
    final deadline = _clock().add(timeout);
    while (!_clock().isAfter(deadline)) {
      final device = cockpitDemoMatchingVerificationDevice(
        devices: await _probeDevices(),
        platform: platform,
      );
      if (device != null) {
        return _ResolvedRapidDevice(
          deviceId: device.deviceId,
          bootstrapped: true,
        );
      }
      await _wait(const Duration(seconds: 2));
    }
    throw CockpitApplicationServiceException(
      code: 'deviceBootstrapTimeout',
      message: 'Timed out waiting for $platform to become available.',
      details: <String, Object?>{'platform': platform},
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
        message: 'External command failed during rapid verification.',
        details: <String, Object?>{
          'command': <String>[executable, ...arguments],
          'exitCode': result.exitCode,
          'stderr': '${result.stderr}',
        },
      );
    }
    return result;
  }

  Future<CockpitRunBatchResult> _runBatchWithRetry(
    CockpitRunBatchRequest request,
  ) async {
    for (var attempt = 0; attempt < 2; attempt += 1) {
      try {
        return await _runBatch(request);
      } on CockpitApplicationServiceException catch (error) {
        if (error.code != 'remoteUnavailable' || attempt == 1) {
          rethrow;
        }
        await _wait(Duration(milliseconds: 360 * (attempt + 1)));
      }
    }
    throw StateError('Unreachable batch retry state.');
  }

  Future<CockpitReadAppResult> _readAppWithRetry(
    CockpitReadAppRequest request,
  ) async {
    for (var attempt = 0; attempt < 5; attempt += 1) {
      try {
        return await _readApp(request);
      } on CockpitApplicationServiceException catch (error) {
        final shouldRetry =
            attempt + 1 < 5 &&
            (error.code == 'remoteUnavailable' ||
                (error.code == 'serverError' &&
                    error.message.contains(
                      'FlutterCockpitRoot is not mounted',
                    )));
        if (!shouldRetry) {
          rethrow;
        }
        await _wait(Duration(milliseconds: 400 * (attempt + 1)));
      }
    }
    throw StateError('Unreachable read-app retry state.');
  }

  Future<CockpitCaptureScreenshotResult> _captureScreenshotWithRetry(
    CockpitCaptureScreenshotRequest request,
  ) async {
    for (var attempt = 0; attempt < 2; attempt += 1) {
      try {
        return await _captureScreenshot(request);
      } on CockpitApplicationServiceException catch (error) {
        final shouldRetry =
            error.code == 'remoteUnavailable' && attempt + 1 < 2;
        if (!shouldRetry) {
          rethrow;
        }
        await _wait(Duration(milliseconds: 400 * (attempt + 1)));
      }
    }
    throw StateError('Unreachable capture retry state.');
  }

  Future<int> _exportScreenshotArtifact({
    required String platform,
    required CockpitInteractiveArtifactDescriptor artifact,
    required String outputDir,
  }) async {
    final sourcePath = artifact.sourcePath;
    if (sourcePath == null || sourcePath.isEmpty) {
      throw CockpitApplicationServiceException(
        code: 'rapidScreenshotArtifactUnavailable',
        message:
            'Rapid verifier screenshot evidence did not include a source file path.',
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
        code: 'rapidScreenshotArtifactUnavailable',
        message: 'Rapid verifier screenshot source file does not exist.',
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
        code: 'rapidScreenshotArtifactEmpty',
        message: 'Rapid verifier screenshot source file is empty.',
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
    return byteLength;
  }

  void _requireBatchSuccess({
    required CockpitRunBatchResult result,
    required int expectedCount,
    required String platform,
  }) {
    if (result.summary.failureCount == 0 &&
        !result.summary.stoppedEarly &&
        result.summary.totalCount == expectedCount &&
        result.results.every((entry) => entry.command.success)) {
      return;
    }
    CockpitInteractiveCommandCore? failedCommand;
    for (final entry in result.results) {
      if (!entry.command.success) {
        failedCommand = entry.command;
        break;
      }
    }
    throw CockpitApplicationServiceException(
      code: 'rapidBatchFailed',
      message: 'Rapid verifier batch did not complete successfully.',
      details: <String, Object?>{
        'platform': platform,
        'totalCount': result.summary.totalCount,
        'failureCount': result.summary.failureCount,
        'stoppedEarly': result.summary.stoppedEarly,
        if (failedCommand != null) 'commandId': failedCommand.commandId,
        if (failedCommand != null) 'commandType': failedCommand.commandType,
        if (failedCommand?.error != null)
          'error': failedCommand!.error!.toJson(),
        ..._finalSnapshotFailureDetails(result.finalSnapshot),
      },
    );
  }

  void _requireRoute({
    required String? routeName,
    required String expectedRoute,
    required String platform,
    required String label,
  }) {
    if (routeName == expectedRoute) {
      return;
    }
    throw CockpitApplicationServiceException(
      code: 'unexpectedRoute',
      message: 'Rapid verifier did not land on the expected route.',
      details: <String, Object?>{
        'platform': platform,
        'label': label,
        'expectedRoute': expectedRoute,
        'actualRoute': routeName,
      },
    );
  }

  void _requireCaptureScreenshotSuccess({
    required CockpitCaptureScreenshotResult result,
    required String platform,
  }) {
    final command = result.command;
    if (command.success) {
      return;
    }
    throw CockpitApplicationServiceException(
      code: 'captureScreenshotFailed',
      message: 'Rapid verifier screenshot command failed.',
      details: <String, Object?>{
        'platform': platform,
        'commandId': command.commandId,
        'commandType': command.commandType,
        if (command.resolvedCaptureKind != null)
          'resolvedCaptureKind': command.resolvedCaptureKind,
        'usedCaptureFallback': command.usedCaptureFallback,
        if (command.degradationReason != null)
          'degradationReason': command.degradationReason,
        if (command.error != null) 'error': command.error!.toJson(),
        if (result.artifacts.isNotEmpty)
          'artifacts': result.artifacts
              .map((artifact) => artifact.toJson())
              .toList(growable: false),
      },
    );
  }

  void _requireReadAppText({
    required CockpitReadAppResult result,
    required String? expectedText,
    required String platform,
    required String label,
  }) {
    if (expectedText == null || expectedText.isEmpty) {
      throw CockpitApplicationServiceException(
        code: 'rapidExpectedTextMissing',
        message: 'Rapid verifier cannot assert an empty $label.',
        details: <String, Object?>{'platform': platform, 'label': label},
      );
    }
    final candidates = <String>[
      ...?result.uiSummary?.textPreviews,
      ...?result.snapshot?.visibleTargets
          .map((target) => target.text)
          .whereType<String>(),
    ];
    if (candidates.any((candidate) => candidate.contains(expectedText))) {
      return;
    }
    throw CockpitApplicationServiceException(
      code: 'rapidSnapshotTextMissing',
      message: 'Rapid verifier read-app snapshot did not contain $label.',
      details: <String, Object?>{
        'platform': platform,
        'label': label,
        'expectedText': expectedText,
        'currentRouteName': result.currentRouteName,
        'visibleTextCandidates': _boundedStringList(
          candidates,
          _rapidMaxSnapshotPreviews,
        ),
      },
    );
  }

  List<CockpitRunBatchCommand> _batchCommandsFromJson(
    List<Map<String, Object?>> commands,
  ) {
    return commands
        .map(
          (command) =>
              CockpitRunBatchCommand(command: CockpitCommand.fromJson(command)),
        )
        .toList(growable: false);
  }
}

Map<String, Object?> _finalSnapshotFailureDetails(
  CockpitReadRemoteSnapshotResult? snapshot,
) {
  if (snapshot == null) {
    return const <String, Object?>{};
  }
  final summary = snapshot.uiSummary;
  return <String, Object?>{
    if (snapshot.routeName != null) 'finalRouteName': snapshot.routeName,
    'finalDiagnosticLevel': snapshot.diagnosticLevel,
    'finalTruncated': snapshot.truncated,
    if (summary != null) ...<String, Object?>{
      'finalVisibleTargetCount': summary.visibleTargetCount,
      'finalRuntimeErrorCount': summary.runtimeErrorCount,
      'finalTextPreviews': _boundedStringList(
        summary.textPreviews,
        _rapidMaxSnapshotPreviews,
      ),
    },
    if (snapshot.snapshotRef != null) 'finalSnapshotRef': snapshot.snapshotRef,
  };
}

List<Map<String, Object?>> _runtimeErrorPreviews(
  List<CockpitErrorEntry> errors,
) {
  return errors
      .take(_rapidMaxRuntimeErrorPreviews)
      .map(
        (error) => <String, Object?>{
          'source': error.source,
          'message': _boundedText(error.message, _rapidMaxPreviewTextLength),
          if (error.recordedAt != null)
            'recordedAt': error.recordedAt!.toUtc().toIso8601String(),
          if (error.kind != null) 'kind': error.kind,
          if (error.routeName != null) 'routeName': error.routeName,
        },
      )
      .toList(growable: false);
}

List<String> _boundedStringList(List<String> values, int maxCount) {
  return values
      .take(maxCount)
      .map((value) => _boundedText(value, _rapidMaxPreviewTextLength))
      .toList(growable: false);
}

String _boundedText(String value, int maxLength) {
  if (value.length <= maxLength) {
    return value;
  }
  return '${value.substring(0, maxLength)}...';
}

const int _rapidMaxSnapshotPreviews = 12;
const int _rapidMaxRuntimeErrorPreviews = 5;
const int _rapidMaxPreviewTextLength = 480;

List<Map<String, Object?>> _buildRapidCreateTaskBatch({
  required String taskTitle,
}) {
  return <Map<String, Object?>>[
    <String, Object?>{
      'commandId': 'rapid-open-editor',
      'commandType': 'tap',
      'locator': <String, Object?>{
        'text': 'New task',
        'ancestor': <String, Object?>{'route': '/inbox'},
      },
    },
    <String, Object?>{
      'commandId': 'rapid-enter-title',
      'commandType': 'enterText',
      'locator': <String, Object?>{
        'text': 'Task title',
        'ancestor': <String, Object?>{'route': '/editor'},
      },
      'parameters': <String, Object?>{'text': taskTitle},
    },
    <String, Object?>{
      'commandId': 'rapid-reveal-notes',
      'commandType': 'scrollUntilVisible',
      'locator': <String, Object?>{
        'text': 'Notes',
        'route': '/editor',
        'ancestor': <String, Object?>{'route': '/editor'},
      },
      'parameters': const <String, Object?>{
        'maxScrolls': 6,
        'viewportFraction': 0.62,
        'continuous': true,
        'durationPerStepMs': 180,
        'revealAlignment': 'center',
      },
    },
    <String, Object?>{
      'commandId': 'rapid-enter-notes',
      'commandType': 'enterText',
      'locator': <String, Object?>{
        'text': 'Notes',
        'type': 'TextField',
        'ancestor': <String, Object?>{'route': '/editor'},
      },
      'parameters': const <String, Object?>{
        'text': 'Created during the rapid AI development verifier.',
      },
    },
    <String, Object?>{
      'commandId': 'rapid-dismiss-keyboard',
      'commandType': 'dismissKeyboard',
    },
    <String, Object?>{
      'commandId': 'rapid-reveal-high-priority',
      'commandType': 'scrollUntilVisible',
      'locator': <String, Object?>{
        'semanticId': 'task-editor-priority-high',
        'text': 'HIGH',
        'route': '/editor',
        'ancestor': <String, Object?>{'route': '/editor'},
      },
      'parameters': const <String, Object?>{
        'maxScrolls': 6,
        'viewportFraction': 0.62,
        'continuous': true,
        'durationPerStepMs': 180,
        'revealAlignment': 'center',
      },
    },
    <String, Object?>{
      'commandId': 'rapid-select-high-priority',
      'commandType': 'tap',
      'locator': <String, Object?>{
        'semanticId': 'task-editor-priority-high',
        'text': 'HIGH',
        'route': '/editor',
        'ancestor': <String, Object?>{'route': '/editor'},
      },
    },
    <String, Object?>{
      'commandId': 'rapid-reveal-due-date-section',
      'commandType': 'scrollUntilVisible',
      'locator': <String, Object?>{
        'text': 'Due date',
        'route': '/editor',
        'ancestor': <String, Object?>{'route': '/editor'},
      },
      'parameters': const <String, Object?>{
        'maxScrolls': 6,
        'viewportFraction': 0.38,
        'continuous': true,
        'durationPerStepMs': 180,
        'revealAlignment': 'center',
      },
    },
    <String, Object?>{
      'commandId': 'rapid-reveal-today',
      'commandType': 'scrollUntilVisible',
      'locator': <String, Object?>{
        'semanticId': 'task-editor-due-today',
        'text': 'Today',
        'route': '/editor',
        'ancestor': <String, Object?>{'route': '/editor'},
      },
      'parameters': const <String, Object?>{
        'maxScrolls': 8,
        'viewportFraction': 0.52,
        'continuous': true,
        'durationPerStepMs': 180,
        'revealAlignment': 'center',
        'revealPaddingPx': 24,
      },
    },
    <String, Object?>{
      'commandId': 'rapid-select-today',
      'commandType': 'tap',
      'locator': <String, Object?>{
        'semanticId': 'task-editor-due-today',
        'text': 'Today',
        'route': '/editor',
        'ancestor': <String, Object?>{'route': '/editor'},
      },
    },
    <String, Object?>{
      'commandId': 'rapid-save-task',
      'commandType': 'tap',
      'locator': <String, Object?>{
        'text': 'Save task',
        'ancestor': <String, Object?>{'route': '/editor'},
      },
    },
    <String, Object?>{
      'commandId': 'rapid-wait-inbox',
      'commandType': 'waitFor',
      'timeoutMs': 12000,
      'parameters': const <String, Object?>{'routeName': '/inbox'},
    },
    <String, Object?>{
      'commandId': 'rapid-wait-queue-brief',
      'commandType': 'waitFor',
      'timeoutMs': 12000,
      'parameters': const <String, Object?>{
        'text':
            'Queue brief: 1 active / 1 due today / 1 priority / 0 conflicts',
      },
    },
  ];
}

String cockpitDemoRapidResultJson(CockpitDemoRapidVerificationResult result) {
  return const JsonEncoder.withIndent('  ').convert(result.toJson());
}

final class _ResolvedRapidDevice {
  const _ResolvedRapidDevice({
    required this.deviceId,
    required this.bootstrapped,
  });

  final String deviceId;
  final bool bootstrapped;
}

Future<void> _defaultWait(Duration duration) => Future<void>.delayed(duration);

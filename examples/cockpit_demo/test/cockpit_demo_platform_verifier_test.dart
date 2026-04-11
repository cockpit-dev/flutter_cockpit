import 'dart:io';

import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_cockpit_devtools/flutter_cockpit_devtools.dart';
import 'package:flutter_test/flutter_test.dart';

import '../tool/src/cockpit_demo_platform_verifier.dart';

void main() {
  test(
    'verifier boots missing mobile targets and validates the development loop',
    () async {
      final launchedRequests = <CockpitLaunchAppRequest>[];
      final commandTypes = <CockpitCommandType>[];
      final batchRequests = <CockpitRunBatchRequest>[];
      final batchedCommandTypes = <CockpitCommandType>[];
      final bootCommands = <String>[];
      final readCounts = <String, int>{};
      final inspectUiRequests = <CockpitInspectUiRequest>[];
      final waitIdleRequests = <CockpitWaitIdleRequest>[];
      final readNetworkRequests = <CockpitReadNetworkRequest>[];
      final readErrorsRequests = <CockpitReadErrorsRequest>[];
      final readLogsRequests = <CockpitReadLogsRequest>[];
      final recordingResolverPlatforms = <String>[];
      final recordingRequests = <CockpitRecordingRequest>[];
      var recordingStopCount = 0;
      final hotRestartRequests = <CockpitHotRestartRequest>[];
      final stopRequests = <CockpitStopAppRequest>[];

      var probeCall = 0;
      final verifier = CockpitDemoPlatformVerifier(
        probeDevices: () async {
          probeCall += 1;
          return switch (probeCall) {
            1 => <CockpitDemoHostDevice>[
                const CockpitDemoHostDevice(
                  name: 'macOS',
                  deviceId: 'macos',
                  platform: 'macos',
                  emulator: false,
                  supported: true,
                ),
                const CockpitDemoHostDevice(
                  name: 'Linux',
                  deviceId: 'linux',
                  platform: 'linux',
                  emulator: false,
                  supported: true,
                ),
                const CockpitDemoHostDevice(
                  name: 'Windows',
                  deviceId: 'windows',
                  platform: 'windows',
                  emulator: false,
                  supported: true,
                ),
              ],
            2 => <CockpitDemoHostDevice>[
                const CockpitDemoHostDevice(
                  name: 'macOS',
                  deviceId: 'macos',
                  platform: 'macos',
                  emulator: false,
                  supported: true,
                ),
                const CockpitDemoHostDevice(
                  name: 'Linux',
                  deviceId: 'linux',
                  platform: 'linux',
                  emulator: false,
                  supported: true,
                ),
                const CockpitDemoHostDevice(
                  name: 'Windows',
                  deviceId: 'windows',
                  platform: 'windows',
                  emulator: false,
                  supported: true,
                ),
              ],
            3 => <CockpitDemoHostDevice>[
                const CockpitDemoHostDevice(
                  name: 'macOS',
                  deviceId: 'macos',
                  platform: 'macos',
                  emulator: false,
                  supported: true,
                ),
                const CockpitDemoHostDevice(
                  name: 'iPhone 17 Pro Max',
                  deviceId: 'FC5B7D0F-B7FB-4A7A-B1B0-FF28BC289BC2',
                  platform: 'ios',
                  emulator: true,
                  supported: true,
                ),
                const CockpitDemoHostDevice(
                  name: 'Linux',
                  deviceId: 'linux',
                  platform: 'linux',
                  emulator: false,
                  supported: true,
                ),
                const CockpitDemoHostDevice(
                  name: 'Windows',
                  deviceId: 'windows',
                  platform: 'windows',
                  emulator: false,
                  supported: true,
                ),
              ],
            4 => <CockpitDemoHostDevice>[
                const CockpitDemoHostDevice(
                  name: 'macOS',
                  deviceId: 'macos',
                  platform: 'macos',
                  emulator: false,
                  supported: true,
                ),
                const CockpitDemoHostDevice(
                  name: 'iPhone 17 Pro Max',
                  deviceId: 'FC5B7D0F-B7FB-4A7A-B1B0-FF28BC289BC2',
                  platform: 'ios',
                  emulator: true,
                  supported: true,
                ),
                const CockpitDemoHostDevice(
                  name: 'Linux',
                  deviceId: 'linux',
                  platform: 'linux',
                  emulator: false,
                  supported: true,
                ),
                const CockpitDemoHostDevice(
                  name: 'Windows',
                  deviceId: 'windows',
                  platform: 'windows',
                  emulator: false,
                  supported: true,
                ),
              ],
            _ => <CockpitDemoHostDevice>[
                const CockpitDemoHostDevice(
                  name: 'macOS',
                  deviceId: 'macos',
                  platform: 'macos',
                  emulator: false,
                  supported: true,
                ),
                const CockpitDemoHostDevice(
                  name: 'iPhone 17 Pro Max',
                  deviceId: 'FC5B7D0F-B7FB-4A7A-B1B0-FF28BC289BC2',
                  platform: 'ios',
                  emulator: true,
                  supported: true,
                ),
                const CockpitDemoHostDevice(
                  name: 'Pixel 9 Pro',
                  deviceId: 'emulator-5554',
                  platform: 'android',
                  emulator: true,
                  supported: true,
                ),
                const CockpitDemoHostDevice(
                  name: 'Linux',
                  deviceId: 'linux',
                  platform: 'linux',
                  emulator: false,
                  supported: true,
                ),
                const CockpitDemoHostDevice(
                  name: 'Windows',
                  deviceId: 'windows',
                  platform: 'windows',
                  emulator: false,
                  supported: true,
                ),
              ],
          };
        },
        listIosSimulators: () async => const <CockpitDemoIosSimulator>[
          CockpitDemoIosSimulator(
            name: 'iPhone 17 Pro Max',
            udid: 'FC5B7D0F-B7FB-4A7A-B1B0-FF28BC289BC2',
            state: 'Shutdown',
            available: true,
          ),
        ],
        runProcess: (executable, arguments, {String? workingDirectory}) async {
          bootCommands.add('$executable ${arguments.join(' ')}');
          return ProcessResult(0, 0, '', '');
        },
        wait: (_) async {},
        launchApp: (request) async {
          launchedRequests.add(request);
          return CockpitLaunchAppResult(
            app: _appForPlatform(
              platform: request.platform,
              deviceId: request.deviceId,
              baseUrl: 'http://127.0.0.1:${request.sessionPort}',
            ),
            appJsonPath:
                '${request.projectDir}/.dart_tool/cockpit_platforms/${request.platform}/app.json',
          );
        },
        readApp: (request) async {
          final app = request.app!;
          final count = (readCounts[app.platform] ?? 0) + 1;
          readCounts[app.platform] = count;
          return CockpitReadAppResult(
            sessionId: '${app.platform}-session',
            transportType: 'remoteHttp',
            capabilities: CockpitCapabilities(
              platform: app.platform,
              transportType: 'remoteHttp',
              supportsInAppControl: true,
              supportsFlutterViewCapture: true,
              supportsNativeScreenCapture: true,
              supportsHostAutomation: app.platform == 'macos',
              supportedCommands: const <CockpitCommandType>[
                CockpitCommandType.tap,
                CockpitCommandType.enterText,
                CockpitCommandType.assertText,
              ],
              supportedLocatorStrategies: CockpitLocatorKind.values,
            ),
            recordingCapabilities: CockpitRecordingCapabilities(
              supportsNativeRecording: true,
              preferredAcceptanceRecordingKind:
                  CockpitRecordingKind.nativeScreen,
            ),
            currentRouteName: '/inbox',
          );
        },
        runCommand: (request) async {
          commandTypes.add(request.command.commandType);
          return CockpitExecuteRemoteCommandResult(
            command: CockpitInteractiveCommandCore(
              commandId: request.command.commandId,
              commandType: request.command.commandType.name,
              success: true,
              durationMs: 12,
              usedCaptureFallback: false,
            ),
            artifacts: request.command.commandType ==
                    CockpitCommandType.captureScreenshot
                ? const <CockpitInteractiveArtifactDescriptor>[
                    CockpitInteractiveArtifactDescriptor(
                      role: 'screenshot',
                      relativePath: 'screenshots/platform-proof.png',
                      byteLength: 1024,
                    ),
                  ]
                : const <CockpitInteractiveArtifactDescriptor>[],
          );
        },
        inspectSurface: (request) async {
          return CockpitInspectSurfaceResult(
            target: CockpitTargetHandle.fromAppHandle(request.app!),
            capabilityProfile: CockpitCapabilityProfile(
              targetKind: CockpitTargetKind.flutterApp,
              surfaceKinds: <CockpitSurfaceKind>{
                CockpitSurfaceKind.flutterSemantic,
              },
              actionCapabilities: <CockpitActionCapability>{
                CockpitActionCapability.tap,
                CockpitActionCapability.typeText,
              },
              evidenceCapabilities: <CockpitEvidenceCapability>{
                CockpitEvidenceCapability.flutterScreenshot,
              },
            ),
            surfaceKind: CockpitSurfaceKind.flutterSemantic,
            selectedPlane: CockpitPlaneKind.flutterSemanticPlane,
            recommendedNextStep: 'continue',
            routeName: '/inbox',
            diagnosticLevel: 'inspect',
            truncated: false,
          );
        },
        inspectUi: (request) async {
          inspectUiRequests.add(request);
          return const CockpitInspectUiResult(
            routeName: '/inbox',
            diagnosticLevel: 'investigate',
            truncated: false,
          );
        },
        runBatch: (request) async {
          batchRequests.add(request);
          for (final batchCommand in request.commands) {
            batchedCommandTypes.add(batchCommand.command.commandType);
          }
          return CockpitRunBatchResult(
            results: request.commands
                .map(
                  (batchCommand) => CockpitExecuteRemoteCommandResult(
                    command: CockpitInteractiveCommandCore(
                      commandId: batchCommand.command.commandId,
                      commandType: batchCommand.command.commandType.name,
                      success: true,
                      durationMs: 12,
                      usedCaptureFallback: false,
                    ),
                    artifacts: const <CockpitInteractiveArtifactDescriptor>[],
                  ),
                )
                .toList(growable: false),
            summary: CockpitExecuteRemoteCommandBatchSummary(
              totalCount: request.commands.length,
              successCount: request.commands.length,
              failureCount: 0,
              stoppedEarly: false,
            ),
          );
        },
        waitIdle: (request) async {
          waitIdleRequests.add(request);
          return const CockpitWaitIdleResult(
            idle: true,
            durationMs: 420,
            quietWindowMs: 160,
            timeoutMs: 5000,
            includeNetworkIdle: true,
          );
        },
        readNetwork: (request) async {
          readNetworkRequests.add(request);
          return CockpitReadNetworkResult(
            appId: 'network-${request.appHandlePath ?? request.baseUri}',
            source: 'app_snapshot',
            available: true,
            routeName: '/inbox',
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
          );
        },
        readErrors: (request) async {
          readErrorsRequests.add(request);
          return const CockpitReadErrorsResult(
            appId: 'errors-app',
            routeName: '/inbox',
            source: 'app_snapshot',
            errors: <CockpitErrorEntry>[],
          );
        },
        readLogs: (request) async {
          readLogsRequests.add(request);
          return const CockpitReadLogsResult(
            appId: 'logs-app',
            source: 'app_snapshot',
            available: true,
            routeName: '/inbox',
            lines: <String>['info runtime: example verifier settled'],
            truncated: false,
          );
        },
        recordingAdapterResolver: ({
          required platform,
          required deviceId,
          required client,
          required recording,
        }) {
          recordingResolverPlatforms.add(platform);
          return _FakeRecordingAdapter(
            onStart: (request) async {
              recordingRequests.add(request);
              return CockpitRecordingSession(
                request: request,
                state: CockpitRecordingState.recording,
              );
            },
            onStop: () async {
              recordingStopCount += 1;
              return CockpitRecordingResult(
                state: CockpitRecordingState.completed,
                purpose: CockpitRecordingPurpose.acceptance,
                recordingKind: CockpitRecordingKind.nativeScreen,
                artifact: const CockpitArtifactRef(
                  role: 'recording',
                  relativePath: 'recordings/platform-loop.mp4',
                ),
                durationMs: 3200,
                sourceFilePath: '/tmp/platform-loop.mp4',
              );
            },
          );
        },
        hotReload: (request) async {
          return CockpitHotReloadResult(
            app: request.app!,
            status: CockpitDevelopmentSessionStatus(
              developmentSessionId: '${request.app!.platform}-session',
              state: CockpitDevelopmentSessionState.ready,
              appReachable: true,
              remoteSessionReachable: true,
              reloadGeneration: 1,
              lastReloadMode: CockpitDevelopmentReloadMode.hotReload,
              lastReloadSucceeded: true,
              lastStatusAt: DateTime.utc(2026, 4, 11),
            ),
          );
        },
        hotRestart: (request) async {
          hotRestartRequests.add(request);
          return CockpitHotRestartResult(
            app: request.app!,
            status: CockpitDevelopmentSessionStatus(
              developmentSessionId: '${request.app!.platform}-session',
              state: CockpitDevelopmentSessionState.ready,
              appReachable: true,
              remoteSessionReachable: true,
              reloadGeneration: 2,
              lastReloadMode: CockpitDevelopmentReloadMode.hotRestart,
              lastReloadSucceeded: true,
              lastStatusAt: DateTime.utc(2026, 4, 11, 0, 0, 1),
            ),
          );
        },
        stopApp: (request) async {
          stopRequests.add(request);
          return CockpitStopAppResult(
            app: request.app!,
            status: CockpitAppStopStatus.stopped(
              mode: request.app!.mode,
            ),
          );
        },
      );

      final result = await verifier.verify(
        const CockpitDemoPlatformVerificationRequest(
          projectDir: '/workspace/examples/cockpit_demo',
          platforms: <String>['macos', 'ios', 'android', 'linux', 'windows'],
          outputRoot: '/tmp/cockpit_demo_platforms',
        ),
      );

      expect(result.success, isTrue);
      expect(
        result.platforms.map((platform) => platform.platform),
        <String>['macos', 'ios', 'android', 'linux', 'windows'],
      );
      expect(
        result.platforms.map((platform) => platform.status),
        everyElement('passed'),
      );
      expect(result.platforms[0].bootstrappedDevice, isFalse);
      expect(result.platforms[1].bootstrappedDevice, isTrue);
      expect(result.platforms[2].bootstrappedDevice, isTrue);
      expect(
        launchedRequests.map((request) => request.deviceId),
        <String>[
          'macos',
          'FC5B7D0F-B7FB-4A7A-B1B0-FF28BC289BC2',
          'emulator-5554',
          'linux',
          'windows',
        ],
      );
      expect(
        bootCommands,
        contains('xcrun simctl boot FC5B7D0F-B7FB-4A7A-B1B0-FF28BC289BC2'),
      );
      expect(
        bootCommands,
        contains('flutter emulators --launch Pixel_9_Pro'),
      );
      expect(
        commandTypes,
        everyElement(
          isIn(<CockpitCommandType>[
            CockpitCommandType.assertText,
            CockpitCommandType.captureScreenshot,
          ]),
        ),
      );
      expect(commandTypes.length, 15);
      final expectedBatchPattern = <CockpitCommandType>[
        CockpitCommandType.tap,
        CockpitCommandType.enterText,
        CockpitCommandType.enterText,
        CockpitCommandType.tap,
      ];
      expect(
        batchedCommandTypes,
        List<CockpitCommandType>.generate(
          5 * expectedBatchPattern.length,
          (index) => expectedBatchPattern[index % expectedBatchPattern.length],
        ),
      );
      expect(batchRequests, hasLength(5));
      final firstBatchCommands = batchRequests.first.commands
          .map((batchCommand) => batchCommand.command)
          .toList(growable: false);
      expect(firstBatchCommands[0].locator?.text, 'New task');
      expect(firstBatchCommands[0].locator?.ancestor?.route, '/inbox');
      expect(firstBatchCommands[1].locator?.text, 'Task title');
      expect(firstBatchCommands[1].locator?.type, isNull);
      expect(firstBatchCommands[1].locator?.ancestor?.route, '/editor');
      expect(firstBatchCommands[2].locator?.text, 'Notes');
      expect(firstBatchCommands[2].locator?.type, isNull);
      expect(firstBatchCommands[2].locator?.ancestor?.route, '/editor');
      expect(firstBatchCommands[3].locator?.text, 'Save task');
      expect(firstBatchCommands[3].locator?.ancestor?.route, '/editor');
      expect(inspectUiRequests, hasLength(5));
      expect(waitIdleRequests, hasLength(5));
      expect(readNetworkRequests, hasLength(5));
      expect(readErrorsRequests, hasLength(5));
      expect(readLogsRequests, hasLength(5));
      expect(
        recordingResolverPlatforms,
        <String>['macos', 'ios', 'android', 'linux', 'windows'],
      );
      expect(recordingRequests, hasLength(5));
      expect(recordingStopCount, 5);
      expect(hotRestartRequests, hasLength(5));
      expect(stopRequests, hasLength(5));
      expect(
        result.platforms.every((platform) => platform.hotReloadSucceeded),
        isTrue,
      );
      expect(
        result.platforms.every((platform) => platform.hotRestartSucceeded),
        isTrue,
      );
      expect(
        result.platforms.every((platform) => platform.waitIdleSucceeded),
        isTrue,
      );
      expect(
        result.platforms.map((platform) => platform.batchCommandCount),
        everyElement(4),
      );
      expect(
        result.platforms.map((platform) => platform.networkFailureCount),
        everyElement(0),
      );
      expect(
        result.platforms.map((platform) => platform.runtimeErrorCount),
        everyElement(0),
      );
      expect(
        result.platforms.map((platform) => platform.logLineCount),
        everyElement(1),
      );
      expect(
        result.platforms.map((platform) => platform.recordingArtifactRef),
        everyElement('recordings/platform-loop.mp4'),
      );
      expect(
        result.platforms.map((platform) => platform.recordingDriver),
        <String>['remote', 'simctl', 'adb', 'remote', 'remote'],
      );
      expect(
        result.platforms.map((platform) => platform.screenshotArtifactRef),
        everyElement(startsWith('screenshots/')),
      );
      expect(
        result.platforms.first.verifiedCommands,
        <String>[
          'launch-app',
          'read-app',
          'inspect-ui',
          'run-batch',
          'start-recording',
          'stop-recording',
          'wait-idle',
          'read-network',
          'read-errors',
          'read-logs',
          'inspect-surface',
          'capture-screenshot',
          'hot-reload',
          'hot-restart',
        ],
      );
    },
  );

  test('verifier records platform failures and continues by default', () async {
    final verifier = CockpitDemoPlatformVerifier(
      probeDevices: () async => const <CockpitDemoHostDevice>[
        CockpitDemoHostDevice(
          name: 'macOS',
          deviceId: 'macos',
          platform: 'macos',
          emulator: false,
          supported: true,
        ),
      ],
      listIosSimulators: () async => const <CockpitDemoIosSimulator>[],
      runProcess: (executable, arguments, {String? workingDirectory}) async {
        return ProcessResult(0, 0, '', '');
      },
      wait: (_) async {},
      launchApp: (request) async =>
          throw const CockpitApplicationServiceException(
        code: 'launchFailed',
        message: 'Unable to launch the example app.',
      ),
    );

    final result = await verifier.verify(
      const CockpitDemoPlatformVerificationRequest(
        projectDir: '/workspace/examples/cockpit_demo',
        platforms: <String>['macos', 'ios'],
      ),
    );

    expect(result.success, isFalse);
    expect(result.platforms, hasLength(2));
    expect(result.platforms.first.status, 'failed');
    expect(result.platforms.first.failureCode, 'launchFailed');
    expect(result.platforms.last.platform, 'ios');
    expect(result.platforms.last.status, 'failed');
  });

  test('device probe normalizes desktop and android variant target platforms',
      () async {
    final devices = await cockpitDemoProbeHostDevices(
      processRunner: (executable, arguments, {String? workingDirectory}) async {
        expect(executable, 'flutter');
        expect(arguments, const <String>['devices', '--machine']);
        return ProcessResult(
          0,
          0,
          '''
[
  {
    "name": "sdk gphone16k arm64",
    "id": "emulator-5554",
    "isSupported": true,
    "targetPlatform": "android-arm64",
    "emulator": true
  },
  {
    "name": "Linux",
    "id": "linux",
    "isSupported": true,
    "targetPlatform": "linux-x64",
    "emulator": false
  },
  {
    "name": "Windows",
    "id": "windows",
    "isSupported": true,
    "targetPlatform": "windows-x64",
    "emulator": false
  }
]
''',
          '',
        );
      },
    );

    expect(devices, hasLength(3));
    expect(
      devices.map((device) => device.platform),
      <String>['android', 'linux', 'windows'],
    );
    expect(
      devices.map((device) => device.deviceId),
      <String>['emulator-5554', 'linux', 'windows'],
    );
    expect(
      devices.map((device) => device.emulator),
      <bool>[true, false, false],
    );
  });
}

CockpitAppHandle _appForPlatform({
  required String platform,
  required String deviceId,
  required String baseUrl,
}) {
  return CockpitAppHandle(
    appId: 'dev.cockpit.cockpit_demo.$platform',
    mode: CockpitAppMode.development,
    platform: platform,
    deviceId: deviceId,
    projectDir: '/workspace/examples/cockpit_demo',
    target: 'cockpit/main.dart',
    baseUrl: baseUrl,
    launchedAt: DateTime.utc(2026, 4, 11),
  );
}

final class _FakeRecordingAdapter implements CockpitRecordingAdapter {
  const _FakeRecordingAdapter({
    required this.onStart,
    required this.onStop,
  });

  final Future<CockpitRecordingSession> Function(
      CockpitRecordingRequest request) onStart;
  final Future<CockpitRecordingResult> Function() onStop;

  @override
  Future<CockpitRecordingSession> startRecording(
    CockpitRecordingRequest request,
  ) {
    return onStart(request);
  }

  @override
  Future<CockpitRecordingResult> stopRecording() {
    return onStop();
  }
}

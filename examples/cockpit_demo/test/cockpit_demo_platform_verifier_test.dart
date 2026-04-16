import 'dart:io';

import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_cockpit_devtools/flutter_cockpit_devtools.dart';
import 'package:flutter_test/flutter_test.dart';

import '../tool/src/cockpit_demo_platform_verifier.dart';

void main() {
  test('default project dir resolves cockpit_demo when invoked from repo root',
      () {
    expect(
      cockpitDemoDefaultProjectDir(
        scriptPath:
            '/workspace/flutter_cockpit/examples/cockpit_demo/tool/verify_platforms.dart',
        currentDirectory: '/workspace/flutter_cockpit',
      ),
      '/workspace/flutter_cockpit/examples/cockpit_demo',
    );
  });

  test('default project dir keeps the example directory when already inside it',
      () {
    expect(
      cockpitDemoDefaultProjectDir(
        scriptPath:
            '/workspace/flutter_cockpit/examples/cockpit_demo/tool/verify_platforms.dart',
        currentDirectory: '/workspace/flutter_cockpit/examples/cockpit_demo',
      ),
      '/workspace/flutter_cockpit/examples/cockpit_demo',
    );
  });

  test(
      'recording driver resolves iOS simulator and physical devices truthfully',
      () {
    expect(
      cockpitDemoRecordingDriverForPlatform(
        platform: 'ios',
        deviceId: '6FD25DED-11E9-4AE9-B4B5-EDF4601981DC',
      ),
      'simctl',
    );
    expect(
      cockpitDemoRecordingDriverForPlatform(
        platform: 'ios',
        deviceId: '00008110-0009341C2EF3801E',
      ),
      'remote',
    );
  });

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
                const CockpitDemoHostDevice(
                  name: 'Chrome',
                  deviceId: 'chrome',
                  platform: 'web',
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
                const CockpitDemoHostDevice(
                  name: 'Chrome',
                  deviceId: 'chrome',
                  platform: 'web',
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
                const CockpitDemoHostDevice(
                  name: 'Chrome',
                  deviceId: 'chrome',
                  platform: 'web',
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
                const CockpitDemoHostDevice(
                  name: 'Chrome',
                  deviceId: 'chrome',
                  platform: 'web',
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
                const CockpitDemoHostDevice(
                  name: 'Chrome',
                  deviceId: 'chrome',
                  platform: 'web',
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
          platforms: <String>[
            'macos',
            'ios',
            'android',
            'linux',
            'windows',
            'web'
          ],
          outputRoot: '/tmp/cockpit_demo_platforms',
        ),
      );

      expect(result.success, isTrue);
      expect(
        result.platforms.map((platform) => platform.platform),
        <String>['macos', 'ios', 'android', 'linux', 'windows', 'web'],
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
          'chrome',
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
            CockpitCommandType.tap,
            CockpitCommandType.scrollUntilVisible,
            CockpitCommandType.captureScreenshot,
          ]),
        ),
      );
      expect(commandTypes.length, 36);
      final expectedBatchPattern = <CockpitCommandType>[
        CockpitCommandType.tap,
        CockpitCommandType.enterText,
        CockpitCommandType.scrollUntilVisible,
        CockpitCommandType.tap,
        CockpitCommandType.enterText,
        CockpitCommandType.tap,
      ];
      expect(
        batchedCommandTypes
            .take(expectedBatchPattern.length)
            .toList(growable: false),
        expectedBatchPattern,
      );
      expect(
        batchedCommandTypes,
        containsAll(<CockpitCommandType>[
          CockpitCommandType.scrollUntilVisible,
          CockpitCommandType.waitFor,
        ]),
      );
      expect(batchedCommandTypes.length, 168);
      expect(batchRequests, hasLength(30));
      final firstBatchCommands = batchRequests.first.commands
          .map((batchCommand) => batchCommand.command)
          .toList(growable: false);
      expect(firstBatchCommands[0].locator?.text, 'New task');
      expect(firstBatchCommands[0].locator?.ancestor?.route, '/inbox');
      expect(firstBatchCommands[1].locator?.text, 'Task title');
      expect(firstBatchCommands[1].locator?.type, isNull);
      expect(firstBatchCommands[1].locator?.ancestor?.route, '/editor');
      expect(firstBatchCommands[2].commandId, 'verify-reveal-task-notes');
      expect(
        firstBatchCommands[2].commandType,
        CockpitCommandType.scrollUntilVisible,
      );
      expect(firstBatchCommands[2].locator?.text, 'Notes');
      expect(firstBatchCommands[2].locator?.route, '/editor');
      expect(firstBatchCommands[2].locator?.ancestor?.route, '/editor');
      expect(firstBatchCommands[3].commandId, 'verify-focus-task-notes');
      expect(firstBatchCommands[3].locator?.text, 'Notes');
      expect(firstBatchCommands[3].locator?.type, isNull);
      expect(firstBatchCommands[3].locator?.ancestor?.route, '/editor');
      expect(firstBatchCommands[4].commandId, 'verify-enter-task-notes');
      expect(firstBatchCommands[4].locator?.text, 'Notes');
      expect(firstBatchCommands[4].locator?.type, 'TextField');
      expect(firstBatchCommands[4].locator?.ancestor?.route, '/editor');
      expect(firstBatchCommands[5].locator?.text, 'Save task');
      expect(firstBatchCommands[5].locator?.ancestor?.route, '/editor');
      expect(firstBatchCommands[5].commandId, 'verify-save-task');
      final syncLabBatchCommands = batchRequests[1]
          .commands
          .map((batchCommand) => batchCommand.command.commandId)
          .toList(growable: false);
      expect(
        syncLabBatchCommands,
        <String>[
          'verify-open-sync-settings',
          'verify-scroll-run-queued-sync',
          'verify-run-queued-sync',
          'verify-wait-for-conflicted-sync-state',
          'verify-close-settings',
        ],
      );
      final syncLabOpenConflictCommands = batchRequests[2]
          .commands
          .map((batchCommand) => batchCommand.command.commandId)
          .toList(growable: false);
      expect(
        syncLabOpenConflictCommands,
        <String>[
          'verify-search-created-task',
          'verify-wait-for-created-task-search-results',
          'verify-open-created-task',
          'verify-wait-for-detail-route',
          'verify-reveal-conflict-resolution',
          'verify-open-conflict-resolution',
        ],
      );
      final syncLabRecoveryCommands = batchRequests[3]
          .commands
          .map((batchCommand) => batchCommand.command.commandId)
          .toList(growable: false);
      expect(
        syncLabRecoveryCommands,
        <String>[
          'verify-return-from-detail',
          'verify-open-sync-settings',
          'verify-scroll-run-queued-sync',
          'verify-run-queued-sync',
          'verify-wait-for-synced-state',
          'verify-close-settings',
        ],
      );
      final syncLabRecoveryVerificationCommands = batchRequests[4]
          .commands
          .map((batchCommand) => batchCommand.command.commandId)
          .toList(growable: false);
      expect(
        syncLabRecoveryVerificationCommands,
        <String>[
          'verify-search-created-task-after-recovery',
          'verify-wait-for-created-task-search-results-after-recovery',
          'verify-open-created-task-after-recovery',
          'verify-wait-for-detail-route-after-recovery',
          'verify-assert-task-synced',
        ],
      );
      expect(inspectUiRequests, hasLength(6));
      expect(waitIdleRequests, hasLength(12));
      expect(readNetworkRequests, hasLength(6));
      expect(readErrorsRequests, hasLength(6));
      expect(readLogsRequests, hasLength(6));
      expect(
        recordingResolverPlatforms,
        <String>['macos', 'ios', 'android', 'linux', 'windows', 'web'],
      );
      expect(recordingRequests, hasLength(6));
      expect(recordingStopCount, 6);
      expect(hotRestartRequests, hasLength(6));
      expect(stopRequests, hasLength(6));
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
        everyElement(28),
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
        <String>['remote', 'simctl', 'adb', 'remote', 'remote', 'browser-host'],
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
          'sync_lab_conflict_recovery',
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

  test('verifier records sync lab conflict recovery evidence', () async {
    var currentRoute = '/inbox';
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
      launchApp: (request) async {
        return CockpitLaunchAppResult(
          app: _appForPlatform(
            platform: request.platform,
            deviceId: request.deviceId,
            baseUrl: 'http://127.0.0.1:${request.sessionPort}',
          ),
          appJsonPath: '/tmp/${request.platform}/app.json',
        );
      },
      readApp: (request) async {
        final app = request.app!;
        return CockpitReadAppResult(
          sessionId: '${app.platform}-session',
          transportType: 'remoteHttp',
          capabilities: CockpitCapabilities(
            platform: app.platform,
            transportType: 'remoteHttp',
            supportsInAppControl: true,
            supportsFlutterViewCapture: true,
            supportsNativeScreenCapture: true,
            supportsHostAutomation: true,
            supportedCommands: const <CockpitCommandType>[
              CockpitCommandType.tap,
              CockpitCommandType.enterText,
              CockpitCommandType.assertText,
            ],
            supportedLocatorStrategies: CockpitLocatorKind.values,
          ),
          recordingCapabilities: CockpitRecordingCapabilities(
            supportsNativeRecording: true,
            preferredAcceptanceRecordingKind: CockpitRecordingKind.nativeScreen,
          ),
          currentRouteName: currentRoute,
        );
      },
      runCommand: (request) async {
        if (request.command.commandId == 'verify-keep-local-resolution') {
          currentRoute = '/detail';
        }
        if (request.command.commandId ==
            'verify-return-from-detail-after-recovery') {
          currentRoute = '/inbox';
        }
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
      runBatch: (request) async {
        for (final batchCommand in request.commands) {
          switch (batchCommand.command.commandId) {
            case 'verify-open-editor':
              currentRoute = '/editor';
            case 'verify-save-task':
              currentRoute = '/inbox';
            case 'verify-open-sync-settings':
              currentRoute = '/settings';
            case 'verify-close-settings':
              currentRoute = '/inbox';
            case 'verify-open-created-task':
            case 'verify-open-created-task-after-recovery':
              currentRoute = '/detail';
            case 'verify-open-conflict-resolution':
              currentRoute = '/sync-conflict';
          }
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
      inspectUi: (request) async {
        return CockpitInspectUiResult(
          routeName: currentRoute,
          diagnosticLevel: 'investigate',
          truncated: false,
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
          routeName: currentRoute,
          diagnosticLevel: 'inspect',
          truncated: false,
        );
      },
      waitIdle: (request) async => const CockpitWaitIdleResult(
        idle: true,
        durationMs: 120,
        quietWindowMs: 120,
        timeoutMs: 5000,
        includeNetworkIdle: true,
      ),
      readNetwork: (request) async => CockpitReadNetworkResult(
        appId: 'network-app',
        source: 'app_snapshot',
        available: true,
        routeName: currentRoute,
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
      ),
      readErrors: (request) async => const CockpitReadErrorsResult(
        appId: 'errors-app',
        routeName: '/inbox',
        source: 'app_snapshot',
        errors: <CockpitErrorEntry>[],
      ),
      readLogs: (request) async => const CockpitReadLogsResult(
        appId: 'logs-app',
        source: 'app_snapshot',
        available: true,
        routeName: '/inbox',
        lines: <String>['info runtime: sync lab loop settled'],
        truncated: false,
      ),
      recordingAdapterResolver: ({
        required platform,
        required deviceId,
        required client,
        required recording,
      }) {
        return _FakeRecordingAdapter(
          onStart: (request) async => CockpitRecordingSession(
            request: request,
            state: CockpitRecordingState.recording,
          ),
          onStop: () async => CockpitRecordingResult(
            state: CockpitRecordingState.completed,
            purpose: CockpitRecordingPurpose.acceptance,
            recordingKind: CockpitRecordingKind.nativeScreen,
            artifact: const CockpitArtifactRef(
              role: 'recording',
              relativePath: 'recordings/platform-loop.mp4',
            ),
            durationMs: 1600,
            sourceFilePath: '/tmp/platform-loop.mp4',
          ),
        );
      },
      hotReload: (request) async => CockpitHotReloadResult(
        app: request.app!,
        status: CockpitDevelopmentSessionStatus(
          developmentSessionId: 'sync-lab-session',
          state: CockpitDevelopmentSessionState.ready,
          appReachable: true,
          remoteSessionReachable: true,
          reloadGeneration: 1,
          lastReloadMode: CockpitDevelopmentReloadMode.hotReload,
          lastReloadSucceeded: true,
          lastStatusAt: DateTime.utc(2026, 4, 12),
        ),
      ),
      hotRestart: (request) async => CockpitHotRestartResult(
        app: request.app!,
        status: CockpitDevelopmentSessionStatus(
          developmentSessionId: 'sync-lab-session',
          state: CockpitDevelopmentSessionState.ready,
          appReachable: true,
          remoteSessionReachable: true,
          reloadGeneration: 2,
          lastReloadMode: CockpitDevelopmentReloadMode.hotRestart,
          lastReloadSucceeded: true,
          lastStatusAt: DateTime.utc(2026, 4, 12, 0, 0, 1),
        ),
      ),
      stopApp: (request) async => CockpitStopAppResult(
        app: request.app!,
        status: CockpitAppStopStatus.stopped(mode: request.app!.mode),
      ),
    );

    final result = await verifier.verify(
      const CockpitDemoPlatformVerificationRequest(
        projectDir: '/workspace/examples/cockpit_demo',
        platforms: <String>['macos'],
        outputRoot: '/tmp/cockpit_demo_platforms',
      ),
    );

    expect(result.success, isTrue);
    expect(result.platforms, hasLength(1));
    expect(
      result.platforms.single.verifiedCommands,
      contains('sync_lab_conflict_recovery'),
    );
    expect(result.platforms.single.inspectRouteName, '/sync-conflict');
  });

  test('verifier retries transient remote unavailability during validation',
      () async {
    var currentRoute = '/inbox';
    var assertNewTaskAttempts = 0;
    var createBatchAttempts = 0;
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
      launchApp: (request) async {
        return CockpitLaunchAppResult(
          app: _appForPlatform(
            platform: request.platform,
            deviceId: request.deviceId,
            baseUrl: 'http://127.0.0.1:${request.sessionPort}',
          ),
          appJsonPath: '/tmp/${request.platform}/app.json',
        );
      },
      readApp: (request) async {
        final app = request.app!;
        return CockpitReadAppResult(
          sessionId: '${app.platform}-session',
          transportType: 'remoteHttp',
          capabilities: CockpitCapabilities(
            platform: app.platform,
            transportType: 'remoteHttp',
            supportsInAppControl: true,
            supportsFlutterViewCapture: true,
            supportsNativeScreenCapture: true,
            supportsHostAutomation: true,
            supportedCommands: const <CockpitCommandType>[
              CockpitCommandType.tap,
              CockpitCommandType.enterText,
              CockpitCommandType.assertText,
              CockpitCommandType.captureScreenshot,
            ],
            supportedLocatorStrategies: CockpitLocatorKind.values,
          ),
          recordingCapabilities: CockpitRecordingCapabilities(
            supportsNativeRecording: true,
            preferredAcceptanceRecordingKind: CockpitRecordingKind.nativeScreen,
          ),
          currentRouteName: currentRoute,
        );
      },
      runCommand: (request) async {
        if (request.command.commandId == 'verify-macos-assert-new-task') {
          assertNewTaskAttempts += 1;
          if (assertNewTaskAttempts == 1) {
            throw const CockpitApplicationServiceException(
              code: 'remoteUnavailable',
              message: 'Remote session is temporarily unavailable.',
            );
          }
        }
        if (request.command.commandId == 'verify-keep-local-resolution') {
          currentRoute = '/detail';
        }
        if (request.command.commandId ==
            'verify-return-from-detail-after-recovery') {
          currentRoute = '/inbox';
        }
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
      runBatch: (request) async {
        if (request.commands.isNotEmpty &&
            request.commands.first.command.commandId == 'verify-open-editor') {
          createBatchAttempts += 1;
          if (createBatchAttempts == 1) {
            throw const CockpitApplicationServiceException(
              code: 'remoteUnavailable',
              message: 'Remote session is temporarily unavailable.',
            );
          }
        }
        for (final batchCommand in request.commands) {
          switch (batchCommand.command.commandId) {
            case 'verify-open-editor':
              currentRoute = '/editor';
            case 'verify-save-task':
              currentRoute = '/inbox';
            case 'verify-open-sync-settings':
              currentRoute = '/settings';
            case 'verify-close-settings':
              currentRoute = '/inbox';
            case 'verify-open-created-task':
            case 'verify-open-created-task-after-recovery':
              currentRoute = '/detail';
            case 'verify-open-conflict-resolution':
              currentRoute = '/sync-conflict';
          }
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
      inspectUi: (request) async => CockpitInspectUiResult(
        routeName: currentRoute,
        diagnosticLevel: 'investigate',
        truncated: false,
      ),
      inspectSurface: (request) async => CockpitInspectSurfaceResult(
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
        routeName: currentRoute,
        diagnosticLevel: 'inspect',
        truncated: false,
      ),
      waitIdle: (request) async => const CockpitWaitIdleResult(
        idle: true,
        durationMs: 120,
        quietWindowMs: 120,
        timeoutMs: 5000,
        includeNetworkIdle: true,
      ),
      readNetwork: (request) async => CockpitReadNetworkResult(
        appId: 'network-app',
        source: 'app_snapshot',
        available: true,
        routeName: currentRoute,
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
      ),
      readErrors: (request) async => const CockpitReadErrorsResult(
        appId: 'errors-app',
        routeName: '/inbox',
        source: 'app_snapshot',
        errors: <CockpitErrorEntry>[],
      ),
      readLogs: (request) async => const CockpitReadLogsResult(
        appId: 'logs-app',
        source: 'app_snapshot',
        available: true,
        routeName: '/inbox',
        lines: <String>['info runtime: retry path settled'],
        truncated: false,
      ),
      recordingAdapterResolver: ({
        required platform,
        required deviceId,
        required client,
        required recording,
      }) {
        return _FakeRecordingAdapter(
          onStart: (request) async => CockpitRecordingSession(
            request: request,
            state: CockpitRecordingState.recording,
          ),
          onStop: () async => CockpitRecordingResult(
            state: CockpitRecordingState.completed,
            purpose: CockpitRecordingPurpose.acceptance,
            recordingKind: CockpitRecordingKind.nativeScreen,
            artifact: const CockpitArtifactRef(
              role: 'recording',
              relativePath: 'recordings/platform-loop.mp4',
            ),
            durationMs: 1600,
            sourceFilePath: '/tmp/platform-loop.mp4',
          ),
        );
      },
      hotReload: (request) async => CockpitHotReloadResult(
        app: request.app!,
        status: CockpitDevelopmentSessionStatus(
          developmentSessionId: 'retry-session',
          state: CockpitDevelopmentSessionState.ready,
          appReachable: true,
          remoteSessionReachable: true,
          reloadGeneration: 1,
          lastReloadMode: CockpitDevelopmentReloadMode.hotReload,
          lastReloadSucceeded: true,
          lastStatusAt: DateTime.utc(2026, 4, 12),
        ),
      ),
      hotRestart: (request) async => CockpitHotRestartResult(
        app: request.app!,
        status: CockpitDevelopmentSessionStatus(
          developmentSessionId: 'retry-session',
          state: CockpitDevelopmentSessionState.ready,
          appReachable: true,
          remoteSessionReachable: true,
          reloadGeneration: 2,
          lastReloadMode: CockpitDevelopmentReloadMode.hotRestart,
          lastReloadSucceeded: true,
          lastStatusAt: DateTime.utc(2026, 4, 12, 0, 0, 1),
        ),
      ),
      stopApp: (request) async => CockpitStopAppResult(
        app: request.app!,
        status: CockpitAppStopStatus.stopped(mode: request.app!.mode),
      ),
    );

    final result = await verifier.verify(
      const CockpitDemoPlatformVerificationRequest(
        projectDir: '/workspace/examples/cockpit_demo',
        platforms: <String>['macos'],
        outputRoot: '/tmp/cockpit_demo_platforms',
      ),
    );

    expect(result.success, isTrue);
    expect(assertNewTaskAttempts, 2);
    expect(createBatchAttempts, 2);
  });

  test('verifier stops an active recording when a later step fails', () async {
    var recordingStopCount = 0;
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
      launchApp: (request) async {
        return CockpitLaunchAppResult(
          app: _appForPlatform(
            platform: request.platform,
            deviceId: request.deviceId,
            baseUrl: 'http://127.0.0.1:${request.sessionPort}',
          ),
          appJsonPath: '/tmp/${request.platform}/app.json',
        );
      },
      readApp: (request) async {
        final app = request.app!;
        return CockpitReadAppResult(
          sessionId: '${app.platform}-session',
          transportType: 'remoteHttp',
          capabilities: CockpitCapabilities(
            platform: app.platform,
            transportType: 'remoteHttp',
            supportsInAppControl: true,
            supportsFlutterViewCapture: true,
            supportsNativeScreenCapture: true,
            supportsHostAutomation: true,
            supportedCommands: const <CockpitCommandType>[
              CockpitCommandType.tap,
              CockpitCommandType.enterText,
              CockpitCommandType.assertText,
            ],
            supportedLocatorStrategies: CockpitLocatorKind.values,
          ),
          recordingCapabilities: CockpitRecordingCapabilities(
            supportsNativeRecording: true,
            preferredAcceptanceRecordingKind: CockpitRecordingKind.nativeScreen,
          ),
          currentRouteName: '/inbox',
        );
      },
      runCommand: (request) async {
        return CockpitExecuteRemoteCommandResult(
          command: CockpitInteractiveCommandCore(
            commandId: request.command.commandId,
            commandType: request.command.commandType.name,
            success: true,
            durationMs: 12,
            usedCaptureFallback: false,
          ),
          artifacts: const <CockpitInteractiveArtifactDescriptor>[],
        );
      },
      inspectUi: (request) async => const CockpitInspectUiResult(
        routeName: '/inbox',
        diagnosticLevel: 'investigate',
        truncated: false,
      ),
      runBatch: (request) async => CockpitRunBatchResult(
        results: <CockpitExecuteRemoteCommandResult>[
          CockpitExecuteRemoteCommandResult(
            command: CockpitInteractiveCommandCore(
              commandId: request.commands.first.command.commandId,
              commandType: request.commands.first.command.commandType.name,
              success: false,
              durationMs: 12,
              usedCaptureFallback: false,
              error: CockpitCommandError.targetNotFound(
                message: 'Notes field is not visible.',
              ),
            ),
            artifacts: const <CockpitInteractiveArtifactDescriptor>[],
          ),
        ],
        summary: const CockpitExecuteRemoteCommandBatchSummary(
          totalCount: 1,
          successCount: 0,
          failureCount: 1,
          stoppedEarly: true,
        ),
      ),
      recordingAdapterResolver: ({
        required platform,
        required deviceId,
        required client,
        required recording,
      }) {
        return _FakeRecordingAdapter(
          onStart: (request) async => CockpitRecordingSession(
            request: request,
            state: CockpitRecordingState.recording,
          ),
          onStop: () async {
            recordingStopCount += 1;
            return CockpitRecordingResult(
              state: CockpitRecordingState.completed,
              purpose: CockpitRecordingPurpose.acceptance,
              recordingKind: CockpitRecordingKind.nativeScreen,
            );
          },
        );
      },
      stopApp: (request) async => CockpitStopAppResult(
        app: request.app!,
        status: CockpitAppStopStatus.stopped(mode: request.app!.mode),
      ),
    );

    final result = await verifier.verify(
      const CockpitDemoPlatformVerificationRequest(
        projectDir: '/workspace/examples/cockpit_demo',
        platforms: <String>['macos'],
      ),
    );

    expect(result.success, isFalse);
    expect(result.platforms.single.failureCode, 'exampleBatchFailed');
    expect(recordingStopCount, 1);
  });

  test(
    'verifier can continue local web validation when host recording prerequisites are explicitly allowed to fail',
    () async {
      final verifier = CockpitDemoPlatformVerifier(
        probeDevices: () async => const <CockpitDemoHostDevice>[
          CockpitDemoHostDevice(
            name: 'Chrome',
            deviceId: 'chrome',
            platform: 'web',
            emulator: false,
            supported: true,
          ),
        ],
        wait: (_) async {},
        runProcess: (executable, arguments, {String? workingDirectory}) async {
          return ProcessResult(0, 0, '', '');
        },
        launchApp: (request) async {
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
        readApp: (request) async => CockpitReadAppResult(
          sessionId: 'web-session',
          transportType: 'remoteHttp',
          capabilities: CockpitCapabilities(
            platform: 'web',
            transportType: 'remoteHttp',
            supportsInAppControl: true,
            supportsFlutterViewCapture: true,
            supportsNativeScreenCapture: false,
            supportsHostAutomation: false,
            supportedCommands: const <CockpitCommandType>[
              CockpitCommandType.tap,
              CockpitCommandType.enterText,
              CockpitCommandType.assertText,
              CockpitCommandType.captureScreenshot,
            ],
            supportedLocatorStrategies: CockpitLocatorKind.values,
          ),
          recordingCapabilities: CockpitRecordingCapabilities(
            supportsNativeRecording: true,
            preferredAcceptanceRecordingKind: CockpitRecordingKind.nativeScreen,
          ),
          currentRouteName: '/inbox',
        ),
        inspectUi: (_) async => const CockpitInspectUiResult(
          routeName: '/inbox',
          diagnosticLevel: 'investigate',
          truncated: false,
        ),
        runCommand: (request) async => CockpitExecuteRemoteCommandResult(
          command: CockpitInteractiveCommandCore(
            commandId: request.command.commandId,
            commandType: request.command.commandType.name,
            success: true,
            durationMs: 10,
            usedCaptureFallback: false,
          ),
          artifacts: request.command.commandType ==
                  CockpitCommandType.captureScreenshot
              ? const <CockpitInteractiveArtifactDescriptor>[
                  CockpitInteractiveArtifactDescriptor(
                    role: 'screenshot',
                    relativePath: 'screenshots/web-warning-proof.png',
                    byteLength: 512,
                  ),
                ]
              : const <CockpitInteractiveArtifactDescriptor>[],
        ),
        runBatch: (request) async => CockpitRunBatchResult(
          results: request.commands
              .map(
                (batchCommand) => CockpitExecuteRemoteCommandResult(
                  command: CockpitInteractiveCommandCore(
                    commandId: batchCommand.command.commandId,
                    commandType: batchCommand.command.commandType.name,
                    success: true,
                    durationMs: 10,
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
        ),
        waitIdle: (_) async => const CockpitWaitIdleResult(
          idle: true,
          durationMs: 120,
          quietWindowMs: 160,
          timeoutMs: 5000,
          includeNetworkIdle: true,
        ),
        readNetwork: (request) async => CockpitReadNetworkResult(
          appId: 'web-network',
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
        ),
        readErrors: (_) async => const CockpitReadErrorsResult(
          appId: 'web-errors',
          routeName: '/inbox',
          source: 'app_snapshot',
          errors: <CockpitErrorEntry>[],
        ),
        readLogs: (_) async => const CockpitReadLogsResult(
          appId: 'web-logs',
          source: 'app_snapshot',
          available: true,
          routeName: '/inbox',
          lines: <String>['info runtime: web verification warning path'],
          truncated: false,
        ),
        inspectSurface: (request) async => CockpitInspectSurfaceResult(
          target: CockpitTargetHandle.fromAppHandle(request.app!),
          capabilityProfile: CockpitCapabilityProfile(
            targetKind: CockpitTargetKind.browserPage,
            surfaceKinds: <CockpitSurfaceKind>{
              CockpitSurfaceKind.browserDom,
              CockpitSurfaceKind.flutterSemantic,
            },
            actionCapabilities: <CockpitActionCapability>{
              CockpitActionCapability.tap,
              CockpitActionCapability.captureScreenshot,
            },
            evidenceCapabilities: <CockpitEvidenceCapability>{
              CockpitEvidenceCapability.windowCapture,
              CockpitEvidenceCapability.flutterScreenshot,
            },
          ),
          surfaceKind: CockpitSurfaceKind.browserDom,
          selectedPlane: CockpitPlaneKind.flutterSemanticPlane,
          recommendedNextStep: 'continue',
          routeName: '/inbox',
          diagnosticLevel: 'inspect',
          truncated: false,
        ),
        recordingAdapterResolver: ({
          required platform,
          required deviceId,
          required client,
          required recording,
        }) {
          return _FakeRecordingAdapter(
            onStart: (_) async {
              throw StateError(
                'Remote session request failed: 412 {"error":"recordingStartFailed","message":"Screen Recording permission is missing."}',
              );
            },
            onStop: () async => throw StateError('stop should not be called'),
          );
        },
        hotReload: (request) async => CockpitHotReloadResult(
          app: request.app!,
          status: CockpitDevelopmentSessionStatus(
            developmentSessionId: 'web-session',
            state: CockpitDevelopmentSessionState.ready,
            appReachable: true,
            remoteSessionReachable: true,
            reloadGeneration: 1,
            lastReloadMode: CockpitDevelopmentReloadMode.hotReload,
            lastReloadSucceeded: true,
            lastStatusAt: DateTime.utc(2026, 4, 11),
          ),
        ),
        hotRestart: (request) async => CockpitHotRestartResult(
          app: request.app!,
          status: CockpitDevelopmentSessionStatus(
            developmentSessionId: 'web-session',
            state: CockpitDevelopmentSessionState.ready,
            appReachable: true,
            remoteSessionReachable: true,
            reloadGeneration: 2,
            lastReloadMode: CockpitDevelopmentReloadMode.hotRestart,
            lastReloadSucceeded: true,
            lastStatusAt: DateTime.utc(2026, 4, 11, 0, 0, 1),
          ),
        ),
        stopApp: (request) async => CockpitStopAppResult(
          app: request.app!,
          status: CockpitAppStopStatus.stopped(mode: request.app!.mode),
        ),
      );

      final result = await verifier.verify(
        const CockpitDemoPlatformVerificationRequest(
          projectDir: '/workspace/examples/cockpit_demo',
          platforms: <String>['web'],
          allowWebHostRecordingPrerequisiteFailure: true,
        ),
      );

      expect(result.success, isTrue);
      expect(result.platforms, hasLength(1));
      final platform = result.platforms.single;
      expect(platform.status, 'passed');
      expect(platform.recordingArtifactRef, isNull);
      expect(platform.recordingDriver, 'browser-host');
      expect(
        platform.verifiedCommands,
        <String>[
          'launch-app',
          'read-app',
          'inspect-ui',
          'run-batch',
          'wait-idle',
          'sync_lab_conflict_recovery',
          'read-network',
          'read-errors',
          'read-logs',
          'inspect-surface',
          'capture-screenshot',
          'hot-reload',
          'hot-restart',
        ],
      );
      expect(platform.warnings, hasLength(1));
      expect(
        platform.warnings.single,
        contains('Screen Recording permission is missing.'),
      );
    },
  );

  test(
    'verifier can continue local web validation when host recording stop fails as a prerequisite issue',
    () async {
      final verifier = CockpitDemoPlatformVerifier(
        probeDevices: () async => const <CockpitDemoHostDevice>[
          CockpitDemoHostDevice(
            name: 'Chrome',
            deviceId: 'chrome',
            platform: 'web',
            emulator: false,
            supported: true,
          ),
        ],
        wait: (_) async {},
        runProcess: (executable, arguments, {String? workingDirectory}) async {
          return ProcessResult(0, 0, '', '');
        },
        launchApp: (request) async {
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
        readApp: (request) async => CockpitReadAppResult(
          sessionId: 'web-session',
          transportType: 'remoteHttp',
          capabilities: CockpitCapabilities(
            platform: 'web',
            transportType: 'remoteHttp',
            supportsInAppControl: true,
            supportsFlutterViewCapture: true,
            supportsNativeScreenCapture: false,
            supportsHostAutomation: false,
            supportedCommands: const <CockpitCommandType>[
              CockpitCommandType.tap,
              CockpitCommandType.enterText,
              CockpitCommandType.assertText,
              CockpitCommandType.captureScreenshot,
            ],
            supportedLocatorStrategies: CockpitLocatorKind.values,
          ),
          recordingCapabilities: CockpitRecordingCapabilities(
            supportsNativeRecording: true,
            preferredAcceptanceRecordingKind: CockpitRecordingKind.nativeScreen,
          ),
          currentRouteName: '/inbox',
        ),
        inspectUi: (_) async => const CockpitInspectUiResult(
          routeName: '/inbox',
          diagnosticLevel: 'investigate',
          truncated: false,
        ),
        runCommand: (request) async => CockpitExecuteRemoteCommandResult(
          command: CockpitInteractiveCommandCore(
            commandId: request.command.commandId,
            commandType: request.command.commandType.name,
            success: true,
            durationMs: 10,
            usedCaptureFallback: false,
          ),
          artifacts: request.command.commandType ==
                  CockpitCommandType.captureScreenshot
              ? const <CockpitInteractiveArtifactDescriptor>[
                  CockpitInteractiveArtifactDescriptor(
                    role: 'screenshot',
                    relativePath: 'screenshots/web-warning-proof.png',
                    byteLength: 512,
                  ),
                ]
              : const <CockpitInteractiveArtifactDescriptor>[],
        ),
        runBatch: (request) async => CockpitRunBatchResult(
          results: request.commands
              .map(
                (batchCommand) => CockpitExecuteRemoteCommandResult(
                  command: CockpitInteractiveCommandCore(
                    commandId: batchCommand.command.commandId,
                    commandType: batchCommand.command.commandType.name,
                    success: true,
                    durationMs: 10,
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
        ),
        waitIdle: (_) async => const CockpitWaitIdleResult(
          idle: true,
          durationMs: 120,
          quietWindowMs: 160,
          timeoutMs: 5000,
          includeNetworkIdle: true,
        ),
        readNetwork: (request) async => CockpitReadNetworkResult(
          appId: 'web-network',
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
        ),
        readErrors: (_) async => const CockpitReadErrorsResult(
          appId: 'web-errors',
          routeName: '/inbox',
          source: 'app_snapshot',
          errors: <CockpitErrorEntry>[],
        ),
        readLogs: (_) async => const CockpitReadLogsResult(
          appId: 'web-logs',
          source: 'app_snapshot',
          available: true,
          routeName: '/inbox',
          lines: <String>['info runtime: web verification warning path'],
          truncated: false,
        ),
        inspectSurface: (request) async => CockpitInspectSurfaceResult(
          target: CockpitTargetHandle.fromAppHandle(request.app!),
          capabilityProfile: CockpitCapabilityProfile(
            targetKind: CockpitTargetKind.browserPage,
            surfaceKinds: <CockpitSurfaceKind>{
              CockpitSurfaceKind.browserDom,
              CockpitSurfaceKind.flutterSemantic,
            },
            actionCapabilities: <CockpitActionCapability>{
              CockpitActionCapability.tap,
              CockpitActionCapability.captureScreenshot,
            },
            evidenceCapabilities: <CockpitEvidenceCapability>{
              CockpitEvidenceCapability.windowCapture,
              CockpitEvidenceCapability.flutterScreenshot,
            },
          ),
          surfaceKind: CockpitSurfaceKind.browserDom,
          selectedPlane: CockpitPlaneKind.flutterSemanticPlane,
          recommendedNextStep: 'continue',
          routeName: '/inbox',
          diagnosticLevel: 'inspect',
          truncated: false,
        ),
        recordingAdapterResolver: ({
          required platform,
          required deviceId,
          required client,
          required recording,
        }) {
          return _FakeRecordingAdapter(
            onStart: (request) async => CockpitRecordingSession(
              request: request,
              state: CockpitRecordingState.recording,
            ),
            onStop: () async => CockpitRecordingResult(
              state: CockpitRecordingState.failed,
              purpose: CockpitRecordingPurpose.acceptance,
              recordingKind: CockpitRecordingKind.nativeScreen,
              failureReason: 'macOS recording did not stop before timeout.',
            ),
          );
        },
        hotReload: (request) async => CockpitHotReloadResult(
          app: request.app!,
          status: CockpitDevelopmentSessionStatus(
            developmentSessionId: 'web-session',
            state: CockpitDevelopmentSessionState.ready,
            appReachable: true,
            remoteSessionReachable: true,
            reloadGeneration: 1,
            lastReloadMode: CockpitDevelopmentReloadMode.hotReload,
            lastReloadSucceeded: true,
            lastStatusAt: DateTime.utc(2026, 4, 11),
          ),
        ),
        hotRestart: (request) async => CockpitHotRestartResult(
          app: request.app!,
          status: CockpitDevelopmentSessionStatus(
            developmentSessionId: 'web-session',
            state: CockpitDevelopmentSessionState.ready,
            appReachable: true,
            remoteSessionReachable: true,
            reloadGeneration: 2,
            lastReloadMode: CockpitDevelopmentReloadMode.hotRestart,
            lastReloadSucceeded: true,
            lastStatusAt: DateTime.utc(2026, 4, 11, 0, 0, 1),
          ),
        ),
        stopApp: (request) async => CockpitStopAppResult(
          app: request.app!,
          status: CockpitAppStopStatus.stopped(mode: request.app!.mode),
        ),
      );

      final result = await verifier.verify(
        const CockpitDemoPlatformVerificationRequest(
          projectDir: '/workspace/examples/cockpit_demo',
          platforms: <String>['web'],
          allowWebHostRecordingPrerequisiteFailure: true,
        ),
      );

      expect(result.success, isTrue);
      expect(result.platforms, hasLength(1));
      final platform = result.platforms.single;
      expect(platform.status, 'passed');
      expect(platform.recordingArtifactRef, isNull);
      expect(platform.recordingDriver, 'browser-host');
      expect(platform.warnings, hasLength(1));
      expect(
        platform.warnings.single,
        contains('macOS recording did not stop before timeout.'),
      );
    },
  );

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
  },
  {
    "name": "Chrome",
    "id": "chrome",
    "isSupported": true,
    "targetPlatform": "web-javascript",
    "emulator": false
  }
]
''',
          '',
        );
      },
    );

    expect(devices, hasLength(4));
    expect(
      devices.map((device) => device.platform),
      <String>['android', 'linux', 'windows', 'web'],
    );
    expect(
      devices.map((device) => device.deviceId),
      <String>['emulator-5554', 'linux', 'windows', 'chrome'],
    );
    expect(
      devices.map((device) => device.emulator),
      <bool>[true, false, false, false],
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

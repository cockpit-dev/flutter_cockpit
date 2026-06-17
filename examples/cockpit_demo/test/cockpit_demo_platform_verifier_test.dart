import 'dart:convert';
import 'dart:io';

import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:cockpit/cockpit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../tool/src/cockpit_demo_platform_verifier.dart';

var _screenshotArtifactSequence = 0;

void main() {
  test(
    'default project dir resolves cockpit_demo when invoked from repo root',
    () {
      expect(
        cockpitDemoDefaultProjectDir(
          scriptPath:
              '/workspace/flutter_cockpit/examples/cockpit_demo/tool/verify_platforms.dart',
          currentDirectory: '/workspace/flutter_cockpit',
        ),
        '/workspace/flutter_cockpit/examples/cockpit_demo',
      );
    },
  );

  test(
    'default project dir keeps the example directory when already inside it',
    () {
      expect(
        cockpitDemoDefaultProjectDir(
          scriptPath:
              '/workspace/flutter_cockpit/examples/cockpit_demo/tool/verify_platforms.dart',
          currentDirectory: '/workspace/flutter_cockpit/examples/cockpit_demo',
        ),
        '/workspace/flutter_cockpit/examples/cockpit_demo',
      );
    },
  );

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
    },
  );

  test('recording driver resolves desktop host recording truthfully', () {
    expect(
      cockpitDemoRecordingDriverForPlatform(
        platform: 'macos',
        deviceId: 'macos',
      ),
      'macos-host',
    );
    expect(
      cockpitDemoRecordingDriverForPlatform(
        platform: 'linux',
        deviceId: 'linux',
      ),
      'linux-host',
    );
    expect(
      cockpitDemoRecordingDriverForPlatform(
        platform: 'windows',
        deviceId: 'windows',
      ),
      'windows-host',
    );
  });

  test('iOS host does not declare a missing SceneDelegate', () {
    final iosRunnerDir =
        Directory.current.path.endsWith('examples/cockpit_demo')
        ? p.join(Directory.current.path, 'ios', 'Runner')
        : p.join(
            Directory.current.path,
            'examples',
            'cockpit_demo',
            'ios',
            'Runner',
          );
    final infoPlist = File(p.join(iosRunnerDir, 'Info.plist'));

    expect(infoPlist.existsSync(), isTrue);
    final contents = infoPlist.readAsStringSync();

    expect(contents, isNot(contains('UIApplicationSceneManifest')));
    expect(contents, isNot(contains('UISceneDelegateClassName')));
    expect(contents, isNot(contains('FlutterSceneDelegate')));
  });

  test('host device probing uses the platform Flutter executable', () async {
    final invocations = <String>[];

    final devices = await cockpitDemoProbeHostDevices(
      isWindows: true,
      processRunner: (executable, arguments, {String? workingDirectory}) async {
        invocations.add('$executable ${arguments.join(' ')}');
        return ProcessResult(0, 0, '[]', '');
      },
    );

    expect(devices, isEmpty);
    expect(invocations, <String>['flutter.bat devices --machine']);
  });

  test(
    'Android emulator launch uses the platform Flutter executable',
    () async {
      final invocations = <String>[];
      final verifier = CockpitDemoPlatformVerifier(
        describeSystemControl: _fakeDescribeSystemControl,
        runSystemAction: _fakeRunSystemAction,
        probeDevices: () async => const <CockpitDemoHostDevice>[],
        listIosSimulators: () async => const <CockpitDemoIosSimulator>[],
        runProcess: (executable, arguments, {String? workingDirectory}) async {
          invocations.add('$executable ${arguments.join(' ')}');
          return ProcessResult(0, 0, '', '');
        },
        wait: (_) async {},
        isWindows: true,
      );

      final result = await verifier.verify(
        const CockpitDemoPlatformVerificationRequest(
          projectDir: '/workspace/examples/cockpit_demo',
          platforms: <String>['android'],
          deviceTimeout: Duration.zero,
        ),
      );

      expect(result.success, isFalse);
      expect(
        invocations,
        contains('flutter.bat emulators --launch Pixel_9_Pro'),
      );
    },
  );

  test('artifact output paths cannot escape the verifier output root', () {
    expect(
      cockpitDemoResolveArtifactOutputPath(
        outputDir: '/tmp/cockpit_demo_platforms',
        relativePath: 'recordings/proof.mp4',
      ),
      p.normalize('/tmp/cockpit_demo_platforms/recordings/proof.mp4'),
    );
    expect(
      () => cockpitDemoResolveArtifactOutputPath(
        outputDir: '/tmp/cockpit_demo_platforms',
        relativePath: '../proof.mp4',
      ),
      throwsA(
        isA<CockpitApplicationServiceException>().having(
          (error) => error.code,
          'code',
          'invalidArtifactPath',
        ),
      ),
    );
    expect(
      () => cockpitDemoResolveArtifactOutputPath(
        outputDir: '/tmp/cockpit_demo_platforms',
        relativePath: '/tmp/proof.mp4',
      ),
      throwsA(
        isA<CockpitApplicationServiceException>().having(
          (error) => error.code,
          'code',
          'invalidArtifactPath',
        ),
      ),
    );
  });

  test(
    'verifier boots missing mobile targets and validates the development loop',
    () async {
      final recordingFile = await _createRecordingArtifact();
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
      final recordingResolverApps = <CockpitAppHandle>[];
      final recordingRequests = <CockpitRecordingRequest>[];
      final systemActionRequests = <CockpitSystemControlActionRequest>[];
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
          return _successfulCommandResult(
            request.command,
            includeScreenshot:
                request.command.commandType ==
                    CockpitCommandType.captureScreenshot ||
                cockpitCommandTypeIsAiEvidenceKeyOperation(
                  request.command.commandType,
                ),
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
                  (batchCommand) => _successfulCommandResult(
                    batchCommand.command,
                    includeScreenshot:
                        cockpitCommandTypeIsAiEvidenceKeyOperation(
                          batchCommand.command.commandType,
                        ),
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
        recordingAdapterResolver:
            ({
              required platform,
              required deviceId,
              required app,
              required client,
              required recording,
            }) {
              recordingResolverPlatforms.add(platform);
              recordingResolverApps.add(app);
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
                    sourceFilePath: recordingFile.path,
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
            status: CockpitAppStopStatus.stopped(mode: request.app!.mode),
          );
        },
        describeSystemControl: _fakeDescribeSystemControl,
        runSystemAction: (request) async {
          systemActionRequests.add(request);
          return _fakeRunSystemAction(request);
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
            'web',
          ],
          outputRoot: '/tmp/cockpit_demo_platforms',
        ),
      );

      expect(result.success, isTrue);
      expect(result.platforms.map((platform) => platform.platform), <String>[
        'macos',
        'ios',
        'android',
        'linux',
        'windows',
        'web',
      ]);
      expect(
        result.platforms.map((platform) => platform.status),
        everyElement('passed'),
      );
      expect(result.platforms[0].bootstrappedDevice, isFalse);
      expect(result.platforms[1].bootstrappedDevice, isTrue);
      expect(result.platforms[2].bootstrappedDevice, isTrue);
      expect(launchedRequests.map((request) => request.deviceId), <String>[
        'macos',
        'FC5B7D0F-B7FB-4A7A-B1B0-FF28BC289BC2',
        'emulator-5554',
        'linux',
        'windows',
        'chrome',
      ]);
      expect(
        bootCommands,
        contains('xcrun simctl boot FC5B7D0F-B7FB-4A7A-B1B0-FF28BC289BC2'),
      );
      expect(bootCommands, contains('flutter emulators --launch Pixel_9_Pro'));
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
        CockpitCommandType.waitFor,
        CockpitCommandType.waitFor,
        CockpitCommandType.enterText,
        CockpitCommandType.scrollUntilVisible,
        CockpitCommandType.tap,
        CockpitCommandType.enterText,
        CockpitCommandType.tap,
        CockpitCommandType.waitFor,
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
      expect(batchedCommandTypes.length, 192);
      expect(batchRequests, hasLength(30));
      final firstBatchCommands = batchRequests.first.commands
          .map((batchCommand) => batchCommand.command)
          .toList(growable: false);
      expect(firstBatchCommands[0].locator?.key, 'open-task-editor-action');
      expect(firstBatchCommands[0].locator?.text, 'New task');
      expect(firstBatchCommands[0].locator?.type, 'TextButton');
      expect(firstBatchCommands[0].locator?.route, '/inbox');
      expect(firstBatchCommands[0].locator?.ancestor?.route, '/inbox');
      expect(firstBatchCommands[0].parameters['expectedRouteName'], '/editor');
      expect(firstBatchCommands[0].parameters['routeTimeoutMs'], 3000);
      expect(firstBatchCommands[1].commandId, 'verify-wait-for-editor-route');
      expect(firstBatchCommands[1].commandType, CockpitCommandType.waitFor);
      expect(firstBatchCommands[1].parameters['routeName'], '/editor');
      expect(
        firstBatchCommands[1].parameters,
        isNot(contains('requireVisibleTargets')),
      );
      expect(
        firstBatchCommands[2].commandId,
        'verify-wait-for-editor-title-target',
      );
      expect(firstBatchCommands[2].commandType, CockpitCommandType.waitFor);
      expect(firstBatchCommands[2].parameters['text'], 'Task title');
      expect(firstBatchCommands[3].locator?.text, 'Task title');
      expect(firstBatchCommands[3].locator?.type, isNull);
      expect(firstBatchCommands[3].locator?.ancestor?.route, '/editor');
      expect(firstBatchCommands[4].commandId, 'verify-reveal-task-notes');
      expect(
        firstBatchCommands[4].commandType,
        CockpitCommandType.scrollUntilVisible,
      );
      expect(firstBatchCommands[4].locator?.text, 'Notes');
      expect(firstBatchCommands[4].locator?.route, '/editor');
      expect(firstBatchCommands[4].locator?.ancestor?.route, '/editor');
      expect(firstBatchCommands[5].commandId, 'verify-focus-task-notes');
      expect(firstBatchCommands[5].locator?.text, 'Notes');
      expect(firstBatchCommands[5].locator?.type, isNull);
      expect(firstBatchCommands[5].locator?.ancestor?.route, '/editor');
      expect(firstBatchCommands[6].commandId, 'verify-enter-task-notes');
      expect(firstBatchCommands[6].locator?.text, 'Notes');
      expect(firstBatchCommands[6].locator?.type, 'TextField');
      expect(firstBatchCommands[6].locator?.ancestor?.route, '/editor');
      expect(firstBatchCommands[7].locator?.text, 'Save task');
      expect(firstBatchCommands[7].locator?.ancestor?.route, '/editor');
      expect(firstBatchCommands[7].commandId, 'verify-save-task');
      expect(firstBatchCommands[7].parameters['expectedRouteName'], '/inbox');
      expect(firstBatchCommands[7].parameters['routeTimeoutMs'], 3000);
      expect(
        firstBatchCommands[8].commandId,
        'verify-wait-for-inbox-route-after-save',
      );
      expect(firstBatchCommands[8].commandType, CockpitCommandType.waitFor);
      expect(firstBatchCommands[8].parameters['routeName'], '/inbox');
      final syncLabBatchCommands = batchRequests[1].commands
          .map((batchCommand) => batchCommand.command.commandId)
          .toList(growable: false);
      expect(syncLabBatchCommands, <String>[
        'verify-open-sync-settings',
        'verify-scroll-run-queued-sync',
        'verify-run-queued-sync',
        'verify-wait-for-conflicted-sync-state',
        'verify-close-settings',
      ]);
      final syncLabOpenConflictCommands = batchRequests[2].commands
          .map((batchCommand) => batchCommand.command.commandId)
          .toList(growable: false);
      expect(syncLabOpenConflictCommands, <String>[
        'verify-search-created-task',
        'verify-wait-for-created-task-search-results',
        'verify-open-created-task',
        'verify-wait-for-detail-route',
        'verify-reveal-conflict-resolution',
        'verify-open-conflict-resolution',
      ]);
      final syncLabRecoveryCommands = batchRequests[3].commands
          .map((batchCommand) => batchCommand.command.commandId)
          .toList(growable: false);
      expect(syncLabRecoveryCommands, <String>[
        'verify-wait-for-detail-route-after-conflict-resolution',
        'verify-return-from-detail',
        'verify-open-sync-settings',
        'verify-scroll-run-queued-sync-after-recovery',
        'verify-run-queued-sync-after-recovery',
        'verify-wait-for-synced-state',
        'verify-close-settings',
      ]);
      final syncLabRecoveryVerificationCommands = batchRequests[4].commands
          .map((batchCommand) => batchCommand.command.commandId)
          .toList(growable: false);
      expect(syncLabRecoveryVerificationCommands, <String>[
        'verify-search-created-task-after-recovery',
        'verify-wait-for-created-task-search-results-after-recovery',
        'verify-open-created-task-after-recovery',
        'verify-wait-for-detail-route-after-recovery',
        'verify-assert-task-synced',
      ]);
      expect(inspectUiRequests, hasLength(6));
      expect(waitIdleRequests, hasLength(12));
      expect(readNetworkRequests, hasLength(6));
      expect(readErrorsRequests, hasLength(6));
      expect(readLogsRequests, hasLength(6));
      expect(recordingResolverPlatforms, <String>[
        'macos',
        'ios',
        'android',
        'linux',
        'windows',
        'web',
      ]);
      expect(
        recordingResolverApps.map((app) => app.platform),
        recordingResolverPlatforms,
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
        everyElement(32),
      );
      expect(
        result.platforms.map((platform) => platform.autoScreenshotCount),
        everyElement(greaterThanOrEqualTo(19)),
      );
      expect(
        result.platforms.map((platform) => platform.exportedScreenshotCount),
        everyElement(greaterThanOrEqualTo(19)),
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
        result.platforms.map((platform) => platform.recordingOutputPath),
        everyElement(isNotNull),
      );
      expect(
        result.platforms.map((platform) => platform.screenshotByteLength),
        everyElement(greaterThan(0)),
      );
      expect(
        result.platforms.map((platform) => platform.screenshotOutputPath),
        everyElement(isNotNull),
      );
      expect(
        result.platforms.map((platform) => platform.recordingDriver),
        <String>[
          'macos-host',
          'simctl',
          'adb',
          'linux-host',
          'windows-host',
          'browser-host',
        ],
      );
      expect(
        result.platforms.map((platform) => platform.systemControlAdapter),
        <String>[
          'macos.accessibility+screencapture',
          'ios.simctl+xctest',
          'android.adb',
          'linux.at-spi+x11+portal',
          'windows.uia+sendinput',
          'browser.dom+host-recording',
        ],
      );
      expect(
        result.platforms.map((platform) => platform.systemVerifiedActions),
        <List<String>>[
          <String>['readSystemState', 'readProcessList'],
          <String>[
            'readSystemState',
            'readProcessList',
            'setStatusBar',
            'clearStatusBar',
            'setClipboard',
            'getClipboard',
          ],
          <String>[
            'readSystemState',
            'readProcessList',
            'setNetworkSpeed',
            'setNetworkDelay',
          ],
          <String>['readSystemState', 'readProcessList'],
          <String>['readSystemState', 'readProcessList'],
          <String>[],
        ],
      );
      expect(
        systemActionRequests.map((request) => request.action.name),
        <String>[
          'readSystemState',
          'readProcessList',
          'readSystemState',
          'readProcessList',
          'setStatusBar',
          'clearStatusBar',
          'setClipboard',
          'getClipboard',
          'readSystemState',
          'readProcessList',
          'setNetworkSpeed',
          'setNetworkDelay',
          'readSystemState',
          'readProcessList',
          'readSystemState',
          'readProcessList',
        ],
      );
      expect(
        result.platforms.map((platform) => platform.screenshotArtifactRef),
        everyElement(startsWith('screenshots/')),
      );
      expect(result.platforms.first.verifiedCommands, <String>[
        'launch-app',
        'read-app',
        'inspect-ui',
        'read-system-capabilities',
        'run-system-action:readSystemState',
        'run-system-action:readProcessList',
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
      ]);
    },
  );

  test(
    'verifier emits AI-readable progress events for long platform runs',
    () async {
      final progressEvents = <CockpitDemoVerificationProgressEvent>[];

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
        launchApp: (_) async => throw StateError('simulated launch stall'),
        clock: () => DateTime.utc(2026, 5, 24, 12),
      );

      final result = await verifier.verify(
        CockpitDemoPlatformVerificationRequest(
          projectDir: '/workspace/examples/cockpit_demo',
          platforms: const <String>['macos'],
          progressSink: progressEvents.add,
        ),
      );

      expect(result.success, isFalse);
      expect(progressEvents.map((event) => event.stage), <String>[
        'device',
        'device',
        'cleanup',
        'launch',
        'failed',
      ]);
      expect(result.platforms.single.failureMessage, contains('launch stall'));
      expect(progressEvents.first.toAiLine(), contains('platform=macos'));
      expect(progressEvents.first.toAiLine(), contains('stage=device'));
      expect(
        progressEvents.last.toAiLine(),
        contains('simulated launch stall'),
      );
    },
  );

  test(
    'exhaustive system control file probes use existing safe paths',
    () async {
      final tempRoot = await Directory.systemTemp.createTemp(
        'cockpit_demo_exhaustive_probe_test_',
      );
      final systemActionRequests = <CockpitSystemControlActionRequest>[];
      final verifier = await _createSinglePlatformVerifier(
        platform: 'macos',
        deviceId: 'macos',
        runSystemAction: (request) async {
          systemActionRequests.add(request);
          if (request.action == CockpitSystemControlAction.pushFile ||
              request.action == CockpitSystemControlAction.pullFile ||
              request.action == CockpitSystemControlAction.addMedia) {
            final sourcePath = request.parameters['sourcePath'] as String?;
            if (sourcePath == null || !File(sourcePath).existsSync()) {
              return CockpitSystemControlActionResult(
                platform: request.platform,
                deviceId: request.deviceId,
                appId: request.appId,
                processId: request.processId,
                action: request.action,
                availability: CockpitSystemControlAvailability.available,
                success: false,
                recommendedNextStep: 'inspectProbeSource',
                errorCode: 'missingProbeSource',
                errorMessage: 'Probe source does not exist: $sourcePath',
              );
            }
          }
          return _fakeRunSystemAction(request);
        },
      );

      final result = await verifier.verify(
        CockpitDemoPlatformVerificationRequest(
          projectDir: '/workspace/examples/cockpit_demo',
          platforms: const <String>['macos'],
          outputRoot: tempRoot.path,
          exhaustiveSystemControl: true,
        ),
      );

      expect(result.success, isTrue);
      final requestsByAction =
          <CockpitSystemControlAction, CockpitSystemControlActionRequest>{
            for (final request in systemActionRequests) request.action: request,
          };
      expect(
        requestsByAction.keys,
        containsAll(<CockpitSystemControlAction>[
          CockpitSystemControlAction.pushFile,
          CockpitSystemControlAction.pullFile,
          CockpitSystemControlAction.addMedia,
        ]),
      );
      expect(
        requestsByAction[CockpitSystemControlAction.pushFile]!
            .parameters['sourcePath'],
        startsWith(p.join(tempRoot.path, 'macos', 'system-control-probes')),
      );
      expect(
        File(
          requestsByAction[CockpitSystemControlAction.pullFile]!
                  .parameters['sourcePath']
              as String,
        ).existsSync(),
        isTrue,
      );
      expect(
        requestsByAction[CockpitSystemControlAction.pullFile]!
            .parameters['destinationPath'],
        startsWith(p.join(tempRoot.path, 'macos', 'system-control-probes')),
      );
      expect(
        File(
          requestsByAction[CockpitSystemControlAction.addMedia]!
                  .parameters['sourcePath']
              as String,
        ).existsSync(),
        isTrue,
      );
    },
  );

  test('platform verification JSON preserves empty system action arrays', () {
    final json = const CockpitDemoPlatformVerification(
      platform: 'web',
      status: 'passed',
      deviceId: 'chrome',
      bootstrappedDevice: false,
      outputDir: '/tmp/web',
      systemControlAdapter: 'browser.dom+host-recording',
    ).toJson();

    expect(json, containsPair('systemAvailableActions', <String>[]));
    expect(json, containsPair('systemVerifiedActions', <String>[]));
  });

  test('iOS exhaustive media probes use an extended action timeout', () async {
    final systemActionRequests = <CockpitSystemControlActionRequest>[];
    final verifier = await _createSinglePlatformVerifier(
      platform: 'ios',
      deviceId: '87639670-FE4D-446D-9245-5324E0D50184',
      runSystemAction: (request) async {
        systemActionRequests.add(request);
        return _fakeRunSystemAction(request);
      },
    );

    final result = await verifier.verify(
      CockpitDemoPlatformVerificationRequest(
        projectDir: '/workspace/examples/cockpit_demo',
        platforms: const <String>['ios'],
        outputRoot: Directory.systemTemp
            .createTempSync('cockpit_demo_ios_probe_test_')
            .path,
        exhaustiveSystemControl: true,
      ),
    );

    expect(result.success, isTrue, reason: jsonEncode(result.toJson()));
    final addMediaRequest = systemActionRequests.singleWhere(
      (request) => request.action == CockpitSystemControlAction.addMedia,
    );
    expect(addMediaRequest.timeout, greaterThan(const Duration(seconds: 15)));
  });

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

  test('verifier includes launch supervisor diagnostics on failures', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'cockpit-demo-platform-failure-',
    );
    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });
    final supervisorLog = File(p.join(tempDir.path, 'supervisor.log'));
    await supervisorLog.writeAsString(
      '[2026-05-23T18:17:57Z] machine stderr Xcode build failed\n'
      '[2026-05-23T18:17:58Z] remote launch failed error=flutter run exited\n',
    );

    final verifier = CockpitDemoPlatformVerifier(
      probeDevices: () async => const <CockpitDemoHostDevice>[
        CockpitDemoHostDevice(
          name: 'iPhone 17 Pro',
          deviceId: '43E53626-61CA-4382-B395-F661DED6625D',
          platform: 'ios',
          emulator: true,
          supported: true,
        ),
      ],
      listIosSimulators: () async => const <CockpitDemoIosSimulator>[],
      runProcess: (executable, arguments, {String? workingDirectory}) async =>
          ProcessResult(0, 0, '', ''),
      wait: (_) async {},
      launchApp: (request) async => throw CockpitApplicationServiceException(
        code: 'launchFailed',
        message: 'Unable to launch the example app.',
        details: <String, Object?>{'supervisorLogPath': supervisorLog.path},
      ),
    );

    final result = await verifier.verify(
      CockpitDemoPlatformVerificationRequest(
        projectDir: '/workspace/examples/cockpit_demo',
        platforms: const <String>['ios'],
        outputRoot: tempDir.path,
      ),
    );

    final failed = result.platforms.single;
    expect(failed.failureCode, 'launchFailed');
    expect(
      failed.failureDetails,
      containsPair('supervisorLogPath', supervisorLog.path),
    );
    expect(
      failed.failureDetails,
      containsPair('supervisorLogTail', contains('Xcode build failed')),
    );
  });

  test(
    'verifier extracts supervisor diagnostics from unstructured launch failures',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit-demo-platform-unstructured-failure-',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });
      final supervisorLog = File(p.join(tempDir.path, 'supervisor.log'));
      await supervisorLog.writeAsString(
        '[2026-05-29T03:55:14Z] machine progress Building Windows application...\n'
        '[2026-05-29T03:56:12Z] machine stderr Windows toolchain failed\n',
      );

      final verifier = CockpitDemoPlatformVerifier(
        describeSystemControl: _fakeDescribeSystemControl,
        runSystemAction: _fakeRunSystemAction,
        probeDevices: () async => const <CockpitDemoHostDevice>[
          CockpitDemoHostDevice(
            name: 'Windows',
            deviceId: 'windows',
            platform: 'windows',
            emulator: false,
            supported: true,
          ),
        ],
        listIosSimulators: () async => const <CockpitDemoIosSimulator>[],
        runProcess: (executable, arguments, {String? workingDirectory}) async {
          return ProcessResult(0, 0, '', '');
        },
        wait: (_) async {},
        launchApp: (_) async => throw StateError(
          'Development session startup failed: SocketException: '
          'The remote computer refused the network connection. '
          '{supervisorLogPath: ${supervisorLog.path}}',
        ),
      );

      final result = await verifier.verify(
        CockpitDemoPlatformVerificationRequest(
          projectDir: '/workspace/examples/cockpit_demo',
          platforms: const <String>['windows'],
          outputRoot: tempDir.path,
        ),
      );

      final failed = result.platforms.single;
      expect(failed.failureCode, 'StateError');
      expect(
        failed.failureDetails,
        containsPair('supervisorLogPath', supervisorLog.path),
      );
      expect(
        failed.failureDetails,
        containsPair('supervisorLogTail', contains('Windows toolchain failed')),
      );
    },
  );

  test('local state cleanup resets Android app data before launch', () async {
    final invocations = <String>[];

    await cockpitDemoCleanupExampleLocalState(
      platform: 'android',
      deviceId: 'emulator-5554',
      workingDirectory: '/workspace/examples/cockpit_demo',
      processRunner: (executable, arguments, {String? workingDirectory}) async {
        invocations.add('$executable ${arguments.join(' ')}');
        return ProcessResult(0, 0, '', '');
      },
    );

    expect(invocations, <String>[
      'adb -s emulator-5554 shell am force-stop dev.cockpit.cockpit_demo',
      'adb -s emulator-5554 shell pm clear dev.cockpit.cockpit_demo',
      'adb -s emulator-5554 shell run-as dev.cockpit.cockpit_demo rm -f app_flutter/cockpit_demo.sqlite app_flutter/cockpit_demo.sqlite-shm app_flutter/cockpit_demo.sqlite-wal',
    ]);
  });

  test(
    'local state cleanup clears current and legacy iOS simulator bundle ids',
    () async {
      final root = await Directory.systemTemp.createTemp('cockpit-ios-state-');
      addTearDown(() async {
        if (root.existsSync()) {
          await root.delete(recursive: true);
        }
      });
      final currentContainer = Directory(p.join(root.path, 'current'));
      final legacyContainer = Directory(p.join(root.path, 'legacy'));
      await currentContainer.create(recursive: true);
      await legacyContainer.create(recursive: true);
      await _createDatabaseArtifacts(currentContainer.path);
      await _createDatabaseArtifacts(legacyContainer.path);

      final requestedBundleIds = <String>[];
      await cockpitDemoCleanupExampleLocalState(
        platform: 'ios',
        deviceId: 'ios-simulator',
        workingDirectory: '/workspace/examples/cockpit_demo',
        processRunner:
            (executable, arguments, {String? workingDirectory}) async {
              expect(executable, 'xcrun');
              requestedBundleIds.add(arguments[3]);
              final bundleId = arguments[3];
              final containerPath =
                  bundleId == 'com.iota9star.fluttercockpit.cockpitdemo'
                  ? currentContainer.path
                  : legacyContainer.path;
              return ProcessResult(0, 0, containerPath, '');
            },
      );

      expect(requestedBundleIds, <String>[
        'com.iota9star.fluttercockpit.cockpitdemo',
        'dev.cockpit.cockpitDemo',
      ]);
      expect(_databaseArtifactsExist(currentContainer.path), isFalse);
      expect(_databaseArtifactsExist(legacyContainer.path), isFalse);
    },
  );

  test('verifier records sync lab conflict recovery evidence', () async {
    final recordingFile = await _createRecordingArtifact();
    var currentRoute = '/inbox';
    final verifier = CockpitDemoPlatformVerifier(
      describeSystemControl: _fakeDescribeSystemControl,
      runSystemAction: _fakeRunSystemAction,
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
        return _successfulCommandResult(
          request.command,
          includeScreenshot:
              request.command.commandType ==
                  CockpitCommandType.captureScreenshot ||
              cockpitCommandTypeIsAiEvidenceKeyOperation(
                request.command.commandType,
              ),
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
        return _successfulBatchResult(request);
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
      recordingAdapterResolver:
          ({
            required platform,
            required deviceId,
            required app,
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
                sourceFilePath: recordingFile.path,
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

  test(
    'verifier retries transient remote unavailability during validation',
    () async {
      final recordingFile = await _createRecordingArtifact();
      var currentRoute = '/inbox';
      var readAppAttempts = 0;
      var assertNewTaskAttempts = 0;
      var createBatchAttempts = 0;
      final verifier = CockpitDemoPlatformVerifier(
        describeSystemControl: _fakeDescribeSystemControl,
        runSystemAction: _fakeRunSystemAction,
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
          readAppAttempts += 1;
          if (readAppAttempts <= 3) {
            throw const CockpitApplicationServiceException(
              code: 'remoteUnavailable',
              message: 'Remote session is temporarily unavailable.',
            );
          }
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
              preferredAcceptanceRecordingKind:
                  CockpitRecordingKind.nativeScreen,
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
          return _successfulCommandResult(
            request.command,
            includeScreenshot:
                request.command.commandType ==
                    CockpitCommandType.captureScreenshot ||
                cockpitCommandTypeIsAiEvidenceKeyOperation(
                  request.command.commandType,
                ),
          );
        },
        runBatch: (request) async {
          if (request.commands.any(
            (command) => command.command.commandId == 'verify-open-editor',
          )) {
            createBatchAttempts += 1;
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
          return _successfulBatchResult(request);
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
        recordingAdapterResolver:
            ({
              required platform,
              required deviceId,
              required app,
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
                  sourceFilePath: recordingFile.path,
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
        timelineRecordingProcessRunner: (executable, arguments) async {
          final outputPath = arguments.last;
          await File(outputPath).writeAsBytes(<int>[1, 2, 3, 4], flush: true);
          return ProcessResult(0, 0, '', '');
        },
      );

      final result = await verifier.verify(
        const CockpitDemoPlatformVerificationRequest(
          projectDir: '/workspace/examples/cockpit_demo',
          platforms: <String>['macos'],
          outputRoot: '/tmp/cockpit_demo_platforms',
        ),
      );

      expect(result.success, isTrue);
      expect(readAppAttempts, greaterThanOrEqualTo(4));
      expect(assertNewTaskAttempts, 2);
      expect(createBatchAttempts, 1);
    },
  );

  test(
    'verifier attaches supervisor diagnostics to post-launch remote failures',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit-post-launch-diagnostics-',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });
      final supervisorLog = File(p.join(tempDir.path, 'supervisor.log'));
      await supervisorLog.writeAsString(
        '[2026-05-24T04:24:55Z] bound remote session app_id=web-demo\n'
        '[2026-05-24T04:25:06Z] bridge request timed out path=/health\n',
      );

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
        listIosSimulators: () async => const <CockpitDemoIosSimulator>[],
        runProcess: (executable, arguments, {String? workingDirectory}) async =>
            ProcessResult(0, 0, '', ''),
        wait: (_) async {},
        launchApp: (request) async => CockpitLaunchAppResult(
          app: _appForPlatform(
            platform: request.platform,
            deviceId: request.deviceId,
            baseUrl: 'http://127.0.0.1:${request.sessionPort}',
          ).copyWith(supervisorLogPath: supervisorLog.path),
          appJsonPath: p.join(tempDir.path, 'app.json'),
          supervisorLogPath: supervisorLog.path,
        ),
        readApp: (_) async => throw const CockpitApplicationServiceException(
          code: 'remoteUnavailable',
          message: 'Remote session is temporarily unavailable.',
          details: <String, Object?>{'path': '/health'},
        ),
        stopApp: (request) async => CockpitStopAppResult(
          app: request.app!,
          status: CockpitAppStopStatus.stopped(mode: request.app!.mode),
        ),
      );

      final result = await verifier.verify(
        CockpitDemoPlatformVerificationRequest(
          projectDir: '/workspace/examples/cockpit_demo',
          platforms: const <String>['web'],
          outputRoot: tempDir.path,
        ),
      );

      final failed = result.platforms.single;
      expect(failed.failureCode, 'remoteUnavailable');
      expect(
        failed.failureDetails,
        containsPair('supervisorLogPath', supervisorLog.path),
      );
      expect(
        failed.failureDetails,
        containsPair('supervisorLogTail', contains('bridge request timed out')),
      );
    },
  );

  test('verifier does not retry side-effecting command batches', () async {
    var batchAttempts = 0;
    final verifier = CockpitDemoPlatformVerifier(
      describeSystemControl: _fakeDescribeSystemControl,
      runSystemAction: _fakeRunSystemAction,
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
      runProcess: (executable, arguments, {String? workingDirectory}) async =>
          ProcessResult(0, 0, '', ''),
      wait: (_) async {},
      launchApp: (request) async => CockpitLaunchAppResult(
        app: _appForPlatform(
          platform: request.platform,
          deviceId: request.deviceId,
          baseUrl: 'http://127.0.0.1:${request.sessionPort}',
        ),
        appJsonPath: '/tmp/${request.platform}/app.json',
      ),
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
      runCommand: (request) async => _successfulCommandResult(request.command),
      inspectUi: (request) async => const CockpitInspectUiResult(
        routeName: '/inbox',
        diagnosticLevel: 'investigate',
        truncated: false,
      ),
      runBatch: (_) async {
        batchAttempts += 1;
        throw const CockpitApplicationServiceException(
          code: 'remoteUnavailable',
          message: 'Remote session is temporarily unavailable.',
        );
      },
      recordingAdapterResolver:
          ({
            required platform,
            required deviceId,
            required app,
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
              ),
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
    expect(batchAttempts, 1);
    expect(result.platforms.single.failureCode, 'remoteUnavailable');
  });

  test('verifier stops an active recording when a later step fails', () async {
    var recordingStopCount = 0;
    final failureScreenshot = File(
      p.join(
        Directory.systemTemp.createTempSync('cockpit_failure_screenshot_').path,
        'verify-open-editor.png',
      ),
    );
    failureScreenshot
      ..createSync(recursive: true)
      ..writeAsBytesSync(<int>[137, 80, 78, 71, 13, 10, 26, 10]);
    addTearDown(() {
      final parent = failureScreenshot.parent;
      if (parent.existsSync()) {
        parent.deleteSync(recursive: true);
      }
    });
    final verifier = CockpitDemoPlatformVerifier(
      describeSystemControl: _fakeDescribeSystemControl,
      runSystemAction: _fakeRunSystemAction,
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
              success: true,
              durationMs: 18,
              usedCaptureFallback: false,
            ),
            artifacts: <CockpitInteractiveArtifactDescriptor>[
              CockpitInteractiveArtifactDescriptor(
                role: 'screenshot',
                relativePath: 'screenshots/verify-open-editor.png',
                byteLength: 2048,
                sourcePath: failureScreenshot.path,
              ),
            ],
            whatChanged: 'Command verify-open-editor completed successfully.',
            snapshot: CockpitSnapshot(
              routeName: '/inbox',
              visibleTargets: const <CockpitSnapshotTarget>[],
            ),
            snapshotRef: 'snapshot-open-editor',
          ),
          CockpitExecuteRemoteCommandResult(
            command: CockpitInteractiveCommandCore(
              commandId: request.commands[1].command.commandId,
              commandType: request.commands[1].command.commandType.name,
              success: false,
              durationMs: 12000,
              usedCaptureFallback: false,
              error: CockpitCommandError.timeout(
                message: 'Timed out waiting for route "/editor".',
                details: const <String, Object?>{
                  'routeName': '/inbox',
                  'visibleTextCandidates': <String>['New task', 'Settings'],
                },
              ),
            ),
            artifacts: const <CockpitInteractiveArtifactDescriptor>[],
            recommendedNextStep: 'inspect-ui-then-fix-locator',
            selectedPlane: CockpitPlaneKind.flutterSemanticPlane,
            whatMatters: 'Timed out waiting for route "/editor".',
            uiSummary: const CockpitInteractiveSnapshotSummary(
              routeName: '/inbox',
              diagnosticLevel: 'baseline',
              truncated: false,
              visibleTargetCount: 8,
              targetsWithCockpitIdCount: 0,
              targetsWithTextCount: 8,
              networkEntryCount: 0,
              networkFailureCount: 0,
              runtimeEntryCount: 0,
              runtimeErrorCount: 0,
              rebuildEntryCount: 0,
              totalRebuildCount: 0,
              accessibilityTargetCount: 8,
              accessibilityTraversalCount: 8,
              textPreviews: <String>['New task', 'Settings'],
            ),
          ),
        ],
        summary: const CockpitExecuteRemoteCommandBatchSummary(
          totalCount: 2,
          successCount: 1,
          failureCount: 1,
          stoppedEarly: true,
        ),
      ),
      recordingAdapterResolver:
          ({
            required platform,
            required deviceId,
            required app,
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
    final failedPlatform = result.platforms.single;
    expect(failedPlatform.failureCode, 'exampleBatchFailed');
    expect(
      failedPlatform.failureDetails,
      containsPair('recommendedNextStep', 'inspect-ui-then-fix-locator'),
    );
    expect(
      failedPlatform.failureDetails,
      containsPair('commandId', 'verify-wait-for-editor-route'),
    );
    expect(
      failedPlatform.failureDetails,
      containsPair('commandType', 'waitFor'),
    );
    expect(failedPlatform.failureDetails, containsPair('expectedCount', 9));
    expect(
      failedPlatform.failureDetails['error'],
      containsPair('code', CockpitCommandError.timeoutCode),
    );
    expect(
      failedPlatform.failureDetails['uiSummary'],
      containsPair('routeName', '/inbox'),
    );
    final completedTrail =
        (failedPlatform.failureDetails['completedCommandTrail']
                as List<Object?>)
            .cast<Map<Object?, Object?>>();
    expect(completedTrail, hasLength(2));
    expect(completedTrail.first['commandId'], 'verify-open-editor');
    expect(completedTrail.first['success'], isTrue);
    expect(completedTrail.first['routeName'], '/inbox');
    expect(completedTrail.first['snapshotRef'], 'snapshot-open-editor');
    expect(
      completedTrail.first['artifacts'],
      contains(
        containsPair('relativePath', 'screenshots/verify-open-editor.png'),
      ),
    );
    expect(completedTrail.last['commandId'], 'verify-wait-for-editor-route');
    expect(completedTrail.last['success'], isFalse);
    expect(
      failedPlatform.toJson()['failureDetails'],
      containsPair('selectedPlane', 'flutterSemanticPlane'),
    );
    expect(recordingStopCount, 1);
    final exportedFailureScreenshot = File(
      p.join(failedPlatform.outputDir, 'screenshots', 'verify-open-editor.png'),
    );
    expect(exportedFailureScreenshot.existsSync(), isTrue);
    expect(exportedFailureScreenshot.lengthSync(), greaterThan(0));
  });

  test(
    'verifier fails when completed recording evidence is unavailable',
    () async {
      final verifier = CockpitDemoPlatformVerifier(
        describeSystemControl: _fakeDescribeSystemControl,
        runSystemAction: _fakeRunSystemAction,
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
        readApp: (request) async => CockpitReadAppResult(
          sessionId: '${request.app!.platform}-session',
          transportType: 'remoteHttp',
          capabilities: _capabilitiesForPlatform(request.app!.platform),
          recordingCapabilities: CockpitRecordingCapabilities(
            supportsNativeRecording: true,
            preferredAcceptanceRecordingKind: CockpitRecordingKind.nativeScreen,
          ),
          currentRouteName: '/inbox',
        ),
        runCommand: (request) async =>
            _successfulCommandResult(request.command),
        inspectUi: (_) async => const CockpitInspectUiResult(
          routeName: '/inbox',
          diagnosticLevel: 'investigate',
          truncated: false,
        ),
        runBatch: (request) async => _successfulBatchResult(request),
        waitIdle: (_) async => const CockpitWaitIdleResult(
          idle: true,
          durationMs: 120,
          quietWindowMs: 160,
          timeoutMs: 5000,
          includeNetworkIdle: true,
        ),
        readNetwork: (_) async => _successfulNetworkResult(),
        readErrors: (_) async => const CockpitReadErrorsResult(
          appId: 'errors-app',
          routeName: '/inbox',
          source: 'app_snapshot',
          errors: <CockpitErrorEntry>[],
        ),
        readLogs: (_) async => const CockpitReadLogsResult(
          appId: 'logs-app',
          source: 'app_snapshot',
          available: true,
          routeName: '/inbox',
          lines: <String>['info runtime: missing evidence path'],
          truncated: false,
        ),
        inspectSurface: (request) async => _inspectSurfaceResult(request.app!),
        recordingAdapterResolver:
            ({
              required platform,
              required deviceId,
              required app,
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
                    relativePath: 'recordings/missing.mp4',
                  ),
                  durationMs: 1600,
                  sourceFilePath: '/tmp/flutter_cockpit_missing_recording.mp4',
                ),
              );
            },
        hotReload: (request) async => _successfulHotReload(request.app!),
        hotRestart: (request) async => _successfulHotRestart(request.app!),
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
      final failedPlatform = result.platforms.single;
      expect(failedPlatform.failureCode, 'recordingArtifactUnavailable');
      expect(
        failedPlatform.failureDetails,
        containsPair('artifactPath', 'recordings/missing.mp4'),
      );
    },
  );

  test('verifier persists inline recording bytes as evidence', () async {
    final verifier = CockpitDemoPlatformVerifier(
      describeSystemControl: _fakeDescribeSystemControl,
      runSystemAction: _fakeRunSystemAction,
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
      readApp: (request) async => CockpitReadAppResult(
        sessionId: '${request.app!.platform}-session',
        transportType: 'remoteHttp',
        capabilities: _capabilitiesForPlatform(request.app!.platform),
        recordingCapabilities: CockpitRecordingCapabilities(
          supportsNativeRecording: true,
          preferredAcceptanceRecordingKind: CockpitRecordingKind.nativeScreen,
        ),
        currentRouteName: '/inbox',
      ),
      runCommand: (request) async => _successfulCommandResult(request.command),
      inspectUi: (_) async => const CockpitInspectUiResult(
        routeName: '/inbox',
        diagnosticLevel: 'investigate',
        truncated: false,
      ),
      runBatch: (request) async => _successfulBatchResult(request),
      waitIdle: (_) async => const CockpitWaitIdleResult(
        idle: true,
        durationMs: 120,
        quietWindowMs: 160,
        timeoutMs: 5000,
        includeNetworkIdle: true,
      ),
      readNetwork: (_) async => _successfulNetworkResult(),
      readErrors: (_) async => const CockpitReadErrorsResult(
        appId: 'errors-app',
        routeName: '/inbox',
        source: 'app_snapshot',
        errors: <CockpitErrorEntry>[],
      ),
      readLogs: (_) async => const CockpitReadLogsResult(
        appId: 'logs-app',
        source: 'app_snapshot',
        available: true,
        routeName: '/inbox',
        lines: <String>['info runtime: inline recording path'],
        truncated: false,
      ),
      inspectSurface: (request) async => _inspectSurfaceResult(request.app!),
      recordingAdapterResolver:
          ({
            required platform,
            required deviceId,
            required app,
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
                  relativePath: 'recordings/inline.mp4',
                ),
                durationMs: 1600,
                bytes: <int>[9, 8, 7, 6],
              ),
            );
          },
      hotReload: (request) async => _successfulHotReload(request.app!),
      hotRestart: (request) async => _successfulHotRestart(request.app!),
      stopApp: (request) async => CockpitStopAppResult(
        app: request.app!,
        status: CockpitAppStopStatus.stopped(mode: request.app!.mode),
      ),
    );

    final outputRoot = await Directory.systemTemp.createTemp(
      'cockpit_inline_recording_',
    );
    final result = await verifier.verify(
      CockpitDemoPlatformVerificationRequest(
        projectDir: '/workspace/examples/cockpit_demo',
        platforms: const <String>['macos'],
        outputRoot: outputRoot.path,
      ),
    );

    expect(result.success, isTrue);
    final platform = result.platforms.single;
    expect(platform.recordingArtifactRef, 'recordings/inline.mp4');
    expect(platform.recordingOutputPath, isNotNull);
    expect(File(platform.recordingOutputPath!).readAsBytesSync(), <int>[
      9,
      8,
      7,
      6,
    ]);
  });

  test('verifier exports automatic key-step screenshots as files', () async {
    final recordingFile = await _createRecordingArtifact();
    final verifier = CockpitDemoPlatformVerifier(
      describeSystemControl: _fakeDescribeSystemControl,
      runSystemAction: _fakeRunSystemAction,
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
      readApp: (request) async => CockpitReadAppResult(
        sessionId: '${request.app!.platform}-session',
        transportType: 'remoteHttp',
        capabilities: _capabilitiesForPlatform(request.app!.platform),
        recordingCapabilities: CockpitRecordingCapabilities(
          supportsNativeRecording: true,
          preferredAcceptanceRecordingKind: CockpitRecordingKind.nativeScreen,
        ),
        currentRouteName: '/inbox',
      ),
      runCommand: (request) async => _successfulCommandResult(request.command),
      inspectUi: (_) async => const CockpitInspectUiResult(
        routeName: '/inbox',
        diagnosticLevel: 'investigate',
        truncated: false,
      ),
      runBatch: (request) async => _successfulBatchResult(request),
      waitIdle: (_) async => const CockpitWaitIdleResult(
        idle: true,
        durationMs: 120,
        quietWindowMs: 160,
        timeoutMs: 5000,
        includeNetworkIdle: true,
      ),
      readNetwork: (_) async => _successfulNetworkResult(),
      readErrors: (_) async => const CockpitReadErrorsResult(
        appId: 'errors-app',
        routeName: '/inbox',
        source: 'app_snapshot',
        errors: <CockpitErrorEntry>[],
      ),
      readLogs: (_) async => const CockpitReadLogsResult(
        appId: 'logs-app',
        source: 'app_snapshot',
        available: true,
        routeName: '/inbox',
        lines: <String>['info runtime: key screenshots exported'],
        truncated: false,
      ),
      inspectSurface: (request) async => _inspectSurfaceResult(request.app!),
      recordingAdapterResolver:
          ({
            required platform,
            required deviceId,
            required app,
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
                sourceFilePath: recordingFile.path,
              ),
            );
          },
      hotReload: (request) async => _successfulHotReload(request.app!),
      hotRestart: (request) async => _successfulHotRestart(request.app!),
      stopApp: (request) async => CockpitStopAppResult(
        app: request.app!,
        status: CockpitAppStopStatus.stopped(mode: request.app!.mode),
      ),
    );

    final outputRoot = await Directory.systemTemp.createTemp(
      'cockpit_key_screenshots_',
    );
    addTearDown(() async {
      if (await outputRoot.exists()) {
        await outputRoot.delete(recursive: true);
      }
    });

    final result = await verifier.verify(
      CockpitDemoPlatformVerificationRequest(
        projectDir: '/workspace/examples/cockpit_demo',
        platforms: const <String>['macos'],
        outputRoot: outputRoot.path,
      ),
    );

    expect(result.success, isTrue);
    final platform = result.platforms.single;
    expect(platform.exportedScreenshotCount, platform.autoScreenshotCount);
    expect(platform.screenshotOutputPath, isNotNull);
    final screenshotsDir = Directory(p.join(platform.outputDir, 'screenshots'));
    final screenshotFiles = screenshotsDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => p.extension(file.path) == '.png')
        .toList(growable: false);
    expect(screenshotFiles, hasLength(platform.autoScreenshotCount + 1));
    expect(
      screenshotFiles.map((file) => p.basename(file.path)),
      contains('platform-proof.png'),
    );
    for (final screenshot in screenshotFiles) {
      expect(screenshot.lengthSync(), greaterThan(0));
    }
  });

  test('verifier fails when screenshot evidence is empty', () async {
    final recordingFile = await _createRecordingArtifact();
    final verifier = CockpitDemoPlatformVerifier(
      describeSystemControl: _fakeDescribeSystemControl,
      runSystemAction: _fakeRunSystemAction,
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
      readApp: (request) async => CockpitReadAppResult(
        sessionId: '${request.app!.platform}-session',
        transportType: 'remoteHttp',
        capabilities: _capabilitiesForPlatform(request.app!.platform),
        recordingCapabilities: CockpitRecordingCapabilities(
          supportsNativeRecording: true,
          preferredAcceptanceRecordingKind: CockpitRecordingKind.nativeScreen,
        ),
        currentRouteName: '/inbox',
      ),
      runCommand: (request) async =>
          _successfulCommandResult(request.command, screenshotByteLength: 0),
      inspectUi: (_) async => const CockpitInspectUiResult(
        routeName: '/inbox',
        diagnosticLevel: 'investigate',
        truncated: false,
      ),
      runBatch: (request) async => _successfulBatchResult(request),
      waitIdle: (_) async => const CockpitWaitIdleResult(
        idle: true,
        durationMs: 120,
        quietWindowMs: 160,
        timeoutMs: 5000,
        includeNetworkIdle: true,
      ),
      readNetwork: (_) async => _successfulNetworkResult(),
      readErrors: (_) async => const CockpitReadErrorsResult(
        appId: 'errors-app',
        routeName: '/inbox',
        source: 'app_snapshot',
        errors: <CockpitErrorEntry>[],
      ),
      readLogs: (_) async => const CockpitReadLogsResult(
        appId: 'logs-app',
        source: 'app_snapshot',
        available: true,
        routeName: '/inbox',
        lines: <String>['info runtime: empty screenshot path'],
        truncated: false,
      ),
      inspectSurface: (request) async => _inspectSurfaceResult(request.app!),
      recordingAdapterResolver:
          ({
            required platform,
            required deviceId,
            required app,
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
                sourceFilePath: recordingFile.path,
              ),
            );
          },
      hotReload: (request) async => _successfulHotReload(request.app!),
      hotRestart: (request) async => _successfulHotRestart(request.app!),
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
    final failedPlatform = result.platforms.single;
    expect(failedPlatform.failureCode, 'screenshotArtifactEmpty');
    expect(
      failedPlatform.failureDetails,
      containsPair(
        'artifactPath',
        startsWith('screenshots/verify-reveal-keep-local-resolution_'),
      ),
    );
  });

  test(
    'verifier fails when a key operation omits screenshot evidence',
    () async {
      final recordingFile = await _createRecordingArtifact();
      final verifier = CockpitDemoPlatformVerifier(
        describeSystemControl: _fakeDescribeSystemControl,
        runSystemAction: _fakeRunSystemAction,
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
        readApp: (request) async => CockpitReadAppResult(
          sessionId: '${request.app!.platform}-session',
          transportType: 'remoteHttp',
          capabilities: _capabilitiesForPlatform(request.app!.platform),
          recordingCapabilities: CockpitRecordingCapabilities(
            supportsNativeRecording: true,
            preferredAcceptanceRecordingKind: CockpitRecordingKind.nativeScreen,
          ),
          currentRouteName: '/inbox',
        ),
        runCommand: (request) async =>
            _successfulCommandResult(request.command),
        inspectUi: (_) async => const CockpitInspectUiResult(
          routeName: '/inbox',
          diagnosticLevel: 'investigate',
          truncated: false,
        ),
        runBatch: (request) async => CockpitRunBatchResult(
          results: request.commands
              .map(
                (batchCommand) => _successfulCommandResult(
                  batchCommand.command,
                  includeScreenshot: false,
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
        readNetwork: (_) async => _successfulNetworkResult(),
        readErrors: (_) async => const CockpitReadErrorsResult(
          appId: 'errors-app',
          routeName: '/inbox',
          source: 'app_snapshot',
          errors: <CockpitErrorEntry>[],
        ),
        readLogs: (_) async => const CockpitReadLogsResult(
          appId: 'logs-app',
          source: 'app_snapshot',
          available: true,
          routeName: '/inbox',
          lines: <String>['info runtime: missing key screenshot path'],
          truncated: false,
        ),
        inspectSurface: (request) async => _inspectSurfaceResult(request.app!),
        recordingAdapterResolver:
            ({
              required platform,
              required deviceId,
              required app,
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
                  sourceFilePath: recordingFile.path,
                ),
              );
            },
        hotReload: (request) async => _successfulHotReload(request.app!),
        hotRestart: (request) async => _successfulHotRestart(request.app!),
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
      final failedPlatform = result.platforms.single;
      expect(failedPlatform.failureCode, 'autoScreenshotArtifactMissing');
      expect(
        failedPlatform.failureDetails,
        containsPair('commandId', 'verify-open-editor'),
      );
    },
  );

  test(
    'verifier defaults web host recording prerequisites to timeline fallback',
    () async {
      final outputRoot = await Directory.systemTemp.createTemp(
        'cockpit_web_start_fallback_',
      );
      addTearDown(() async {
        if (await outputRoot.exists()) {
          await outputRoot.delete(recursive: true);
        }
      });
      final verifier = CockpitDemoPlatformVerifier(
        describeSystemControl: _fakeDescribeSystemControl,
        runSystemAction: _fakeRunSystemAction,
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
        runCommand: (request) async => _successfulCommandResult(
          request.command,
          includeScreenshot:
              request.command.commandType ==
                  CockpitCommandType.captureScreenshot ||
              cockpitCommandTypeIsAiEvidenceKeyOperation(
                request.command.commandType,
              ),
          screenshotByteLength: 512,
        ),
        runBatch: (request) async => _successfulBatchResult(request),
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
        recordingAdapterResolver:
            ({
              required platform,
              required deviceId,
              required app,
              required client,
              required recording,
            }) {
              return _FakeRecordingAdapter(
                onStart: (_) async {
                  throw const CockpitApplicationServiceException(
                    code: 'recordingStartFailed',
                    message: 'Screen Recording permission is missing.',
                    details: <String, Object?>{'statusCode': 412},
                  );
                },
                onStop: () async =>
                    throw StateError('stop should not be called'),
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
        timelineRecordingProcessRunner: (executable, arguments) async {
          expect(executable, 'ffmpeg');
          final outputPath = arguments.last;
          await File(outputPath).writeAsBytes(<int>[1, 2, 3, 4], flush: true);
          return ProcessResult(0, 0, '', '');
        },
      );

      final result = await verifier.verify(
        CockpitDemoPlatformVerificationRequest(
          projectDir: '/workspace/examples/cockpit_demo',
          platforms: const <String>['web'],
          outputRoot: outputRoot.path,
        ),
      );

      expect(result.success, isTrue);
      expect(result.platforms, hasLength(1));
      final platform = result.platforms.single;
      expect(platform.status, 'passed');
      expect(
        platform.recordingArtifactRef,
        'recordings/verify_web_loop_timeline_fallback.mp4',
      );
      expect(platform.recordingOutputPath, isNotNull);
      expect(File(platform.recordingOutputPath!).existsSync(), isTrue);
      expect(platform.recordingDriver, 'browser-host-fallback');
      expect(platform.recordingKind, 'timelineScreenshotFallback');
      expect(platform.verifiedCommands, <String>[
        'launch-app',
        'read-app',
        'inspect-ui',
        'read-system-capabilities',
        'run-batch',
        'wait-idle',
        'sync_lab_conflict_recovery',
        'read-network',
        'read-errors',
        'read-logs',
        'inspect-surface',
        'capture-screenshot',
        'timeline-recording-fallback',
        'hot-reload',
        'hot-restart',
      ]);
      expect(platform.exportedScreenshotCount, platform.autoScreenshotCount);
      expect(platform.screenshotOutputPath, isNotNull);
      expect(platform.warnings, hasLength(2));
      expect(
        platform.warnings.first,
        contains('Screen Recording permission is missing.'),
      );
      expect(
        platform.warnings.last,
        contains('Synthesized a timeline recording'),
      );
    },
  );

  test(
    'verifier synthesizes a web timeline recording when host recording fails after startup',
    () async {
      final outputRoot = await Directory.systemTemp.createTemp(
        'cockpit_web_timeline_fallback_',
      );
      addTearDown(() async {
        if (await outputRoot.exists()) {
          await outputRoot.delete(recursive: true);
        }
      });
      final verifier = CockpitDemoPlatformVerifier(
        describeSystemControl: _fakeDescribeSystemControl,
        runSystemAction: _fakeRunSystemAction,
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
        runCommand: (request) async => _successfulCommandResult(
          request.command,
          screenshotByteLength: 512,
        ),
        runBatch: (request) async => _successfulBatchResult(request),
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
        recordingAdapterResolver:
            ({
              required platform,
              required deviceId,
              required app,
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
        timelineRecordingProcessRunner: (executable, arguments) async {
          expect(executable, 'ffmpeg');
          final outputPath = arguments.last;
          await File(outputPath).writeAsBytes(<int>[1, 2, 3, 4], flush: true);
          return ProcessResult(0, 0, '', '');
        },
      );

      final result = await verifier.verify(
        CockpitDemoPlatformVerificationRequest(
          projectDir: '/workspace/examples/cockpit_demo',
          platforms: const <String>['web'],
          outputRoot: outputRoot.path,
        ),
      );

      expect(result.success, isTrue);
      expect(result.platforms, hasLength(1));
      final platform = result.platforms.single;
      expect(platform.status, 'passed');
      expect(
        platform.recordingArtifactRef,
        'recordings/verify_web_loop_timeline_fallback.mp4',
      );
      expect(platform.recordingOutputPath, isNotNull);
      expect(File(platform.recordingOutputPath!).existsSync(), isTrue);
      expect(platform.recordingDriver, 'browser-host-fallback');
      expect(platform.recordingKind, 'timelineScreenshotFallback');
      expect(platform.exportedScreenshotCount, platform.autoScreenshotCount);
      expect(platform.verifiedCommands, contains('stop-recording'));
      final screenshotsDir = Directory(
        p.join(platform.outputDir, 'screenshots'),
      );
      final screenshotFiles = screenshotsDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => p.extension(file.path) == '.png')
          .toList(growable: false);
      expect(screenshotFiles, hasLength(platform.autoScreenshotCount + 1));
      expect(
        platform.warnings.single,
        contains('macOS recording did not stop before timeout.'),
      );
    },
  );

  test(
    'verifier keeps web host recording failures strict when requested',
    () async {
      final outputRoot = await Directory.systemTemp.createTemp(
        'cockpit_web_strict_recording_',
      );
      addTearDown(() async {
        if (await outputRoot.exists()) {
          await outputRoot.delete(recursive: true);
        }
      });
      final verifier = await _createSinglePlatformVerifier(
        platform: 'web',
        deviceId: 'chrome',
        recordingAdapterResolver:
            ({
              required platform,
              required deviceId,
              required app,
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
                  failureReason: 'browser-host recording output is empty',
                ),
              );
            },
        timelineRecordingProcessRunner: (executable, arguments) async {
          fail('strict web host recording must not synthesize a fallback');
        },
      );

      final result = await verifier.verify(
        CockpitDemoPlatformVerificationRequest(
          projectDir: '/workspace/examples/cockpit_demo',
          platforms: const <String>['web'],
          outputRoot: outputRoot.path,
          strictWebHostRecording: true,
        ),
      );

      expect(result.success, isFalse);
      final platform = result.platforms.single;
      expect(platform.status, 'failed');
      expect(platform.failureCode, 'recordingStopFailed');
      expect(platform.recordingDriver, isNull);
      expect(
        platform.verifiedCommands,
        isNot(contains('timeline-recording-fallback')),
      );
      expect(
        platform.failureMessage,
        contains('browser-host recording output is empty'),
      );
    },
  );

  test(
    'verifier synthesizes a Windows timeline recording when host recording startup evidence is unavailable',
    () async {
      final outputRoot = await Directory.systemTemp.createTemp(
        'cockpit_windows_start_fallback_',
      );
      addTearDown(() async {
        if (await outputRoot.exists()) {
          await outputRoot.delete(recursive: true);
        }
      });
      final verifier = CockpitDemoPlatformVerifier(
        describeSystemControl: _fakeDescribeSystemControl,
        runSystemAction: _fakeRunSystemAction,
        probeDevices: () async => const <CockpitDemoHostDevice>[
          CockpitDemoHostDevice(
            name: 'Windows',
            deviceId: 'windows',
            platform: 'windows',
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
          sessionId: 'windows-session',
          transportType: 'remoteHttp',
          capabilities: CockpitCapabilities(
            platform: 'windows',
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
          currentRouteName: '/inbox',
        ),
        inspectUi: (_) async => const CockpitInspectUiResult(
          routeName: '/inbox',
          diagnosticLevel: 'investigate',
          truncated: false,
        ),
        runCommand: (request) async => _successfulCommandResult(
          request.command,
          includeScreenshot:
              request.command.commandType ==
                  CockpitCommandType.captureScreenshot ||
              cockpitCommandTypeIsAiEvidenceKeyOperation(
                request.command.commandType,
              ),
          screenshotByteLength: 512,
        ),
        runBatch: (request) async => _successfulBatchResult(request),
        waitIdle: (_) async => const CockpitWaitIdleResult(
          idle: true,
          durationMs: 120,
          quietWindowMs: 160,
          timeoutMs: 5000,
          includeNetworkIdle: true,
        ),
        readNetwork: (request) async => CockpitReadNetworkResult(
          appId: 'windows-network',
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
          appId: 'windows-errors',
          routeName: '/inbox',
          source: 'app_snapshot',
          errors: <CockpitErrorEntry>[],
        ),
        readLogs: (_) async => const CockpitReadLogsResult(
          appId: 'windows-logs',
          source: 'app_snapshot',
          available: true,
          routeName: '/inbox',
          lines: <String>['info runtime: windows verification warning path'],
          truncated: false,
        ),
        inspectSurface: (request) async => CockpitInspectSurfaceResult(
          target: CockpitTargetHandle.fromAppHandle(request.app!),
          capabilityProfile: CockpitCapabilityProfile(
            targetKind: CockpitTargetKind.desktopApp,
            surfaceKinds: <CockpitSurfaceKind>{
              CockpitSurfaceKind.flutterSemantic,
              CockpitSurfaceKind.nativeUi,
              CockpitSurfaceKind.desktopWindow,
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
          surfaceKind: CockpitSurfaceKind.desktopWindow,
          selectedPlane: CockpitPlaneKind.flutterSemanticPlane,
          recommendedNextStep: 'continue',
          routeName: '/inbox',
          diagnosticLevel: 'inspect',
          truncated: false,
        ),
        recordingAdapterResolver:
            ({
              required platform,
              required deviceId,
              required app,
              required client,
              required recording,
            }) {
              return _FakeRecordingAdapter(
                onStart: (_) async {
                  throw StateError(
                    'Windows recording did not confirm startup or produce output. '
                    'Ensure the desktop session is active and ffmpeg gdigrab can capture the screen on this host.',
                  );
                },
                onStop: () async =>
                    throw StateError('stop should not be called'),
              );
            },
        hotReload: (request) async => CockpitHotReloadResult(
          app: request.app!,
          status: CockpitDevelopmentSessionStatus(
            developmentSessionId: 'windows-session',
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
            developmentSessionId: 'windows-session',
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
        timelineRecordingProcessRunner: (executable, arguments) async {
          expect(executable, 'ffmpeg');
          final outputPath = arguments.last;
          await File(outputPath).writeAsBytes(<int>[1, 2, 3, 4], flush: true);
          return ProcessResult(0, 0, '', '');
        },
      );

      final result = await verifier.verify(
        CockpitDemoPlatformVerificationRequest(
          projectDir: '/workspace/examples/cockpit_demo',
          platforms: const <String>['windows'],
          outputRoot: outputRoot.path,
        ),
      );

      expect(result.success, isTrue);
      final platform = result.platforms.single;
      expect(platform.status, 'passed');
      expect(
        platform.recordingArtifactRef,
        'recordings/verify_windows_loop_timeline_fallback.mp4',
      );
      expect(platform.recordingOutputPath, isNotNull);
      expect(File(platform.recordingOutputPath!).existsSync(), isTrue);
      expect(platform.recordingDriver, 'windows-host-fallback');
      expect(platform.recordingKind, 'timelineScreenshotFallback');
      expect(platform.exportedScreenshotCount, platform.autoScreenshotCount);
      expect(
        platform.verifiedCommands,
        contains('timeline-recording-fallback'),
      );
      expect(platform.verifiedCommands, isNot(contains('start-recording')));
      expect(platform.warnings, hasLength(2));
      expect(
        platform.warnings.first,
        contains('Windows recording did not confirm startup'),
      );
      expect(
        platform.warnings.last,
        contains('Synthesized a timeline recording'),
      );
    },
  );

  test(
    'device probe normalizes desktop and android variant target platforms',
    () async {
      final devices = await cockpitDemoProbeHostDevices(
        processRunner:
            (executable, arguments, {String? workingDirectory}) async {
              expect(executable, 'flutter');
              expect(arguments, const <String>['devices', '--machine']);
              return ProcessResult(0, 0, '''
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
''', '');
            },
      );

      expect(devices, hasLength(4));
      expect(devices.map((device) => device.platform), <String>[
        'android',
        'linux',
        'windows',
        'web',
      ]);
      expect(devices.map((device) => device.deviceId), <String>[
        'emulator-5554',
        'linux',
        'windows',
        'chrome',
      ]);
      expect(devices.map((device) => device.emulator), <bool>[
        true,
        false,
        false,
        false,
      ]);
    },
  );
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
    platformAppId: 'dev.cockpit.cockpit_demo',
  );
}

Future<File> _createRecordingArtifact() async {
  final directory = await Directory.systemTemp.createTemp(
    'cockpit_demo_recording_artifact_',
  );
  final file = File(p.join(directory.path, 'platform-loop.mp4'));
  await file.writeAsBytes(<int>[1, 2, 3, 4], flush: true);
  return file;
}

Future<CockpitDemoPlatformVerifier> _createSinglePlatformVerifier({
  required String platform,
  required String deviceId,
  CockpitDemoSystemControlRunActionFunction? runSystemAction,
  CockpitDemoRecordingAdapterResolver? recordingAdapterResolver,
  CockpitDemoTimelineRecordingProcessRunner? timelineRecordingProcessRunner,
}) async {
  final recordingFile = await _createRecordingArtifact();
  late CockpitAppHandle launchedApp;
  return CockpitDemoPlatformVerifier(
    probeDevices: () async => <CockpitDemoHostDevice>[
      CockpitDemoHostDevice(
        name: platform,
        deviceId: deviceId,
        platform: platform,
        emulator: platform == 'ios' || platform == 'android',
        supported: true,
      ),
    ],
    launchApp: (request) async {
      launchedApp = _appForPlatform(
        platform: request.platform,
        deviceId: request.deviceId,
        baseUrl: 'http://127.0.0.1:58331',
      );
      return CockpitLaunchAppResult(
        app: launchedApp,
        appJsonPath: request.appHandlePath,
      );
    },
    readApp: (request) async => CockpitReadAppResult(
      sessionId: '${request.app!.platform}-session',
      transportType: 'remoteHttp',
      capabilities: _capabilitiesForPlatform(request.app!.platform),
      recordingCapabilities: CockpitRecordingCapabilities(
        supportsNativeRecording: true,
        preferredAcceptanceRecordingKind: CockpitRecordingKind.nativeScreen,
      ),
      currentRouteName: '/inbox',
      snapshot: CockpitSnapshot(
        routeName: '/inbox',
        visibleTargets: const <CockpitSnapshotTarget>[],
      ),
    ),
    inspectUi: (_) async => const CockpitInspectUiResult(
      routeName: '/inbox',
      diagnosticLevel: 'inspect',
      truncated: false,
    ),
    describeSystemControl: _fakeDescribeSystemControl,
    runSystemAction: runSystemAction ?? _fakeRunSystemAction,
    runCommand: (request) async => _successfulCommandResult(request.command),
    runBatch: (request) async => _successfulBatchResult(request),
    recordingAdapterResolver:
        recordingAdapterResolver ??
        ({
          required platform,
          required deviceId,
          required app,
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
              durationMs: 3200,
              sourceFilePath: recordingFile.path,
            ),
          );
        },
    hotReload: (request) async => _successfulHotReload(request.app!),
    hotRestart: (request) async => _successfulHotRestart(request.app!),
    waitIdle: (_) async => const CockpitWaitIdleResult(
      idle: true,
      durationMs: 1,
      quietWindowMs: 96,
      timeoutMs: 1600,
      includeNetworkIdle: true,
    ),
    readNetwork: (_) async => _successfulNetworkResult(),
    readErrors: (_) async => const CockpitReadErrorsResult(
      appId: 'errors-app',
      routeName: '/inbox',
      source: 'app_snapshot',
      errors: <CockpitErrorEntry>[],
    ),
    readLogs: (_) async => const CockpitReadLogsResult(
      appId: 'logs-app',
      source: 'app_snapshot',
      available: true,
      routeName: '/inbox',
      lines: <String>['info runtime: example verifier settled'],
      truncated: false,
    ),
    inspectSurface: (_) async => _inspectSurfaceResult(launchedApp),
    stopApp: (request) async => CockpitStopAppResult(
      app: request.app!,
      status: CockpitAppStopStatus.stopped(mode: request.app!.mode),
    ),
    timelineRecordingProcessRunner: timelineRecordingProcessRunner,
    wait: (_) async {},
  );
}

CockpitCapabilities _capabilitiesForPlatform(String platform) {
  return CockpitCapabilities(
    platform: platform,
    transportType: 'remoteHttp',
    supportsInAppControl: true,
    supportsFlutterViewCapture: true,
    supportsNativeScreenCapture: true,
    supportsHostAutomation: platform == 'macos',
    supportedCommands: const <CockpitCommandType>[
      CockpitCommandType.tap,
      CockpitCommandType.enterText,
      CockpitCommandType.assertText,
      CockpitCommandType.captureScreenshot,
    ],
    supportedLocatorStrategies: CockpitLocatorKind.values,
  );
}

CockpitExecuteRemoteCommandResult _successfulCommandResult(
  CockpitCommand command, {
  bool? includeScreenshot,
  int screenshotByteLength = 1024,
}) {
  final shouldIncludeScreenshot =
      includeScreenshot ??
      (command.commandType == CockpitCommandType.captureScreenshot ||
          cockpitCommandTypeIsAiEvidenceKeyOperation(command.commandType));
  final screenshotRelativePath = shouldIncludeScreenshot
      ? _screenshotRelativePathFor(command)
      : null;
  final screenshotArtifact = shouldIncludeScreenshot
      ? CockpitInteractiveArtifactDescriptor(
          role: 'screenshot',
          relativePath: screenshotRelativePath!,
          byteLength: screenshotByteLength,
          sourcePath: screenshotByteLength <= 0
              ? null
              : _writeScreenshotArtifactFor(
                  relativePath: screenshotRelativePath,
                  byteLength: screenshotByteLength,
                ),
        )
      : null;
  return CockpitExecuteRemoteCommandResult(
    command: CockpitInteractiveCommandCore(
      commandId: command.commandId,
      commandType: command.commandType.name,
      success: true,
      durationMs: 12,
      usedCaptureFallback: false,
    ),
    artifacts: screenshotArtifact == null
        ? const <CockpitInteractiveArtifactDescriptor>[]
        : <CockpitInteractiveArtifactDescriptor>[screenshotArtifact],
  );
}

String _screenshotRelativePathFor(CockpitCommand command) {
  if (command.commandType == CockpitCommandType.captureScreenshot) {
    return 'screenshots/platform-proof.png';
  }
  _screenshotArtifactSequence += 1;
  final sanitized = command.commandId
      .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  final stem = sanitized.isEmpty ? 'command' : sanitized;
  return 'screenshots/${stem}_$_screenshotArtifactSequence.png';
}

String _writeScreenshotArtifactFor({
  required String relativePath,
  required int byteLength,
}) {
  final directory = Directory.systemTemp.createTempSync(
    'cockpit_demo_screenshot_artifact_',
  );
  final file = File(p.join(directory.path, p.basename(relativePath)));
  file.writeAsBytesSync(List<int>.filled(byteLength, 1), flush: true);
  return file.path;
}

CockpitRunBatchResult _successfulBatchResult(CockpitRunBatchRequest request) {
  return CockpitRunBatchResult(
    results: request.commands
        .map(
          (batchCommand) => _successfulCommandResult(
            batchCommand.command,
            includeScreenshot: cockpitCommandTypeIsAiEvidenceKeyOperation(
              batchCommand.command.commandType,
            ),
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
}

CockpitReadNetworkResult _successfulNetworkResult() {
  return CockpitReadNetworkResult(
    appId: 'network-app',
    source: 'app_snapshot',
    available: true,
    routeName: '/inbox',
    summary: CockpitReadNetworkSummary(
      totalEntryCount: 0,
      failureCount: 0,
      capturedEntryCount: 0,
      inFlightCount: 0,
      truncated: false,
      query: const CockpitNetworkQuery(),
    ),
    endpointSummaries: const <CockpitNetworkEndpointSummary>[],
    endpointSummariesTruncated: false,
    recentFailures: const <CockpitNetworkEntry>[],
  );
}

CockpitInspectSurfaceResult _inspectSurfaceResult(CockpitAppHandle app) {
  return CockpitInspectSurfaceResult(
    target: CockpitTargetHandle.fromAppHandle(app),
    capabilityProfile: CockpitCapabilityProfile(
      targetKind: CockpitTargetKind.flutterApp,
      surfaceKinds: <CockpitSurfaceKind>{CockpitSurfaceKind.flutterSemantic},
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
}

CockpitHotReloadResult _successfulHotReload(CockpitAppHandle app) {
  return CockpitHotReloadResult(
    app: app,
    status: CockpitDevelopmentSessionStatus(
      developmentSessionId: '${app.platform}-session',
      state: CockpitDevelopmentSessionState.ready,
      appReachable: true,
      remoteSessionReachable: true,
      reloadGeneration: 1,
      lastReloadMode: CockpitDevelopmentReloadMode.hotReload,
      lastReloadSucceeded: true,
      lastStatusAt: DateTime.utc(2026, 4, 12),
    ),
  );
}

CockpitHotRestartResult _successfulHotRestart(CockpitAppHandle app) {
  return CockpitHotRestartResult(
    app: app,
    status: CockpitDevelopmentSessionStatus(
      developmentSessionId: '${app.platform}-session',
      state: CockpitDevelopmentSessionState.ready,
      appReachable: true,
      remoteSessionReachable: true,
      reloadGeneration: 2,
      lastReloadMode: CockpitDevelopmentReloadMode.hotRestart,
      lastReloadSucceeded: true,
      lastStatusAt: DateTime.utc(2026, 4, 12, 0, 0, 1),
    ),
  );
}

String? _fakeSystemClipboardText;

Future<CockpitSystemControlDescribeResult> _fakeDescribeSystemControl(
  CockpitSystemControlDescribeRequest request,
) {
  final metadata = <String, Object?>{...request.metadata};
  if (request.platform == 'android') {
    metadata['androidDeviceReachable'] = true;
    metadata['androidDeviceState'] = 'device';
  }
  return CockpitSystemControlService().describe(
    CockpitSystemControlDescribeRequest(
      platform: request.platform,
      deviceId: request.deviceId,
      appId: request.appId,
      processId: request.processId,
      metadata: metadata,
    ),
  );
}

Future<CockpitSystemControlActionResult> _fakeRunSystemAction(
  CockpitSystemControlActionRequest request,
) async {
  final describe = await _fakeDescribeSystemControl(
    CockpitSystemControlDescribeRequest(
      platform: request.platform,
      deviceId: request.deviceId,
      appId: request.appId,
      processId: request.processId,
    ),
  );
  final capability = describe.profile.capabilityFor(request.action);
  final availability =
      capability?.availability ?? CockpitSystemControlAvailability.unsupported;
  if (availability != CockpitSystemControlAvailability.available) {
    return CockpitSystemControlActionResult(
      platform: request.platform,
      deviceId: request.deviceId,
      appId: request.appId,
      processId: request.processId,
      action: request.action,
      availability: availability,
      success: false,
      recommendedNextStep: 'readSystemCapabilities',
      errorCode: 'systemActionNotAvailable',
      errorMessage: '${request.action.name} is not available in this test.',
      strategy: capability?.strategy,
      requires: capability?.requires ?? const <String>[],
      limitations: capability?.limitations ?? const <String>[],
    );
  }

  String? stdout;
  if (request.action == CockpitSystemControlAction.setClipboard) {
    _fakeSystemClipboardText = request.parameters['text'] as String?;
  } else if (request.action == CockpitSystemControlAction.getClipboard) {
    stdout = _fakeSystemClipboardText ?? '';
  } else if (request.action == CockpitSystemControlAction.readSystemState) {
    stdout = 'fake ${request.platform} system state';
  } else if (request.action == CockpitSystemControlAction.readProcessList) {
    stdout = 'fake ${request.platform} process list';
  }

  return CockpitSystemControlActionResult(
    platform: request.platform,
    deviceId: request.deviceId,
    appId: request.appId,
    processId: request.processId,
    action: request.action,
    availability: availability,
    success: true,
    command: <String>['fake-system-control', request.action.name],
    stdout: stdout,
    recommendedNextStep: 'readPostActionState',
    strategy: capability?.strategy,
    requires: capability?.requires ?? const <String>[],
    limitations: capability?.limitations ?? const <String>[],
  );
}

final class _FakeRecordingAdapter implements CockpitRecordingAdapter {
  const _FakeRecordingAdapter({required this.onStart, required this.onStop});

  final Future<CockpitRecordingSession> Function(
    CockpitRecordingRequest request,
  )
  onStart;
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

Future<void> _createDatabaseArtifacts(String containerPath) async {
  final documents = Directory(p.join(containerPath, 'Documents'));
  await documents.create(recursive: true);
  for (final filename in _databaseArtifactFilenames) {
    await File(p.join(documents.path, filename)).writeAsString('stale');
  }
}

bool _databaseArtifactsExist(String containerPath) {
  final documents = p.join(containerPath, 'Documents');
  return _databaseArtifactFilenames.any(
    (filename) => File(p.join(documents, filename)).existsSync(),
  );
}

const List<String> _databaseArtifactFilenames = <String>[
  'cockpit_demo.sqlite',
  'cockpit_demo.sqlite-shm',
  'cockpit_demo.sqlite-wal',
];

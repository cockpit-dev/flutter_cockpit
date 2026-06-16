import 'dart:io';

import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:cockpit/cockpit.dart';
import 'package:flutter_test/flutter_test.dart';

import '../tool/src/cockpit_demo_platform_verifier.dart';
import '../tool/src/cockpit_demo_rapid_dev_verifier.dart';

void main() {
  test(
    'rapid verifier validates the low-cost edit reload loop on local targets',
    () async {
      final launchRequests = <CockpitLaunchAppRequest>[];
      final batchRequests = <CockpitRunBatchRequest>[];
      final commandRequests = <CockpitRunCommandRequest>[];
      final bootCommands = <String>[];
      final stoppedPlatforms = <String>[];
      final waitIdlePlatforms = <String>[];
      final readErrorPlatforms = <String>[];
      var probeCall = 0;

      final verifier = CockpitDemoRapidDevVerifier(
        probeDevices: () async {
          probeCall += 1;
          return switch (probeCall) {
            1 => _devices(macos: true),
            2 => _devices(macos: true),
            3 => _devices(macos: true, ios: true),
            4 => _devices(macos: true, ios: true),
            _ => _devices(macos: true, ios: true, android: true),
          };
        },
        listIosSimulators: () async => const <CockpitDemoIosSimulator>[
          CockpitDemoIosSimulator(
            name: 'iPhone 17 Pro',
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
        clock: () => DateTime.utc(2026, 5, 22, 9, 30, probeCall),
        launchApp: (request) async {
          launchRequests.add(request);
          return CockpitLaunchAppResult(
            app: _appForPlatform(
              platform: request.platform,
              deviceId: request.deviceId,
              baseUrl: 'http://127.0.0.1:${request.sessionPort}',
            ),
            appJsonPath:
                '${request.projectDir}/.dart_tool/cockpit_rapid_dev/${request.platform}/app.json',
          );
        },
        readApp: (request) async => _readAppResult(request.app!),
        runBatch: (request) async {
          batchRequests.add(request);
          return CockpitRunBatchResult(
            results: request.commands
                .map(
                  (entry) => CockpitExecuteRemoteCommandResult(
                    command: _commandCore(entry.command),
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
            finalSnapshot: CockpitReadRemoteSnapshotResult(
              routeName: '/inbox',
              diagnosticLevel: 'baseline',
              truncated: false,
              uiSummary: const CockpitInteractiveSnapshotSummary(
                routeName: '/inbox',
                diagnosticLevel: 'baseline',
                truncated: false,
                visibleTargetCount: 7,
                targetsWithCockpitIdCount: 0,
                targetsWithTextCount: 7,
                networkEntryCount: 0,
                networkFailureCount: 0,
                runtimeEntryCount: 0,
                runtimeErrorCount: 0,
                rebuildEntryCount: 0,
                totalRebuildCount: 0,
                accessibilityTargetCount: 0,
                accessibilityTraversalCount: 0,
                textPreviews: <String>[
                  'Queue brief: 1 active / 1 due today / 1 priority / 0 conflicts',
                ],
              ),
            ),
          );
        },
        runCommand: (request) async {
          commandRequests.add(request);
          return CockpitExecuteRemoteCommandResult(
            command: _commandCore(request.command),
            artifacts:
                request.command.commandType ==
                    CockpitCommandType.captureScreenshot
                ? const <CockpitInteractiveArtifactDescriptor>[
                    CockpitInteractiveArtifactDescriptor(
                      role: 'screenshot',
                      relativePath: 'screenshots/rapid_queue_brief.png',
                      byteLength: 2048,
                    ),
                  ]
                : const <CockpitInteractiveArtifactDescriptor>[],
          );
        },
        waitIdle: (request) async {
          waitIdlePlatforms.add(request.app!.platform);
          return const CockpitWaitIdleResult(
            idle: true,
            durationMs: 180,
            quietWindowMs: 120,
            timeoutMs: 4000,
            includeNetworkIdle: true,
          );
        },
        hotReload: (request) async {
          return CockpitHotReloadResult(
            app: request.app!,
            status: CockpitDevelopmentSessionStatus(
              developmentSessionId: '${request.app!.platform}-dev',
              state: CockpitDevelopmentSessionState.ready,
              appReachable: true,
              remoteSessionReachable: true,
              reloadGeneration: 3,
              lastReloadMode: CockpitDevelopmentReloadMode.hotReload,
              lastReloadSucceeded: true,
              lastStatusAt: DateTime.utc(2026, 5, 22, 9, 31),
            ),
          );
        },
        readErrors: (request) async {
          readErrorPlatforms.add('${request.baseUri}');
          return const CockpitReadErrorsResult(
            appId: 'rapid-errors',
            source: 'app_snapshot',
            routeName: '/inbox',
            errors: <CockpitErrorEntry>[],
          );
        },
        stopApp: (request) async {
          stoppedPlatforms.add(request.app!.platform);
          return CockpitStopAppResult(
            app: request.app!,
            status: CockpitAppStopStatus.stopped(mode: request.app!.mode),
          );
        },
      );

      final result = await verifier.verify(
        const CockpitDemoRapidVerificationRequest(
          projectDir: '/workspace/examples/cockpit_demo',
          platforms: <String>['macos', 'ios', 'android'],
          outputRoot: '/tmp/cockpit_rapid_dev',
        ),
      );

      expect(result.success, isTrue);
      expect(result.platforms.map((platform) => platform.platform), <String>[
        'macos',
        'ios',
        'android',
      ]);
      expect(
        result.platforms.map((platform) => platform.status),
        everyElement('passed'),
      );
      expect(launchRequests.map((request) => request.deviceId), <String>[
        'macos',
        'FC5B7D0F-B7FB-4A7A-B1B0-FF28BC289BC2',
        'emulator-5554',
      ]);
      expect(
        bootCommands,
        contains('xcrun simctl boot FC5B7D0F-B7FB-4A7A-B1B0-FF28BC289BC2'),
      );
      expect(bootCommands, contains('flutter emulators --launch Pixel_9_Pro'));
      expect(batchRequests, hasLength(3));
      expect(
        batchRequests.first.commands
            .map((entry) => entry.command.commandId)
            .toList(growable: false),
        <String>[
          'rapid-open-editor',
          'rapid-enter-title',
          'rapid-reveal-notes',
          'rapid-enter-notes',
          'rapid-reveal-high-priority',
          'rapid-select-high-priority',
          'rapid-reveal-today',
          'rapid-select-today',
          'rapid-save-task',
          'rapid-wait-inbox',
          'rapid-wait-queue-brief',
        ],
      );
      expect(
        batchRequests.first.defaultResultProfile.name,
        CockpitInteractiveResultProfileName.minimal,
      );
      expect(
        batchRequests.first.finalSnapshotProfile?.name,
        CockpitInteractiveResultProfileName.standard,
      );
      expect(waitIdlePlatforms, <String>['macos', 'ios', 'android']);
      expect(
        commandRequests.map((request) => request.command.commandId),
        <String>[
          'rapid-assert-queue-brief',
          'rapid-assert-created-task',
          'rapid-capture-queue-brief',
          'rapid-assert-queue-brief',
          'rapid-assert-created-task',
          'rapid-capture-queue-brief',
          'rapid-assert-queue-brief',
          'rapid-assert-created-task',
          'rapid-capture-queue-brief',
        ],
      );
      expect(readErrorPlatforms, hasLength(3));
      expect(stoppedPlatforms, <String>['macos', 'ios', 'android']);
      expect(
        result.platforms.map((platform) => platform.queueBrief),
        everyElement(
          'Queue brief: 1 active / 1 due today / 1 priority / 0 conflicts',
        ),
      );
      expect(
        result.platforms.map((platform) => platform.screenshotArtifactRef),
        everyElement('screenshots/rapid_queue_brief.png'),
      );
      expect(result.platforms.first.verifiedCommands, <String>[
        'launch-app',
        'read-app',
        'run-batch',
        'wait-idle',
        'hot-reload',
        'assert-text',
        'capture-screenshot',
        'read-errors',
      ]);
    },
  );

  test(
    'rapid verifier failure keeps progress and final snapshot evidence',
    () async {
      final verifier = CockpitDemoRapidDevVerifier(
        probeDevices: () async => _devices(macos: true),
        runProcess: (executable, arguments, {String? workingDirectory}) async {
          return ProcessResult(0, 0, '', '');
        },
        wait: (_) async {},
        clock: () => DateTime.utc(2026, 5, 22, 10),
        launchApp: (request) async {
          return CockpitLaunchAppResult(
            app: _appForPlatform(
              platform: request.platform,
              deviceId: request.deviceId,
              baseUrl: 'http://127.0.0.1:${request.sessionPort}',
            ),
            appJsonPath:
                '${request.projectDir}/.dart_tool/cockpit_rapid_dev/${request.platform}/app.json',
          );
        },
        readApp: (request) async => _readAppResult(request.app!),
        runBatch: (request) async {
          final results = <CockpitExecuteRemoteCommandResult>[];
          for (var index = 0; index < request.commands.length; index += 1) {
            final command = request.commands[index].command;
            final last = index == request.commands.length - 1;
            results.add(
              CockpitExecuteRemoteCommandResult(
                command: _commandCore(
                  command,
                  success: !last,
                  error: last
                      ? CockpitCommandError.timeout(
                          message: 'Timed out waiting for queue brief.',
                          details: const <String, Object?>{
                            'waitCondition': 'queue brief',
                          },
                        )
                      : null,
                ),
                artifacts: const <CockpitInteractiveArtifactDescriptor>[],
              ),
            );
          }
          return CockpitRunBatchResult(
            results: results,
            summary: const CockpitExecuteRemoteCommandBatchSummary(
              totalCount: 11,
              successCount: 10,
              failureCount: 1,
              stoppedEarly: true,
            ),
            finalSnapshot: const CockpitReadRemoteSnapshotResult(
              routeName: '/inbox',
              diagnosticLevel: 'baseline',
              truncated: false,
              uiSummary: CockpitInteractiveSnapshotSummary(
                routeName: '/inbox',
                diagnosticLevel: 'baseline',
                truncated: false,
                visibleTargetCount: 9,
                targetsWithCockpitIdCount: 0,
                targetsWithTextCount: 9,
                networkEntryCount: 0,
                networkFailureCount: 0,
                runtimeEntryCount: 0,
                runtimeErrorCount: 0,
                rebuildEntryCount: 0,
                totalRebuildCount: 0,
                accessibilityTargetCount: 0,
                accessibilityTraversalCount: 0,
                textPreviews: <String>[
                  'Queue brief: 2 active / 2 due today / 2 priority / 0 conflicts',
                  'Rapid AI loop macos_1779434400000000',
                ],
              ),
            ),
          );
        },
        stopApp: (request) async => CockpitStopAppResult(
          app: request.app!,
          status: CockpitAppStopStatus.stopped(mode: request.app!.mode),
        ),
      );

      final result = await verifier.verify(
        const CockpitDemoRapidVerificationRequest(
          projectDir: '/workspace/examples/cockpit_demo',
          platforms: <String>['macos'],
          outputRoot: '/tmp/cockpit_rapid_dev',
        ),
      );

      expect(result.success, isFalse);
      final platform = result.platforms.single;
      expect(platform.failureCode, 'rapidBatchFailed');
      expect(platform.verifiedCommands, <String>['launch-app', 'read-app']);
      final json = platform.toJson();
      expect(json['failureDetails'], isA<Map<String, Object?>>());
      final details = json['failureDetails']! as Map<String, Object?>;
      expect(details['commandId'], 'rapid-wait-queue-brief');
      expect(details['finalRouteName'], '/inbox');
      expect(
        details['finalTextPreviews'],
        contains(
          'Queue brief: 2 active / 2 due today / 2 priority / 0 conflicts',
        ),
      );
    },
  );

  test(
    'rapid verifier failure includes bounded runtime error previews',
    () async {
      final verifier = CockpitDemoRapidDevVerifier(
        probeDevices: () async => _devices(macos: true),
        runProcess: (executable, arguments, {String? workingDirectory}) async {
          return ProcessResult(0, 0, '', '');
        },
        wait: (_) async {},
        clock: () => DateTime.utc(2026, 5, 22, 11),
        launchApp: (request) async {
          return CockpitLaunchAppResult(
            app: _appForPlatform(
              platform: request.platform,
              deviceId: request.deviceId,
              baseUrl: 'http://127.0.0.1:${request.sessionPort}',
            ),
            appJsonPath:
                '${request.projectDir}/.dart_tool/cockpit_rapid_dev/${request.platform}/app.json',
          );
        },
        readApp: (request) async => _readAppResult(request.app!),
        runBatch: (request) async => CockpitRunBatchResult(
          results: request.commands
              .map(
                (entry) => CockpitExecuteRemoteCommandResult(
                  command: _commandCore(entry.command),
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
          finalSnapshot: const CockpitReadRemoteSnapshotResult(
            routeName: '/inbox',
            diagnosticLevel: 'baseline',
            truncated: false,
          ),
        ),
        runCommand: (request) async => CockpitExecuteRemoteCommandResult(
          command: _commandCore(request.command),
          artifacts:
              request.command.commandType ==
                  CockpitCommandType.captureScreenshot
              ? const <CockpitInteractiveArtifactDescriptor>[
                  CockpitInteractiveArtifactDescriptor(
                    role: 'screenshot',
                    relativePath: 'screenshots/rapid_queue_brief.png',
                    byteLength: 2048,
                  ),
                ]
              : const <CockpitInteractiveArtifactDescriptor>[],
        ),
        waitIdle: (request) async => const CockpitWaitIdleResult(
          idle: true,
          durationMs: 180,
          quietWindowMs: 120,
          timeoutMs: 4000,
          includeNetworkIdle: true,
        ),
        hotReload: (request) async => CockpitHotReloadResult(
          app: request.app!,
          status: CockpitDevelopmentSessionStatus(
            developmentSessionId: 'macos-dev',
            state: CockpitDevelopmentSessionState.ready,
            appReachable: true,
            remoteSessionReachable: true,
            reloadGeneration: 1,
            lastReloadMode: CockpitDevelopmentReloadMode.hotReload,
            lastReloadSucceeded: true,
            lastStatusAt: DateTime.utc(2026, 5, 22, 11, 1),
          ),
        ),
        readErrors: (request) async => CockpitReadErrorsResult(
          appId: 'rapid-errors',
          source: 'app_snapshot',
          routeName: '/inbox',
          errors: <CockpitErrorEntry>[
            CockpitErrorEntry(
              source: 'app_snapshot',
              message: 'SQLiteException: stale database state caused failure',
              recordedAt: DateTime.utc(2026, 5, 22, 11, 2),
              kind: 'flutter_error',
              routeName: '/inbox',
            ),
          ],
        ),
        stopApp: (request) async => CockpitStopAppResult(
          app: request.app!,
          status: CockpitAppStopStatus.stopped(mode: request.app!.mode),
        ),
      );

      final result = await verifier.verify(
        const CockpitDemoRapidVerificationRequest(
          projectDir: '/workspace/examples/cockpit_demo',
          platforms: <String>['macos'],
          outputRoot: '/tmp/cockpit_rapid_dev',
        ),
      );

      expect(result.success, isFalse);
      final platform = result.platforms.single;
      expect(platform.failureCode, 'runtimeErrorsDetected');
      expect(platform.verifiedCommands, <String>[
        'launch-app',
        'read-app',
        'run-batch',
        'wait-idle',
        'hot-reload',
        'assert-text',
        'capture-screenshot',
      ]);
      final json = platform.toJson();
      expect(json['runtimeErrorPreviews'], isA<List<Object?>>());
      final previews = json['runtimeErrorPreviews']! as List<Object?>;
      expect(previews, hasLength(1));
      expect(previews.single, isA<Map<String, Object?>>());
      final preview = previews.single! as Map<String, Object?>;
      expect(preview['routeName'], '/inbox');
      expect(
        preview['message'],
        contains('SQLiteException: stale database state caused failure'),
      );
    },
  );
}

List<CockpitDemoHostDevice> _devices({
  bool macos = false,
  bool ios = false,
  bool android = false,
}) {
  return <CockpitDemoHostDevice>[
    if (macos)
      const CockpitDemoHostDevice(
        name: 'macOS',
        deviceId: 'macos',
        platform: 'macos',
        emulator: false,
        supported: true,
      ),
    if (ios)
      const CockpitDemoHostDevice(
        name: 'iPhone 17 Pro',
        deviceId: 'FC5B7D0F-B7FB-4A7A-B1B0-FF28BC289BC2',
        platform: 'ios',
        emulator: true,
        supported: true,
      ),
    if (android)
      const CockpitDemoHostDevice(
        name: 'Pixel 9 Pro',
        deviceId: 'emulator-5554',
        platform: 'android',
        emulator: true,
        supported: true,
      ),
  ];
}

CockpitReadAppResult _readAppResult(CockpitAppHandle app) {
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
        CockpitCommandType.captureScreenshot,
      ],
      supportedLocatorStrategies: CockpitLocatorKind.values,
    ),
    recordingCapabilities: CockpitRecordingCapabilities(
      supportsNativeRecording: false,
    ),
    currentRouteName: '/inbox',
  );
}

CockpitInteractiveCommandCore _commandCore(
  CockpitCommand command, {
  bool success = true,
  CockpitCommandError? error,
}) {
  return CockpitInteractiveCommandCore(
    commandId: command.commandId,
    commandType: command.commandType.name,
    success: success,
    durationMs: 12,
    usedCaptureFallback: false,
    error: error,
  );
}

CockpitAppHandle _appForPlatform({
  required String platform,
  required String deviceId,
  required String baseUrl,
}) {
  final launchedAt = DateTime.utc(2026, 5, 22, 9);
  final port = Uri.parse(baseUrl).port;
  final remoteSession = CockpitRemoteSessionHandle(
    platform: platform,
    deviceId: deviceId,
    projectDir: '/workspace/examples/cockpit_demo',
    target: 'lib/main.dart',
    appId: '$platform-app',
    host: '127.0.0.1',
    hostPort: port,
    devicePort: port,
    baseUrl: baseUrl,
    launchedAt: launchedAt,
  );
  return CockpitAppHandle(
    appId: '$platform-app',
    mode: CockpitAppMode.development,
    platform: platform,
    deviceId: deviceId,
    projectDir: '/workspace/examples/cockpit_demo',
    target: 'lib/main.dart',
    baseUrl: baseUrl,
    launchedAt: launchedAt,
    remoteSession: remoteSession,
    developmentSession: CockpitDevelopmentSessionHandle(
      developmentSessionId: '$platform-dev',
      platform: platform,
      deviceId: deviceId,
      projectDir: '/workspace/examples/cockpit_demo',
      target: 'lib/main.dart',
      appId: '$platform-app',
      appBaseUrl: baseUrl,
      supervisorBaseUrl: 'http://127.0.0.1:${port + 1000}',
      launchedAt: launchedAt,
      reloadGeneration: 0,
      remoteSessionHandle: remoteSession,
    ),
  );
}

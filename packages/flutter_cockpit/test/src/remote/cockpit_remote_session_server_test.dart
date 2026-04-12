import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_cockpit/flutter_cockpit_flutter.dart';
import 'package:flutter_cockpit/src/remote/cockpit_remote_session_server.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(FlutterCockpit.dispose);

  testWidgets(
    'remote session executes commands against native-discovered widgets',
    (tester) async {
      final controller = CockpitSessionController(
        sessionId: 'remote-native-discovery-session',
        taskId: 'remote-native-discovery-task',
        platform: 'android',
      );
      final registry = CockpitTargetRegistry(routeName: '/home');

      await tester.pumpWidget(
        _RemoteNativeDiscoveryTestApp(
          controller: controller,
          registry: registry,
          configuration: FlutterCockpitConfiguration(
            initialRouteName: '/home',
            remoteSession: const CockpitRemoteSessionConfiguration(
              enabled: true,
              autoStart: false,
              port: 0,
            ),
            nativeRecording: _FakeCockpitNativeRecording(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final rootState = tester.state<FlutterCockpitRootState>(
        find.byType(FlutterCockpitRoot),
      );
      final baseUri = await tester.runAsync(() async {
        return rootState.waitForRemoteSession().timeout(
              const Duration(seconds: 5),
              onTimeout: () => throw TimeoutException('waitForRemoteSession'),
            );
      });

      final healthJson = await tester.runAsync(() async {
        return _readJson(baseUri!.resolve('/health'));
      });
      final health = CockpitRemoteSessionStatus.fromJson(healthJson!);
      final nativeButton = health.snapshot.visibleTargets.firstWhere(
        (target) => target.keyValue == 'native-open-form-button',
      );

      expect(nativeButton.text, 'Open form');
      expect(nativeButton.tooltip, 'Open the remote form');
      expect(nativeButton.semanticId, 'Open form');
      expect(nativeButton.supportedCommands, contains(CockpitCommandType.tap));

      final responseJson = await tester.runAsync(() async {
        return _postJson(
          baseUri!.resolve('/commands/execute'),
          CockpitCommand(
            commandId: 'tap-native-open-form',
            commandType: CockpitCommandType.tap,
            locator: const CockpitLocator(
              key: 'native-open-form-button',
            ),
          ).toJson(),
        );
      });
      final response = CockpitRemoteCommandResponse.fromJson(responseJson!);

      expect(response.result.success, isTrue);

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(rootState.snapshot().routeName, '/form');
    },
  );

  testWidgets(
    'remote session health and command execution expose live app state',
    (tester) async {
      final controller = CockpitSessionController(
        sessionId: 'remote-health-session',
        taskId: 'remote-health-task',
        platform: 'android',
      );
      final registry = CockpitTargetRegistry(routeName: '/home');

      await tester.pumpWidget(
        _RemoteTestApp(
          controller: controller,
          registry: registry,
          configuration: FlutterCockpitConfiguration(
            initialRouteName: '/home',
            remoteSession: const CockpitRemoteSessionConfiguration(
              enabled: true,
              autoStart: false,
              port: 0,
            ),
            nativeRecording: _FakeCockpitNativeRecording(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final rootState = tester.state<FlutterCockpitRootState>(
        find.byType(FlutterCockpitRoot),
      );
      final baseUri = await tester.runAsync(() {
        return rootState.waitForRemoteSession().timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            throw TimeoutException('waitForRemoteSession');
          },
        );
      }).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw TimeoutException('waitForRemoteSession');
        },
      );

      final healthJson = await tester.runAsync(() {
        return _readJson(baseUri!.resolve('/health'));
      }).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw TimeoutException('health');
        },
      );
      final health = CockpitRemoteSessionStatus.fromJson(healthJson!);
      expect(health.capabilities.supportsInAppControl, isTrue);
      expect(health.snapshot.routeName, '/home');
      expect(health.snapshot.diagnosticLevel, CockpitSnapshotProfile.live);
      expect(
        health.capabilities.supportedCommands,
        containsAll(<CockpitCommandType>[
          CockpitCommandType.assertVisible,
          CockpitCommandType.assertText,
          CockpitCommandType.waitFor,
          CockpitCommandType.collectSnapshot,
          CockpitCommandType.captureScreenshot,
        ]),
      );

      final responseJson = await tester.runAsync(() {
        return _postJson(
          baseUri!.resolve('/commands/execute'),
          CockpitCommand(
            commandId: 'tap-open-form',
            commandType: CockpitCommandType.tap,
            locator: const CockpitLocator(
              cockpitId: 'open_form_button',
            ),
          ).toJson(),
        );
      }).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw TimeoutException('executeCommand');
        },
      );
      final response = CockpitRemoteCommandResponse.fromJson(responseJson!);
      final result = response.result;

      expect(result.success, isTrue);

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(rootState.snapshot().routeName, '/form');
    },
  );

  testWidgets(
    'remote command responses drain runtime steps without an explicit session controller',
    (tester) async {
      FlutterCockpit.initialize(
        FlutterCockpitConfiguration(
          initialRouteName: '/editor',
          remoteSession: CockpitRemoteSessionConfiguration(
            enabled: true,
            autoStart: false,
            port: 0,
          ),
          nativeRecording: _FakeCockpitNativeRecording(),
        ),
      );

      final rootKey = GlobalKey<FlutterCockpitRootState>();

      await tester.pumpWidget(
        FlutterCockpitRoot(
          key: rootKey,
          child: MaterialApp(
            navigatorObservers: <NavigatorObserver>[
              FlutterCockpit.navigatorObserver,
            ],
            home: Scaffold(
              body: Center(
                child: ElevatedButton(
                  key: const ValueKey<String>('runtime-step-button'),
                  onPressed: () {
                    FlutterCockpit.recordStep(
                      actionType: 'validation_error',
                      actionArgs: const <String, Object?>{
                        'message': 'Task title is required.',
                        'field': 'title',
                      },
                      observation: CockpitObservation(
                        routeName: '/editor',
                        interactiveElements: <String>['Save task'],
                        phase: CockpitObservationPhase.failure,
                      ),
                    );
                  },
                  child: const Text('Save task'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final baseUri = await tester.runAsync(() async {
        return rootKey.currentState!.waitForRemoteSession().timeout(
              const Duration(seconds: 5),
              onTimeout: () => throw TimeoutException('waitForRemoteSession'),
            );
      });

      final responseJson = await tester.runAsync(() async {
        return _postJson(
          baseUri!.resolve('/commands/execute'),
          CockpitCommand(
            commandId: 'tap-runtime-step',
            commandType: CockpitCommandType.tap,
            locator: const CockpitLocator(
              key: 'runtime-step-button',
            ),
          ).toJson(),
        );
      });
      final response = CockpitRemoteCommandResponse.fromJson(responseJson!);

      expect(response.result.success, isTrue);
      expect(response.runtimeSteps, hasLength(1));
      expect(response.runtimeSteps.single.actionType, 'validation_error');
      expect(
        response.runtimeSteps.single.actionArgs['message'],
        'Task title is required.',
      );
    },
  );

  testWidgets(
    'remote snapshot endpoint supports explicit diagnostic profile escalation without bloating health',
    (tester) async {
      final controller = CockpitSessionController(
        sessionId: 'remote-snapshot-session',
        taskId: 'remote-snapshot-task',
        platform: 'android',
      );
      final registry = CockpitTargetRegistry(routeName: '/home');

      await tester.pumpWidget(
        _RemoteTestApp(
          controller: controller,
          registry: registry,
          configuration: FlutterCockpitConfiguration(
            initialRouteName: '/home',
            remoteSession: const CockpitRemoteSessionConfiguration(
              enabled: true,
              autoStart: false,
              port: 0,
            ),
            nativeRecording: _FakeCockpitNativeRecording(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final rootState = tester.state<FlutterCockpitRootState>(
        find.byType(FlutterCockpitRoot),
      );
      final baseUri = await tester.runAsync(() async {
        return rootState.waitForRemoteSession().timeout(
              const Duration(seconds: 5),
              onTimeout: () => throw TimeoutException('waitForRemoteSession'),
            );
      });

      final healthJson = await tester.runAsync(() async {
        return _readJson(baseUri!.resolve('/health'));
      });
      final health = CockpitRemoteSessionStatus.fromJson(healthJson!);

      final snapshotJson = await tester.runAsync(() async {
        return _readJson(
          baseUri!.resolve(
            '/snapshot?profile=investigate&includeStyleDetails=true&includeDiagnosticProperties=true',
          ),
        );
      });
      final snapshot = CockpitSnapshot.fromJson(snapshotJson!);

      expect(health.snapshot.diagnosticLevel, CockpitSnapshotProfile.live);
      expect(snapshot.diagnosticLevel, CockpitSnapshotProfile.investigate);
      expect(snapshot.visibleTargets, isNotEmpty);
      expect(
        snapshot.visibleTargets.any((target) => target.layout != null),
        isTrue,
      );
    },
  );

  test(
    'remote session health output omits null fields',
    () async {
      final server = CockpitRemoteSessionServer(
        configuration: const CockpitRemoteSessionConfiguration(
          enabled: true,
          autoStart: false,
          port: 0,
        ),
        statusProvider: () async => CockpitRemoteSessionStatus(
          sessionId: 'remote-health-compact',
          platform: 'android',
          transportType: 'remoteHttp',
          currentRouteName: null,
          capabilities: CockpitCapabilities(
            platform: 'android',
            transportType: 'remoteHttp',
            supportsInAppControl: true,
            supportsFlutterViewCapture: true,
            supportsNativeScreenCapture: false,
            supportsHostAutomation: false,
            supportedCommands: const <CockpitCommandType>[
              CockpitCommandType.collectSnapshot,
            ],
            supportedLocatorStrategies: CockpitLocatorKind.values,
          ),
          recordingCapabilities: CockpitRecordingCapabilities(
            supportsNativeRecording: false,
            preferredAcceptanceRecordingKind: CockpitRecordingKind.nativeScreen,
          ),
          snapshot: CockpitSnapshot(routeName: '/home'),
        ),
        snapshotProvider: ({required options}) async => CockpitSnapshot(
          routeName: '/home',
          diagnosticLevel: options.profile,
        ),
        commandExecutor: (_) async => CockpitCommandExecution(
          result: CockpitCommandResult(
            success: true,
            commandId: 'noop',
            commandType: CockpitCommandType.collectSnapshot,
            durationMs: 0,
          ),
        ),
        startRecording: (request) async => CockpitRecordingSession(
          request: request,
          state: CockpitRecordingState.recording,
        ),
        stopRecording: () async =>
            CockpitRecordingResult(state: CockpitRecordingState.failed),
      );
      await server.start();
      addTearDown(server.close);

      final healthJson = await _readJson(server.baseUri!.resolve('/health'));

      expect(healthJson, isNotNull);
      expect(healthJson['sessionId'], 'remote-health-compact');
      expect(healthJson.containsKey('currentRouteName'), isFalse);
      expect(healthJson.containsKey('environment'), isFalse);
      expect(healthJson.containsKey('activeRecording'), isFalse);
    },
  );

  test(
    'remote snapshot endpoint forwards network diagnostic query parameters',
    () async {
      CockpitSnapshotOptions? capturedOptions;
      final server = CockpitRemoteSessionServer(
        configuration: const CockpitRemoteSessionConfiguration(
          enabled: true,
          autoStart: false,
          port: 0,
        ),
        statusProvider: () async => CockpitRemoteSessionStatus(
          sessionId: 'remote-network-options',
          platform: 'android',
          transportType: 'remoteHttp',
          currentRouteName: '/home',
          capabilities: CockpitCapabilities(
            platform: 'android',
            transportType: 'remoteHttp',
            supportsInAppControl: true,
            supportsFlutterViewCapture: true,
            supportsNativeScreenCapture: false,
            supportsHostAutomation: false,
            supportedCommands: const <CockpitCommandType>[
              CockpitCommandType.collectSnapshot,
            ],
            supportedLocatorStrategies: CockpitLocatorKind.values,
          ),
          recordingCapabilities: CockpitRecordingCapabilities(
            supportsNativeRecording: false,
            preferredAcceptanceRecordingKind: CockpitRecordingKind.nativeScreen,
          ),
          snapshot: CockpitSnapshot(routeName: '/home'),
        ),
        snapshotProvider: ({required options}) async {
          capturedOptions = options;
          return CockpitSnapshot(
            routeName: '/home',
            diagnosticLevel: options.profile,
          );
        },
        commandExecutor: (_) async => CockpitCommandExecution(
          result: CockpitCommandResult(
            success: true,
            commandId: 'noop',
            commandType: CockpitCommandType.collectSnapshot,
            durationMs: 0,
          ),
        ),
        startRecording: (request) async => CockpitRecordingSession(
          request: request,
          state: CockpitRecordingState.recording,
        ),
        stopRecording: () async =>
            CockpitRecordingResult(state: CockpitRecordingState.failed),
      );
      await server.start();
      addTearDown(server.close);

      final baseUri = server.baseUri;
      expect(baseUri, isNotNull);

      await _readJson(
        baseUri!.resolve(
          '/snapshot?profile=forensic&includeNetworkActivity=true&maxNetworkEntries=15&emitArtifactWhenLarge=true&networkOnlyFailures=true&networkMethod=POST&networkUriContains=%2Fsync&networkStatusCodeAtLeast=500',
        ),
      );

      expect(capturedOptions?.profile, CockpitSnapshotProfile.forensic);
      expect(capturedOptions?.includeNetworkActivity, isTrue);
      expect(capturedOptions?.maxNetworkEntries, 15);
      expect(capturedOptions?.emitArtifactWhenLarge, isTrue);
      expect(capturedOptions?.networkQuery.onlyFailures, isTrue);
      expect(capturedOptions?.networkQuery.method, 'POST');
      expect(capturedOptions?.networkQuery.uriContains, '/sync');
      expect(capturedOptions?.networkQuery.statusCodeAtLeast, 500);
    },
  );

  test(
    'remote snapshot endpoint forwards rebuild diagnostic query parameters while health stays lightweight',
    () async {
      CockpitSnapshotOptions? capturedOptions;
      final server = CockpitRemoteSessionServer(
        configuration: const CockpitRemoteSessionConfiguration(
          enabled: true,
          autoStart: false,
          port: 0,
        ),
        statusProvider: () async => CockpitRemoteSessionStatus(
          sessionId: 'remote-rebuild-options',
          platform: 'android',
          transportType: 'remoteHttp',
          currentRouteName: '/home',
          capabilities: CockpitCapabilities(
            platform: 'android',
            transportType: 'remoteHttp',
            supportsInAppControl: true,
            supportsFlutterViewCapture: true,
            supportsNativeScreenCapture: false,
            supportsHostAutomation: false,
            supportedCommands: const <CockpitCommandType>[
              CockpitCommandType.collectSnapshot,
            ],
            supportedLocatorStrategies: CockpitLocatorKind.values,
          ),
          recordingCapabilities: CockpitRecordingCapabilities(
            supportsNativeRecording: false,
            preferredAcceptanceRecordingKind: CockpitRecordingKind.nativeScreen,
          ),
          snapshot: CockpitSnapshot(
            routeName: '/home',
            summary: const CockpitSnapshotSummary(
              visibleTargetCount: 0,
              targetsWithCockpitIdCount: 0,
              targetsWithTextCount: 0,
              styleDetailsIncluded: false,
              diagnosticPropertiesIncluded: false,
              ancestorSummariesIncluded: false,
              rebuildSummaryIncluded: false,
              accessibilitySummaryIncluded: false,
            ),
          ),
        ),
        snapshotProvider: ({required options}) async {
          capturedOptions = options;
          return CockpitSnapshot(
            routeName: '/home',
            diagnosticLevel: options.profile,
            summary: CockpitSnapshotSummary(
              visibleTargetCount: 0,
              targetsWithCockpitIdCount: 0,
              targetsWithTextCount: 0,
              styleDetailsIncluded: options.includeStyleDetails,
              diagnosticPropertiesIncluded: options.includeDiagnosticProperties,
              ancestorSummariesIncluded: options.maxAncestorsPerTarget > 0,
              rebuildSummaryIncluded: options.includeRebuildActivity,
              accessibilitySummaryIncluded: options.includeAccessibilitySummary,
            ),
            rebuild: options.includeRebuildActivity
                ? const CockpitRebuildSnapshot(
                    totalRebuildCount: 4,
                    uniqueElementCount: 1,
                    capturedEntryCount: 1,
                    truncated: false,
                    entries: <CockpitRebuildEntry>[
                      CockpitRebuildEntry(
                        signature: '/home|FilledButton|save|',
                        routeName: '/home',
                        typeName: 'FilledButton',
                        rebuildCount: 4,
                        builtOnceCount: 1,
                        keyValue: 'save',
                      ),
                    ],
                  )
                : null,
          );
        },
        commandExecutor: (_) async => CockpitCommandExecution(
          result: CockpitCommandResult(
            success: true,
            commandId: 'noop',
            commandType: CockpitCommandType.collectSnapshot,
            durationMs: 0,
          ),
        ),
        startRecording: (request) async => CockpitRecordingSession(
          request: request,
          state: CockpitRecordingState.recording,
        ),
        stopRecording: () async =>
            CockpitRecordingResult(state: CockpitRecordingState.failed),
      );
      await server.start();
      addTearDown(server.close);

      final baseUri = server.baseUri;
      expect(baseUri, isNotNull);

      final healthJson = await _readJson(baseUri!.resolve('/health'));
      final health = CockpitRemoteSessionStatus.fromJson(healthJson);

      final snapshotJson = await _readJson(
        baseUri.resolve(
          '/snapshot?profile=investigate&includeRebuildActivity=true&maxRebuildEntries=1',
        ),
      );
      final snapshot = CockpitSnapshot.fromJson(snapshotJson);

      expect(health.snapshot.diagnosticLevel, CockpitSnapshotProfile.live);
      expect(health.snapshot.rebuild, isNull);
      expect(health.snapshot.summary?.rebuildSummaryIncluded, isFalse);
      expect(capturedOptions?.includeRebuildActivity, isTrue);
      expect(capturedOptions?.maxRebuildEntries, 1);
      expect(snapshot.rebuild?.totalRebuildCount, 4);
      expect(snapshot.summary?.rebuildSummaryIncluded, isTrue);
    },
  );

  test(
    'remote snapshot endpoint externalizes large forensic payloads into downloadable diagnostics artifacts',
    () async {
      final server = CockpitRemoteSessionServer(
        configuration: const CockpitRemoteSessionConfiguration(
          enabled: true,
          autoStart: false,
          port: 0,
        ),
        statusProvider: () async => CockpitRemoteSessionStatus(
          sessionId: 'remote-forensic-snapshot',
          platform: 'android',
          transportType: 'remoteHttp',
          currentRouteName: '/debug',
          capabilities: CockpitCapabilities(
            platform: 'android',
            transportType: 'remoteHttp',
            supportsInAppControl: true,
            supportsFlutterViewCapture: true,
            supportsNativeScreenCapture: false,
            supportsHostAutomation: false,
            supportedCommands: const <CockpitCommandType>[
              CockpitCommandType.collectSnapshot,
            ],
            supportedLocatorStrategies: CockpitLocatorKind.values,
          ),
          recordingCapabilities: CockpitRecordingCapabilities(
            supportsNativeRecording: false,
            preferredAcceptanceRecordingKind: CockpitRecordingKind.nativeScreen,
          ),
          snapshot: CockpitSnapshot(routeName: '/debug'),
        ),
        snapshotProvider: ({required options}) async => CockpitSnapshot(
          routeName: '/debug',
          diagnosticLevel: options.profile,
          visibleTargets: <CockpitSnapshotTarget>[
            CockpitSnapshotTarget(
              registrationId: 'debug.sync-check',
              keyValue: 'settings-sync-check-button',
              text: 'Run check',
              typeName: 'FilledButton',
              routeName: '/debug',
              supportedCommands: const <CockpitCommandType>[
                CockpitCommandType.tap,
              ],
              diagnosticProperties: <CockpitDiagnosticProperty>[
                CockpitDiagnosticProperty(
                  name: 'payload',
                  value: 'x' * 24000,
                  category: CockpitDiagnosticCategory.other,
                ),
              ],
            ),
          ],
        ),
        commandExecutor: (_) async => CockpitCommandExecution(
          result: CockpitCommandResult(
            success: true,
            commandId: 'noop',
            commandType: CockpitCommandType.collectSnapshot,
            durationMs: 0,
          ),
        ),
        startRecording: (request) async => CockpitRecordingSession(
          request: request,
          state: CockpitRecordingState.recording,
        ),
        stopRecording: () async =>
            CockpitRecordingResult(state: CockpitRecordingState.failed),
      );
      await server.start();
      addTearDown(server.close);

      final responseJson = await _readJson(
        server.baseUri!.resolve(
          '/snapshot?profile=forensic&includeDiagnosticProperties=true&emitArtifactWhenLarge=true',
        ),
      );

      expect(responseJson['snapshot'], isA<Map<Object?, Object?>>());
      expect(responseJson['artifactDownloads'], isA<List<Object?>>());
      final snapshot = CockpitSnapshot.fromJson(
        Map<String, Object?>.from(
          responseJson['snapshot']! as Map<Object?, Object?>,
        ),
      );
      expect(snapshot.diagnosticsArtifactRef, isNotNull);
      expect(snapshot.visibleTargets.single.diagnosticProperties, isEmpty);

      final downloadPath =
          ((responseJson['artifactDownloads']! as List<Object?>).single
              as Map<Object?, Object?>)['downloadPath']! as String;
      final downloadedJson = await _readJson(
        server.baseUri!.resolve(downloadPath),
      );
      final downloadedSnapshot = CockpitSnapshot.fromJson(downloadedJson);
      expect(
        downloadedSnapshot
            .visibleTargets.single.diagnosticProperties.single.value.length,
        greaterThan(20000),
      );
    },
  );

  testWidgets(
    'remote session health reports native capture support when the plugin is available',
    (tester) async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const captureChannel = MethodChannel(
        'dev.cockpit.flutter_cockpit/capture',
      );
      messenger.setMockMethodCallHandler(captureChannel, (call) async {
        switch (call.method) {
          case 'queryNativeCaptureAvailability':
            return true;
          case 'captureAcceptanceScreenshot':
            return <String, Object?>{
              'bytes': Uint8List.fromList(<int>[137, 80, 78, 71]),
            };
        }
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(captureChannel, null),
      );

      final controller = CockpitSessionController(
        sessionId: 'remote-native-capture-session',
        taskId: 'remote-native-capture-task',
        platform: 'android',
      );
      final registry = CockpitTargetRegistry(routeName: '/home');

      await tester.pumpWidget(
        _RemoteTestApp(
          controller: controller,
          registry: registry,
          configuration: FlutterCockpitConfiguration(
            initialRouteName: '/home',
            remoteSession: const CockpitRemoteSessionConfiguration(
              enabled: true,
              autoStart: false,
              port: 0,
            ),
            nativeCapture: const CockpitNativeCapture(channel: captureChannel),
            nativeRecording: _FakeCockpitNativeRecording(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final rootState = tester.state<FlutterCockpitRootState>(
        find.byType(FlutterCockpitRoot),
      );
      final baseUri = await tester.runAsync(() async {
        return rootState.waitForRemoteSession().timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            throw TimeoutException('waitForRemoteSession');
          },
        );
      });

      final responseJson = await tester.runAsync(() async {
        return _readJson(baseUri!.resolve('/health'));
      });
      final status = CockpitRemoteSessionStatus.fromJson(responseJson!);

      expect(status.capabilities.supportsNativeScreenCapture, isTrue);
    },
  );

  testWidgets(
    'remote session capture command falls back cleanly when native capture is unavailable',
    (tester) async {
      final controller = CockpitSessionController(
        sessionId: 'remote-capture-session',
        taskId: 'remote-capture-task',
        platform: 'ios',
      );
      final registry = CockpitTargetRegistry(routeName: '/home');

      await tester.pumpWidget(
        _RemoteTestApp(
          controller: controller,
          registry: registry,
          configuration: const FlutterCockpitConfiguration(
            initialRouteName: '/home',
            remoteSession: CockpitRemoteSessionConfiguration(
              enabled: true,
              autoStart: false,
              port: 0,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final rootState = tester.state<FlutterCockpitRootState>(
        find.byType(FlutterCockpitRoot),
      );
      final baseUri = await tester.runAsync(() {
        return rootState.waitForRemoteSession().timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            throw TimeoutException('waitForRemoteSession');
          },
        );
      }).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw TimeoutException('waitForRemoteSession');
        },
      );

      final responseJson = await tester.runAsync(() {
        return _postJson(
          baseUri!.resolve('/commands/execute'),
          CockpitCommand(
            commandId: 'capture-home',
            commandType: CockpitCommandType.captureScreenshot,
            screenshotRequest: const CockpitScreenshotRequest(
              reason: CockpitScreenshotReason.acceptance,
              name: 'remote-home',
              includeSnapshot: true,
              attachToStep: true,
            ),
          ).toJson(),
        );
      }).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw TimeoutException('executeCaptureCommand');
        },
      );

      final response = CockpitRemoteCommandResponse.fromJson(responseJson!);
      final result = response.result;

      expect(result.success, isTrue);
      expect(result.requestedCaptureProfile, CockpitCaptureProfile.acceptance);
      expect(result.resolvedCaptureKind, CockpitCaptureKind.flutterView);
      expect(result.usedCaptureFallback, isFalse);
      expect(result.degradationReason, isNull);
      expect(response.artifactPayloads.single.bytes, isNotEmpty);
      expect(
        result.artifacts.single.relativePath,
        allOf(startsWith('screenshots/'), endsWith('.png')),
      );
    },
  );

  test(
    'remote session recording endpoints expose downloadable artifacts',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_remote_recording_server_test',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });
      final sourceFile = File(
        p.join(tempDir.path, 'recordings', 'remote_home_acceptance.mp4'),
      );
      sourceFile.parent.createSync(recursive: true);
      sourceFile.writeAsBytesSync(const <int>[1, 2, 3, 4]);

      final server = CockpitRemoteSessionServer(
        configuration: const CockpitRemoteSessionConfiguration(
          enabled: true,
          autoStart: false,
          port: 0,
        ),
        statusProvider: () async => CockpitRemoteSessionStatus(
          sessionId: 'remote-recording-session',
          platform: 'ios',
          transportType: 'remoteHttp',
          currentRouteName: '/home',
          capabilities: CockpitCapabilities(
            platform: 'ios',
            transportType: 'remoteHttp',
            supportsInAppControl: true,
            supportsFlutterViewCapture: true,
            supportsNativeScreenCapture: true,
            supportsHostAutomation: false,
            supportedCommands: const <CockpitCommandType>[
              CockpitCommandType.tap,
            ],
            supportedLocatorStrategies: CockpitLocatorKind.values,
          ),
          recordingCapabilities: CockpitRecordingCapabilities(
            supportsNativeRecording: true,
            preferredAcceptanceRecordingKind: CockpitRecordingKind.nativeScreen,
          ),
          snapshot: CockpitSnapshot(routeName: '/home'),
        ),
        snapshotProvider: ({required options}) async => CockpitSnapshot(
          routeName: '/home',
          diagnosticLevel: options.profile,
        ),
        commandExecutor: (_) async => CockpitCommandExecution(
          result: CockpitCommandResult(
            success: true,
            commandId: 'noop',
            commandType: CockpitCommandType.tap,
            durationMs: 0,
          ),
        ),
        startRecording: (request) async => CockpitRecordingSession(
          request: request,
          state: CockpitRecordingState.recording,
        ),
        stopRecording: () async => CockpitRecordingResult(
          state: CockpitRecordingState.completed,
          purpose: CockpitRecordingPurpose.acceptance,
          recordingKind: CockpitRecordingKind.nativeScreen,
          artifact: const CockpitArtifactRef(
            role: 'recording',
            relativePath: 'recordings/remote_home_acceptance.mp4',
          ),
          durationMs: 1800,
          sourceFilePath: sourceFile.path,
        ),
      );
      await server.start();
      addTearDown(server.close);

      final baseUri = server.baseUri;
      expect(baseUri, isNotNull);
      final resolvedBaseUri = baseUri ??
          (throw StateError('Remote session server failed to start.'));

      final sessionJson = await _postJson(
        resolvedBaseUri.resolve('/recording/start'),
        const <String, Object?>{
          'purpose': 'acceptance',
          'name': 'remote_home_acceptance',
          'attachToStep': true,
        },
      );
      final session = CockpitRecordingSession.fromJson(sessionJson);
      expect(session.state, CockpitRecordingState.recording);

      final resultJson = await _postJson(
        resolvedBaseUri.resolve('/recording/stop'),
        const <String, Object?>{},
      );
      final response = CockpitRemoteRecordingResponse.fromJson(resultJson);
      final result = response.result;

      expect(result.state, CockpitRecordingState.completed);
      expect(
        result.artifact?.relativePath,
        'recordings/remote_home_acceptance.mp4',
      );
      expect(response.artifactDownloads, hasLength(1));
      expect(
        response.artifactDownloads.single.artifact.relativePath,
        'recordings/remote_home_acceptance.mp4',
      );
      expect(
        response.artifactDownloads.single.downloadPath,
        '/artifacts/download?path=recordings%2Fremote_home_acceptance.mp4',
      );
      sourceFile.deleteSync();
      expect(
        await _readBytes(
          resolvedBaseUri.resolve(
            response.artifactDownloads.single.downloadPath,
          ),
        ),
        <int>[1, 2, 3, 4],
      );
    },
  );
}

Future<Map<String, Object?>> _readJson(Uri uri) async {
  return HttpOverrides.runZoned(() async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(uri);
      final response = await request.close();
      final payload = jsonDecode(await utf8.decoder.bind(response).join());
      return Map<String, Object?>.from(payload as Map<Object?, Object?>);
    } finally {
      client.close(force: true);
    }
  }, createHttpClient: _RealHttpOverrides().createHttpClient);
}

Future<Map<String, Object?>> _postJson(
  Uri uri,
  Map<String, Object?> payload,
) async {
  return HttpOverrides.runZoned(() async {
    final client = HttpClient();
    try {
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(payload));
      final response = await request.close();
      final body = await utf8.decoder.bind(response).join();
      return Map<String, Object?>.from(
        jsonDecode(body) as Map<Object?, Object?>,
      );
    } finally {
      client.close(force: true);
    }
  }, createHttpClient: _RealHttpOverrides().createHttpClient);
}

Future<List<int>> _readBytes(Uri uri) async {
  return HttpOverrides.runZoned(() async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(uri);
      final response = await request.close();
      final bytes = await response.fold<List<int>>(<int>[], (bytes, chunk) {
        final combined = List<int>.of(bytes);
        combined.addAll(chunk);
        return combined;
      });
      return bytes;
    } finally {
      client.close(force: true);
    }
  }, createHttpClient: _RealHttpOverrides().createHttpClient);
}

final class _RealHttpOverrides extends HttpOverrides {}

final class _FakeCockpitNativeRecording extends CockpitNativeRecording {
  _FakeCockpitNativeRecording({
    Directory? tempDirectory,
    List<int> recordingBytes = const <int>[1, 2, 3, 4],
  })  : _tempDirectory = tempDirectory,
        _recordingBytes = List<int>.unmodifiable(recordingBytes);

  final Directory? _tempDirectory;
  final List<int> _recordingBytes;

  @override
  Future<CockpitRecordingCapabilities> queryCapabilities() async {
    return CockpitRecordingCapabilities(
      supportsNativeRecording: true,
      preferredAcceptanceRecordingKind: CockpitRecordingKind.nativeScreen,
    );
  }

  @override
  Future<CockpitRecordingSession> startRecording({
    required CockpitRecordingRequest request,
  }) async {
    return CockpitRecordingSession(
      request: request,
      state: CockpitRecordingState.recording,
    );
  }

  @override
  Future<CockpitRecordingResult> stopRecording({
    required CockpitRecordingSession session,
  }) async {
    final relativePath = cockpitRecordingRelativePathFor(session.request);
    final sourceFilePath = _writeRecordingFile(relativePath);
    return CockpitRecordingResult(
      state: CockpitRecordingState.completed,
      purpose: session.request.purpose,
      recordingKind: CockpitRecordingKind.nativeScreen,
      artifact: CockpitArtifactRef(
        role: 'recording',
        relativePath: relativePath,
      ),
      durationMs: 1800,
      sourceFilePath: sourceFilePath,
    );
  }

  String? _writeRecordingFile(String relativePath) {
    final tempDirectory = _tempDirectory;
    if (tempDirectory == null) {
      return null;
    }

    final file = File('${tempDirectory.path}/$relativePath');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(_recordingBytes);
    return file.path;
  }
}

final class _RemoteTestApp extends StatelessWidget {
  _RemoteTestApp({
    required this.controller,
    required this.registry,
    required this.configuration,
  }) {
    FlutterCockpit.initialize(
      FlutterCockpitConfiguration(
        initialRouteName: configuration.initialRouteName,
        registry: configuration.registry ?? registry,
        nativeCapture: configuration.nativeCapture,
        nativeRecording: configuration.nativeRecording,
        remoteSession: configuration.remoteSession,
      ),
    );
  }

  final CockpitSessionController controller;
  final CockpitTargetRegistry registry;
  final FlutterCockpitConfiguration configuration;

  @override
  Widget build(BuildContext context) {
    return FlutterCockpitRoot(
      child: MaterialApp(
        navigatorObservers: <NavigatorObserver>[
          FlutterCockpit.navigatorObserver,
        ],
        home: _RemoteHomePage(controller: controller, registry: registry),
      ),
    );
  }
}

final class _RemoteNativeDiscoveryTestApp extends StatelessWidget {
  _RemoteNativeDiscoveryTestApp({
    required this.controller,
    required this.registry,
    required this.configuration,
  }) {
    FlutterCockpit.initialize(
      FlutterCockpitConfiguration(
        initialRouteName: configuration.initialRouteName,
        registry: configuration.registry ?? registry,
        nativeCapture: configuration.nativeCapture,
        nativeRecording: configuration.nativeRecording,
        remoteSession: configuration.remoteSession,
      ),
    );
  }

  final CockpitSessionController controller;
  final CockpitTargetRegistry registry;
  final FlutterCockpitConfiguration configuration;

  @override
  Widget build(BuildContext context) {
    return FlutterCockpitRoot(
      child: MaterialApp(
        navigatorObservers: <NavigatorObserver>[
          FlutterCockpit.navigatorObserver,
        ],
        home: _RemoteNativeHomePage(controller: controller, registry: registry),
      ),
    );
  }
}

final class _RemoteHomePage extends StatelessWidget {
  const _RemoteHomePage({required this.controller, required this.registry});

  final CockpitSessionController controller;
  final CockpitTargetRegistry registry;

  void _openForm(BuildContext context) {
    controller.recordStep(
      actionType: 'open_form',
      actionArgs: const <String, Object?>{'target': 'open_form_button'},
      observation: CockpitObservation(
        routeName: '/home',
        interactiveElements: <String>['open_form_button'],
      ),
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/form'),
        builder: (_) =>
            _RemoteFormPage(controller: controller, registry: registry),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: CockpitTargetNode(
          registrationId: 'home.open_form_button',
          cockpitId: 'open_form_button',
          text: 'Open form',
          typeName: 'ElevatedButton',
          supportedCommands: const <CockpitCommandType>{CockpitCommandType.tap},
          onTap: () => _openForm(context),
          child: ElevatedButton(
            onPressed: () => _openForm(context),
            child: const Text('Open form'),
          ),
        ),
      ),
    );
  }
}

final class _RemoteNativeHomePage extends StatelessWidget {
  const _RemoteNativeHomePage({
    required this.controller,
    required this.registry,
  });

  final CockpitSessionController controller;
  final CockpitTargetRegistry registry;

  void _openForm(BuildContext context) {
    controller.recordStep(
      actionType: 'native_open_form',
      actionArgs: const <String, Object?>{'target': 'native-open-form-button'},
      observation: CockpitObservation(
        routeName: '/home',
        interactiveElements: <String>['native-open-form-button'],
      ),
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/form'),
        builder: (_) =>
            _RemoteFormPage(controller: controller, registry: registry),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Semantics(
          label: 'Open form',
          hint: 'Navigates to the remote form screen',
          child: Tooltip(
            message: 'Open the remote form',
            child: ElevatedButton(
              key: const ValueKey<String>('native-open-form-button'),
              onPressed: () => _openForm(context),
              child: const Text('Open form'),
            ),
          ),
        ),
      ),
    );
  }
}

final class _RemoteFormPage extends StatelessWidget {
  const _RemoteFormPage({required this.controller, required this.registry});

  final CockpitSessionController controller;
  final CockpitTargetRegistry registry;

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Form page')));
  }
}

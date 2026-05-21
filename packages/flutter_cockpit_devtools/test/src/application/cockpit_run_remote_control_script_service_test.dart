import 'dart:convert';
import 'dart:io';

import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_cockpit_devtools/src/adapters/cockpit_recording_adapter.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_application_service_exception.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_run_remote_control_script_service.dart';
import 'package:flutter_cockpit_devtools/src/artifacts/cockpit_timeline_video_fallback_builder.dart';
import 'package:flutter_cockpit_devtools/src/artifacts/task_run_bundle_writer.dart';
import 'package:flutter_cockpit_devtools/src/cli/cockpit_control_script.dart';
import 'package:flutter_cockpit_devtools/src/recording/cockpit_recording_strategy_resolver.dart';
import 'package:flutter_cockpit_devtools/src/session/cockpit_remote_session_handle.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test(
    'run service executes a structured remote control script, persists it for replay, and returns bundle metadata',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_run_remote_control_script_service',
      );
      addTearDown(() async {
        await server.close(force: true);
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      server.listen((request) async {
        request.response.headers.contentType = ContentType.json;
        switch ((request.method, request.uri.path)) {
          case ('GET', '/health'):
            request.response.write(
              jsonEncode(
                CockpitRemoteSessionStatus(
                  sessionId: 'service-remote-demo',
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
                    supportedCommands: <CockpitCommandType>[
                      CockpitCommandType.tap,
                      CockpitCommandType.captureScreenshot,
                    ],
                    supportedLocatorStrategies: CockpitLocatorKind.values,
                  ),
                  recordingCapabilities: CockpitRecordingCapabilities(
                    supportsNativeRecording: true,
                    preferredAcceptanceRecordingKind:
                        CockpitRecordingKind.nativeScreen,
                  ),
                  snapshot: CockpitSnapshot(routeName: '/home'),
                ).toJson(),
              ),
            );
          case ('POST', '/commands/execute'):
            final body = jsonDecode(await utf8.decoder.bind(request).join())
                as Map<String, Object?>;
            final command = CockpitCommand.fromJson(body);
            request.response.write(
              jsonEncode(
                CockpitRemoteCommandResponse(
                  result: CockpitCommandResult(
                    success: true,
                    commandId: command.commandId,
                    commandType: command.commandType,
                    durationMs: 20,
                    artifacts: command.commandType ==
                            CockpitCommandType.captureScreenshot
                        ? const <CockpitArtifactRef>[
                            CockpitArtifactRef(
                              role: 'screenshot',
                              relativePath:
                                  'screenshots/service_acceptance.png',
                            ),
                          ]
                        : const <CockpitArtifactRef>[],
                    snapshot: CockpitSnapshot(routeName: '/done').toJson(),
                  ),
                  artifactPayloads: command.commandType ==
                          CockpitCommandType.captureScreenshot
                      ? const <CockpitRemoteArtifactPayload>[
                          CockpitRemoteArtifactPayload(
                            artifact: CockpitArtifactRef(
                              role: 'screenshot',
                              relativePath:
                                  'screenshots/service_acceptance.png',
                            ),
                            bytes: <int>[1, 2, 3],
                          ),
                        ]
                      : const <CockpitRemoteArtifactPayload>[],
                ).toJson(),
              ),
            );
          default:
            request.response.statusCode = HttpStatus.notFound;
            request.response.write(
              jsonEncode(const <String, Object?>{'error': 'notFound'}),
            );
        }
        await request.response.close();
      });

      final handle = CockpitRemoteSessionHandle(
        platform: 'ios',
        deviceId: 'simulator',
        projectDir: '/workspace/examples/cockpit_demo',
        target: 'lib/main.dart',
        appId: 'dev.cockpit.cockpit_demo',
        host: '127.0.0.1',
        hostPort: server.port,
        devicePort: server.port,
        baseUrl: 'http://127.0.0.1:${server.port}',
        launchedAt: DateTime.utc(2026, 3, 21, 0, 0),
      );
      final script = CockpitControlScript(
        sessionId: 'remote-script-session',
        taskId: 'remote-script-task',
        platform: 'ios',
        environment: const CockpitEnvironment(
          platform: 'ios',
          flutterVersion: '3.38.9',
          dartVersion: '3.10.8',
        ),
        commands: <CockpitCommand>[
          CockpitCommand(
            commandId: 'remote-open',
            commandType: CockpitCommandType.tap,
            locator: const CockpitLocator(
              cockpitId: 'open_form_button',
            ),
          ),
          CockpitCommand(
            commandId: 'remote-capture',
            commandType: CockpitCommandType.captureScreenshot,
            screenshotRequest: const CockpitScreenshotRequest(
              reason: CockpitScreenshotReason.acceptance,
              name: 'service-acceptance',
              includeSnapshot: true,
              attachToStep: true,
            ),
          ),
        ],
        failFast: true,
      );
      final persistedScript = File(p.join(tempDir.path, 'replay_script.json'));
      final service = CockpitRunRemoteControlScriptService();

      final result = await service.run(
        CockpitRunRemoteControlScriptRequest(
          sessionHandle: handle,
          iosDeviceId: '',
          script: script,
          outputRoot: tempDir.path,
          persistScriptPath: persistedScript.path,
        ),
      );

      expect(result.sessionHandle?.toJson(), handle.toJson());
      expect(result.bundleDir.existsSync(), isTrue);
      expect(result.manifest.commandCount, 2);
      expect(
        result.delivery['primaryScreenshotRef'],
        'screenshots/service_acceptance.png',
      );
      expect(
        result.artifactPaths.primaryScreenshotPath,
        p.join(result.bundleDir.path, 'screenshots', 'service_acceptance.png'),
      );

      final replayJson = jsonDecode(await persistedScript.readAsString())
          as Map<String, Object?>;
      expect(replayJson['sessionId'], 'remote-script-session');
      expect(
        File(
          p.join(
            result.bundleDir.path,
            'screenshots',
            'service_acceptance.png',
          ),
        ).readAsBytesSync(),
        <int>[1, 2, 3],
      );
    },
  );

  test(
    'run service returns metadata from the finalized written bundle',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_run_remote_control_script_service_finalized_metadata',
      );
      addTearDown(() async {
        await server.close(force: true);
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      server.listen((request) async {
        request.response.headers.contentType = ContentType.json;
        switch ((request.method, request.uri.path)) {
          case ('GET', '/health'):
            request.response.write(
              jsonEncode(
                CockpitRemoteSessionStatus(
                  sessionId: 'service-finalized-demo',
                  platform: 'ios',
                  transportType: 'remoteHttp',
                  currentRouteName: '/home',
                  capabilities: CockpitCapabilities(
                    platform: 'ios',
                    transportType: 'remoteHttp',
                    supportsInAppControl: true,
                    supportsFlutterViewCapture: true,
                    supportsNativeScreenCapture: false,
                    supportsHostAutomation: false,
                    supportedCommands: <CockpitCommandType>[
                      CockpitCommandType.captureScreenshot,
                    ],
                    supportedLocatorStrategies: CockpitLocatorKind.values,
                  ),
                  recordingCapabilities: CockpitRecordingCapabilities(
                    supportsNativeRecording: false,
                    preferredAcceptanceRecordingKind:
                        CockpitRecordingKind.nativeScreen,
                  ),
                  snapshot: CockpitSnapshot(routeName: '/home'),
                  environment: const CockpitEnvironment(
                    platform: 'ios',
                    flutterVersion: '3.38.9',
                    dartVersion: '3.10.8',
                  ),
                ).toJson(),
              ),
            );
          case ('POST', '/commands/execute'):
            request.response.write(
              jsonEncode(
                CockpitRemoteCommandResponse(
                  result: CockpitCommandResult(
                    success: true,
                    commandId: 'capture-acceptance',
                    commandType: CockpitCommandType.captureScreenshot,
                    durationMs: 16,
                    artifacts: const <CockpitArtifactRef>[
                      CockpitArtifactRef(
                        role: 'screenshot',
                        relativePath: 'screenshots/finalized_acceptance.png',
                      ),
                    ],
                    snapshot: CockpitSnapshot(routeName: '/done').toJson(),
                    requestedCaptureProfile: CockpitCaptureProfile.acceptance,
                  ),
                  artifactPayloads: const <CockpitRemoteArtifactPayload>[
                    CockpitRemoteArtifactPayload(
                      artifact: CockpitArtifactRef(
                        role: 'screenshot',
                        relativePath: 'screenshots/finalized_acceptance.png',
                      ),
                      bytes: <int>[137, 80, 78, 71],
                    ),
                  ],
                ).toJson(),
              ),
            );
          default:
            request.response.statusCode = HttpStatus.notFound;
            request.response.write(
              jsonEncode(const <String, Object?>{'error': 'notFound'}),
            );
        }
        await request.response.close();
      });

      final writer = TaskRunBundleWriter(
        timelineVideoFallbackBuilder: _FakeTimelineFallbackBuilder(
          sourceRoot: tempDir.path,
          relativePath: 'recordings/finalized_timeline_fallback.mp4',
        ),
      );
      final service = CockpitRunRemoteControlScriptService(writer: writer);

      final result = await service.run(
        CockpitRunRemoteControlScriptRequest(
          script: CockpitControlScript(
            sessionId: 'finalized-metadata-session',
            taskId: 'finalized-metadata-task',
            platform: 'ios',
            commands: <CockpitCommand>[
              CockpitCommand(
                commandId: 'capture-acceptance',
                commandType: CockpitCommandType.captureScreenshot,
                screenshotRequest: const CockpitScreenshotRequest(
                  reason: CockpitScreenshotReason.acceptance,
                  name: 'finalized-acceptance',
                  includeSnapshot: true,
                  attachToStep: true,
                ),
              ),
            ],
            failFast: true,
            recording: const CockpitRecordingRequest(
              purpose: CockpitRecordingPurpose.acceptance,
              name: 'finalized-recording',
              attachToStep: true,
            ),
          ),
          outputRoot: tempDir.path,
          baseUri: Uri.parse('http://127.0.0.1:${server.port}'),
        ),
      );

      expect(result.manifest.deliveryVideoReady, isTrue);
      expect(result.manifest.recordingCount, 1);
      expect(result.delivery['deliveryVideoSynthesized'], isTrue);
      expect(
        result.delivery['primaryRecordingRef'],
        'recordings/finalized_timeline_fallback.mp4',
      );
      expect(
        result.artifactPaths.primaryRecordingPath,
        p.join(
          result.bundleDir.path,
          'recordings',
          'finalized_timeline_fallback.mp4',
        ),
      );
      expect(
        File(result.artifactPaths.primaryRecordingPath!).readAsBytesSync(),
        <int>[0, 1, 2, 3],
      );
    },
  );

  test(
    'run service resolves environment from remote health when the script omits it',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_run_remote_control_script_service_env',
      );
      addTearDown(() async {
        await server.close(force: true);
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      server.listen((request) async {
        request.response.headers.contentType = ContentType.json;
        switch ((request.method, request.uri.path)) {
          case ('GET', '/health'):
            request.response.write(
              jsonEncode(<String, Object?>{
                'sessionId': 'service-remote-demo',
                'platform': 'ios',
                'transportType': 'remoteHttp',
                'currentRouteName': '/home',
                'capabilities': CockpitCapabilities(
                  platform: 'ios',
                  transportType: 'remoteHttp',
                  supportsInAppControl: true,
                  supportsFlutterViewCapture: true,
                  supportsNativeScreenCapture: true,
                  supportsHostAutomation: false,
                  supportedCommands: <CockpitCommandType>[
                    CockpitCommandType.tap,
                  ],
                  supportedLocatorStrategies: CockpitLocatorKind.values,
                ).toJson(),
                'recordingCapabilities': CockpitRecordingCapabilities(
                  supportsNativeRecording: true,
                  preferredAcceptanceRecordingKind:
                      CockpitRecordingKind.nativeScreen,
                ).toJson(),
                'snapshot': CockpitSnapshot(routeName: '/home').toJson(),
                'environment': const CockpitEnvironment(
                  platform: 'ios',
                  flutterVersion: '3.38.9',
                  dartVersion: '3.10.8',
                ).toJson(),
              }),
            );
          case ('POST', '/commands/execute'):
            final body = jsonDecode(await utf8.decoder.bind(request).join())
                as Map<String, Object?>;
            final command = CockpitCommand.fromJson(body);
            request.response.write(
              jsonEncode(
                CockpitRemoteCommandResponse(
                  result: CockpitCommandResult(
                    success: true,
                    commandId: command.commandId,
                    commandType: command.commandType,
                    durationMs: 20,
                  ),
                ).toJson(),
              ),
            );
          default:
            request.response.statusCode = HttpStatus.notFound;
            request.response.write(
              jsonEncode(const <String, Object?>{'error': 'notFound'}),
            );
        }
        await request.response.close();
      });

      final handle = CockpitRemoteSessionHandle(
        platform: 'ios',
        deviceId: 'simulator',
        projectDir: '/workspace/examples/cockpit_demo',
        target: 'lib/main.dart',
        appId: 'dev.cockpit.cockpit_demo',
        host: '127.0.0.1',
        hostPort: server.port,
        devicePort: server.port,
        baseUrl: 'http://127.0.0.1:${server.port}',
        launchedAt: DateTime.utc(2026, 3, 21, 0, 0),
      );
      final script = CockpitControlScript.fromJson(<String, Object?>{
        'sessionId': 'remote-script-session',
        'taskId': 'remote-script-task',
        'platform': 'ios',
        'commands': <Map<String, Object?>>[
          <String, Object?>{
            'commandId': 'remote-open',
            'commandType': 'tap',
            'locator': const CockpitLocator(
              cockpitId: 'open_form_button',
            ).toJson(),
          },
        ],
        'failFast': true,
      });
      final service = CockpitRunRemoteControlScriptService();

      final result = await service.run(
        CockpitRunRemoteControlScriptRequest(
          sessionHandle: handle,
          iosDeviceId: '',
          script: script,
          outputRoot: tempDir.path,
        ),
      );

      expect(result.manifest.status, CockpitTaskStatus.completed);
      expect(
        jsonDecode(
          await File(
            p.join(result.bundleDir.path, 'environment.json'),
          ).readAsString(),
        ) as Map<String, Object?>,
        const <String, Object?>{
          'platform': 'ios',
          'flutterVersion': '3.38.9',
          'dartVersion': '3.10.8',
        },
      );
    },
  );

  test(
    'run service fails with missingEnvironment when neither script nor remote health provide environment',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_run_remote_control_script_service_missing_env',
      );
      addTearDown(() async {
        await server.close(force: true);
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      server.listen((request) async {
        request.response.headers.contentType = ContentType.json;
        switch ((request.method, request.uri.path)) {
          case ('GET', '/health'):
            request.response.write(
              jsonEncode(<String, Object?>{
                'sessionId': 'service-remote-demo',
                'platform': 'ios',
                'transportType': 'remoteHttp',
                'currentRouteName': '/home',
                'capabilities': CockpitCapabilities(
                  platform: 'ios',
                  transportType: 'remoteHttp',
                  supportsInAppControl: true,
                  supportsFlutterViewCapture: true,
                  supportsNativeScreenCapture: true,
                  supportsHostAutomation: false,
                  supportedCommands: <CockpitCommandType>[
                    CockpitCommandType.tap,
                  ],
                  supportedLocatorStrategies: CockpitLocatorKind.values,
                ).toJson(),
                'recordingCapabilities': CockpitRecordingCapabilities(
                  supportsNativeRecording: true,
                  preferredAcceptanceRecordingKind:
                      CockpitRecordingKind.nativeScreen,
                ).toJson(),
                'snapshot': CockpitSnapshot(routeName: '/home').toJson(),
              }),
            );
          default:
            request.response.statusCode = HttpStatus.notFound;
            request.response.write(
              jsonEncode(const <String, Object?>{'error': 'notFound'}),
            );
        }
        await request.response.close();
      });

      final handle = CockpitRemoteSessionHandle(
        platform: 'ios',
        deviceId: 'simulator',
        projectDir: '/workspace/examples/cockpit_demo',
        target: 'lib/main.dart',
        appId: 'dev.cockpit.cockpit_demo',
        host: '127.0.0.1',
        hostPort: server.port,
        devicePort: server.port,
        baseUrl: 'http://127.0.0.1:${server.port}',
        launchedAt: DateTime.utc(2026, 3, 21, 0, 0),
      );
      final script = CockpitControlScript.fromJson(<String, Object?>{
        'sessionId': 'remote-script-session',
        'taskId': 'remote-script-task',
        'platform': 'ios',
        'commands': <Map<String, Object?>>[
          <String, Object?>{
            'commandId': 'remote-open',
            'commandType': 'tap',
            'locator': const CockpitLocator(
              cockpitId: 'open_form_button',
            ).toJson(),
          },
        ],
        'failFast': true,
      });
      final service = CockpitRunRemoteControlScriptService();

      expect(
        () => service.run(
          CockpitRunRemoteControlScriptRequest(
            sessionHandle: handle,
            script: script,
            outputRoot: tempDir.path,
          ),
        ),
        throwsA(
          isA<CockpitApplicationServiceException>().having(
            (error) => error.code,
            'code',
            'missingEnvironment',
          ),
        ),
      );
    },
  );

  test(
    'run service uses process-scoped Windows host recording when only platform app metadata is provided',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_run_remote_control_script_service_windows_host',
      );
      addTearDown(() async {
        await server.close(force: true);
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      server.listen((request) async {
        request.response.headers.contentType = ContentType.json;
        switch ((request.method, request.uri.path)) {
          case ('GET', '/health'):
            request.response.write(
              jsonEncode(
                CockpitRemoteSessionStatus(
                  sessionId: 'windows-host-service',
                  platform: 'windows',
                  transportType: 'remoteHttp',
                  currentRouteName: '/home',
                  capabilities: CockpitCapabilities(
                    platform: 'windows',
                    transportType: 'remoteHttp',
                    supportsInAppControl: true,
                    supportsFlutterViewCapture: true,
                    supportsNativeScreenCapture: true,
                    supportsHostAutomation: false,
                    supportedCommands: const <CockpitCommandType>[],
                    supportedLocatorStrategies: CockpitLocatorKind.values,
                  ),
                  recordingCapabilities: CockpitRecordingCapabilities(
                    supportsNativeRecording: false,
                    preferredAcceptanceRecordingKind:
                        CockpitRecordingKind.nativeScreen,
                  ),
                  snapshot: CockpitSnapshot(routeName: '/home'),
                ).toJson(),
              ),
            );
          default:
            request.response.statusCode = HttpStatus.notFound;
            request.response.write(
              jsonEncode(const <String, Object?>{'error': 'notFound'}),
            );
        }
        await request.response.close();
      });

      String? capturedAppId;
      int? capturedProcessId;
      final hostRecordingSource = File(
        p.join(tempDir.path, 'windows_host_recording.mp4'),
      )..writeAsBytesSync(const <int>[4, 1, 0, 1]);
      final service = CockpitRunRemoteControlScriptService(
        recordingStrategyResolver: CockpitRecordingStrategyResolver(
          remoteAdapterFactory: (_) => throw StateError(
            'remote recording adapter should not be used',
          ),
          adbAdapterFactory: (_) => throw StateError(
            'adb recording adapter should not be used',
          ),
          simctlAdapterFactory: (_) => throw StateError(
            'simctl recording adapter should not be used',
          ),
          windowsAdapterFactory: (appId, {processId}) {
            capturedAppId = appId;
            capturedProcessId = processId;
            return _HostOnlyRecordingAdapter(hostRecordingSource.path);
          },
        ),
      );

      final result = await service.run(
        CockpitRunRemoteControlScriptRequest(
          script: CockpitControlScript(
            sessionId: 'remote-script-session',
            taskId: 'remote-script-task',
            platform: 'windows',
            environment: const CockpitEnvironment(
              platform: 'windows',
              flutterVersion: '3.38.9',
              dartVersion: '3.10.8',
            ),
            commands: const <CockpitCommand>[],
            failFast: true,
            recording: const CockpitRecordingRequest(
              purpose: CockpitRecordingPurpose.acceptance,
              name: 'windows-host-recording',
              mode: CockpitRecordingMode.full,
            ),
          ),
          outputRoot: tempDir.path,
          platformAppId: 'cockpit_demo',
          processId: 4101,
          baseUri: Uri.parse('http://127.0.0.1:${server.port}'),
        ),
      );

      expect(capturedAppId, 'cockpit_demo');
      expect(capturedProcessId, 4101);
      expect(result.manifest.recordingCount, 1);
      expect(
        result.artifactPaths.primaryRecordingPath,
        p.join(
          result.bundleDir.path,
          'recordings',
          'windows-host-recording.mp4',
        ),
      );
      expect(
        File(result.artifactPaths.primaryRecordingPath!).readAsBytesSync(),
        <int>[4, 1, 0, 1],
      );
    },
  );
}

final class _HostOnlyRecordingAdapter implements CockpitRecordingAdapter {
  _HostOnlyRecordingAdapter(this.sourceFilePath);

  final String sourceFilePath;
  CockpitRecordingRequest? _request;

  @override
  Future<CockpitRecordingSession> startRecording(
    CockpitRecordingRequest request,
  ) async {
    _request = request;
    return CockpitRecordingSession(
      request: request,
      state: CockpitRecordingState.recording,
    );
  }

  @override
  Future<CockpitRecordingResult> stopRecording() async {
    final request = _request!;
    return CockpitRecordingResult(
      state: CockpitRecordingState.completed,
      purpose: request.purpose,
      recordingKind: CockpitRecordingKind.nativeScreen,
      artifact: CockpitArtifactRef(
        role: 'recording',
        relativePath: 'recordings/${request.name}.mp4',
      ),
      sourceFilePath: sourceFilePath,
      durationMs: 600,
    );
  }
}

final class _FakeTimelineFallbackBuilder
    implements CockpitTimelineVideoFallbackBuilder {
  const _FakeTimelineFallbackBuilder({
    required this.sourceRoot,
    required this.relativePath,
  });

  final String sourceRoot;
  final String relativePath;

  @override
  Future<CockpitTimelineVideoFallbackResult?> build({
    required CockpitContextBundle bundle,
    required String outputDirectoryPath,
  }) async {
    final sourceFile = File(p.join(sourceRoot, 'timeline_fallback.mp4'));
    sourceFile.writeAsBytesSync(const <int>[0, 1, 2, 3]);
    return CockpitTimelineVideoFallbackResult(
      artifact: CockpitArtifactRef(
        role: 'recording',
        relativePath: relativePath,
      ),
      sourceFilePath: sourceFile.path,
      durationMs: 1800,
      screenshotRefs: const <String>['screenshots/finalized_acceptance.png'],
    );
  }
}

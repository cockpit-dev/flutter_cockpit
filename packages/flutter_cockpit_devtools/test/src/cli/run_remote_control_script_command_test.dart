import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_cockpit_devtools/flutter_cockpit_devtools.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_app_reference_resolver.dart';
import 'package:flutter_cockpit_devtools/src/cli/commands/run_script_command.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test(
    'run-script executes commands against a running app and writes a bundle',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_run_remote_cli',
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
                  sessionId: 'cli-remote-demo',
                  platform: 'android',
                  transportType: 'remoteHttp',
                  currentRouteName: '/home',
                  capabilities: CockpitCapabilities(
                    platform: 'android',
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
                  environment: const CockpitEnvironment(
                    platform: 'android',
                    flutterVersion: '3.38.9',
                    dartVersion: '3.10.8',
                  ),
                ).toJson(),
              ),
            );
          case ('POST', '/commands/execute'):
            final body =
                jsonDecode(await utf8.decoder.bind(request).join())
                    as Map<String, Object?>;
            final command = CockpitCommand.fromJson(body);
            request.response.write(
              jsonEncode(
                CockpitRemoteCommandResponse(
                  result: CockpitCommandResult(
                    success: true,
                    commandId: command.commandId,
                    commandType: command.commandType,
                    durationMs: 25,
                    artifacts:
                        command.commandType ==
                            CockpitCommandType.captureScreenshot
                        ? const <CockpitArtifactRef>[
                            CockpitArtifactRef(
                              role: 'screenshot',
                              relativePath: 'screenshots/remote_acceptance.png',
                            ),
                          ]
                        : const <CockpitArtifactRef>[],
                    snapshot: CockpitSnapshot(routeName: '/form').toJson(),
                  ),
                  artifactPayloads:
                      command.commandType ==
                          CockpitCommandType.captureScreenshot
                      ? const <CockpitRemoteArtifactPayload>[
                          CockpitRemoteArtifactPayload(
                            artifact: CockpitArtifactRef(
                              role: 'screenshot',
                              relativePath: 'screenshots/remote_acceptance.png',
                            ),
                            bytes: <int>[4, 5, 6],
                          ),
                        ]
                      : const <CockpitRemoteArtifactPayload>[],
                ).toJson(),
              ),
            );
          case ('POST', '/recording/start'):
            request.response.write(
              jsonEncode(
                const CockpitRecordingSession(
                  request: CockpitRecordingRequest(
                    purpose: CockpitRecordingPurpose.acceptance,
                    name: 'remote-demo-acceptance',
                    attachToStep: true,
                  ),
                  state: CockpitRecordingState.recording,
                ).toJson(),
              ),
            );
          case ('POST', '/recording/stop'):
            request.response.write(
              jsonEncode(
                CockpitRemoteRecordingResponse(
                  result: CockpitRecordingResult(
                    state: CockpitRecordingState.completed,
                    purpose: CockpitRecordingPurpose.acceptance,
                    recordingKind: CockpitRecordingKind.nativeScreen,
                    artifact: const CockpitArtifactRef(
                      role: 'recording',
                      relativePath: 'recordings/remote-demo-acceptance.mp4',
                    ),
                    durationMs: 900,
                  ),
                  artifactDownloads: const <CockpitRemoteArtifactDownload>[
                    CockpitRemoteArtifactDownload(
                      artifact: CockpitArtifactRef(
                        role: 'recording',
                        relativePath: 'recordings/remote-demo-acceptance.mp4',
                      ),
                      downloadPath:
                          '/artifacts/download?path=recordings%2Fremote-demo-acceptance.mp4',
                    ),
                  ],
                ).toJson(),
              ),
            );
          case ('GET', '/artifacts/download'):
            request.response.headers.contentType = ContentType.binary;
            request.response.add(const <int>[9, 8, 7, 6]);
          default:
            request.response.statusCode = HttpStatus.notFound;
            request.response.write(
              jsonEncode(const <String, Object?>{'error': 'notFound'}),
            );
        }
        await request.response.close();
      });

      final scriptFile = File(p.join(tempDir.path, 'remote_script.json'));
      await scriptFile.writeAsString(
        jsonEncode(<String, Object?>{
          'sessionId': 'remote-script-session',
          'taskId': 'remote-script-task',
          'platform': 'android',
          'recording': const CockpitRecordingRequest(
            purpose: CockpitRecordingPurpose.acceptance,
            name: 'remote-demo-acceptance',
            attachToStep: true,
          ).toJson(),
          'commands': <Map<String, Object?>>[
            CockpitCommand(
              commandId: 'remote-open',
              commandType: CockpitCommandType.tap,
              locator: const CockpitLocator(cockpitId: 'open_form_button'),
            ).toJson(),
            CockpitCommand(
              commandId: 'remote-capture',
              commandType: CockpitCommandType.captureScreenshot,
              screenshotRequest: const CockpitScreenshotRequest(
                reason: CockpitScreenshotReason.acceptance,
                name: 'remote-acceptance',
                includeSnapshot: true,
                attachToStep: true,
              ),
            ).toJson(),
          ],
        }),
      );

      final exitCode = await CockpitCommandRunner().run(<String>[
        'run-script',
        '--base-url',
        'http://127.0.0.1:${server.port}',
        '--script-json',
        scriptFile.path,
        '--output-root',
        tempDir.path,
      ]);

      expect(exitCode, 0);

      final outputDirectories = tempDir
          .listSync()
          .whereType<Directory>()
          .where(
            (directory) =>
                File(p.join(directory.path, 'manifest.json')).existsSync(),
          )
          .toList(growable: false);

      expect(outputDirectories, hasLength(1));
      expect(
        File(
          p.join(
            outputDirectories.single.path,
            'screenshots',
            'remote_acceptance.png',
          ),
        ).readAsBytesSync(),
        <int>[4, 5, 6],
      );
      expect(
        File(
          p.join(
            outputDirectories.single.path,
            'recordings',
            'remote-demo-acceptance.mp4',
          ),
        ).readAsBytesSync(),
        <int>[9, 8, 7, 6],
      );

      final manifestJson =
          jsonDecode(
                await File(
                  p.join(outputDirectories.single.path, 'manifest.json'),
                ).readAsString(),
              )
              as Map<String, Object?>;

      expect(manifestJson['commandCount'], 2);
      expect(manifestJson['screenshotCount'], 1);
      expect(manifestJson['recordingCount'], 1);
      expect(manifestJson['deliveryVideoReady'], isTrue);

      final deliveryJson =
          jsonDecode(
                await File(
                  p.join(outputDirectories.single.path, 'delivery.json'),
                ).readAsString(),
              )
              as Map<String, Object?>;
      expect(
        deliveryJson['primaryRecordingRef'],
        'recordings/remote-demo-acceptance.mp4',
      );
    },
  );

  test('run-script uses the forwarded host port for Android devices', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final tempDir = await Directory.systemTemp.createTemp(
      'cockpit_run_remote_cli_android',
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
                sessionId: 'cli-remote-android-demo',
                platform: 'android',
                transportType: 'remoteHttp',
                currentRouteName: '/home',
                capabilities: CockpitCapabilities(
                  platform: 'android',
                  transportType: 'remoteHttp',
                  supportsInAppControl: true,
                  supportsFlutterViewCapture: true,
                  supportsNativeScreenCapture: true,
                  supportsHostAutomation: false,
                  supportedCommands: <CockpitCommandType>[
                    CockpitCommandType.tap,
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
          final body =
              jsonDecode(await utf8.decoder.bind(request).join())
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
                  snapshot: CockpitSnapshot(routeName: '/form').toJson(),
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

    final scriptFile = File(p.join(tempDir.path, 'android_remote_script.json'));
    await scriptFile.writeAsString(
      jsonEncode(<String, Object?>{
        'sessionId': 'remote-script-android-session',
        'taskId': 'remote-script-android-task',
        'platform': 'android',
        'environment': const CockpitEnvironment(
          platform: 'android',
          flutterVersion: '3.38.9',
          dartVersion: '3.10.8',
        ).toJson(),
        'commands': <Map<String, Object?>>[
          CockpitCommand(
            commandId: 'remote-open',
            commandType: CockpitCommandType.tap,
            locator: const CockpitLocator(cockpitId: 'open_form_button'),
          ).toJson(),
        ],
      }),
    );

    final runner =
        CommandRunner<int>(
          'flutter_cockpit_devtools',
          'Host-side tooling for flutter_cockpit.',
        )..addCommand(
          RunScriptCommand(
            appReferenceResolver: CockpitAppReferenceResolver(
              portForwarder: _FakeAndroidPortForwarder(
                forwardedHostPort: server.port,
              ),
            ),
          ),
        );
    final exitCode =
        await runner.run(<String>[
          'run-script',
          '--base-url',
          'http://127.0.0.1:47331',
          '--script-json',
          scriptFile.path,
          '--output-root',
          tempDir.path,
          '--android-device-id',
          'emulator-5554',
        ]) ??
        0;

    expect(exitCode, 0);
  });

  test(
    'run-script writes a host-recorded video without remote recording downloads',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_run_remote_cli_host_recording',
      );
      addTearDown(() async {
        await server.close(force: true);
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      var remoteRecordingEndpointsHit = false;
      server.listen((request) async {
        request.response.headers.contentType = ContentType.json;
        switch ((request.method, request.uri.path)) {
          case ('GET', '/health'):
            request.response.write(
              jsonEncode(
                CockpitRemoteSessionStatus(
                  sessionId: 'cli-remote-ios-demo',
                  platform: 'ios',
                  transportType: 'remoteHttp',
                  currentRouteName: '/home',
                  capabilities: CockpitCapabilities(
                    platform: 'ios',
                    transportType: 'remoteHttp',
                    supportsInAppControl: true,
                    supportsFlutterViewCapture: false,
                    supportsNativeScreenCapture: true,
                    supportsHostAutomation: false,
                    supportedCommands: <CockpitCommandType>[
                      CockpitCommandType.tap,
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
            final body =
                jsonDecode(await utf8.decoder.bind(request).join())
                    as Map<String, Object?>;
            final command = CockpitCommand.fromJson(body);
            request.response.write(
              jsonEncode(
                CockpitRemoteCommandResponse(
                  result: CockpitCommandResult(
                    success: true,
                    commandId: command.commandId,
                    commandType: command.commandType,
                    durationMs: 18,
                    snapshot: CockpitSnapshot(routeName: '/form').toJson(),
                  ),
                ).toJson(),
              ),
            );
          case ('POST', '/recording/start'):
          case ('POST', '/recording/stop'):
          case ('GET', '/artifacts/download'):
            remoteRecordingEndpointsHit = true;
            request.response.statusCode = HttpStatus.internalServerError;
            request.response.write(
              jsonEncode(const <String, Object?>{
                'error': 'remoteRecordingShouldNotBeUsed',
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

      final hostRecordingSource = File(
        p.join(tempDir.path, 'host_recording.mp4'),
      );
      await hostRecordingSource.writeAsBytes(const <int>[7, 7, 7, 7]);

      final scriptFile = File(
        p.join(tempDir.path, 'host_recording_script.json'),
      );
      await scriptFile.writeAsString(
        jsonEncode(<String, Object?>{
          'sessionId': 'remote-script-ios-session',
          'taskId': 'remote-script-ios-task',
          'platform': 'ios',
          'environment': const CockpitEnvironment(
            platform: 'ios',
            flutterVersion: '3.38.9',
            dartVersion: '3.10.8',
          ).toJson(),
          'recording': const CockpitRecordingRequest(
            purpose: CockpitRecordingPurpose.acceptance,
            name: 'host-ios-acceptance',
            attachToStep: true,
          ).toJson(),
          'commands': <Map<String, Object?>>[
            CockpitCommand(
              commandId: 'remote-open',
              commandType: CockpitCommandType.tap,
              locator: const CockpitLocator(cockpitId: 'open_form_button'),
            ).toJson(),
          ],
        }),
      );

      final runner =
          CommandRunner<int>(
            'flutter_cockpit_devtools',
            'Host-side tooling for flutter_cockpit.',
          )..addCommand(
            RunScriptCommand(
              service: CockpitRunRemoteControlScriptService(
                recordingStrategyResolver: CockpitRecordingStrategyResolver(
                  remoteAdapterFactory: (client) => throw StateError(
                    'remote recording adapter should not be used',
                  ),
                  adbAdapterFactory: (deviceId) => throw StateError(
                    'adb recording adapter should not be used',
                  ),
                  simctlAdapterFactory: (deviceId) =>
                      _FakeRecordingAdapter.fromSourceFile(
                        hostRecordingSource.path,
                      ),
                ),
              ),
            ),
          );
      final exitCode =
          await runner.run(<String>[
            'run-script',
            '--base-url',
            'http://127.0.0.1:${server.port}',
            '--script-json',
            scriptFile.path,
            '--output-root',
            tempDir.path,
            '--ios-device-id',
            '6FD25DED-11E9-4AE9-B4B5-EDF4601981DC',
          ]) ??
          0;

      expect(exitCode, 0);
      expect(remoteRecordingEndpointsHit, isFalse);

      final outputDirectories = tempDir
          .listSync()
          .whereType<Directory>()
          .where(
            (directory) =>
                File(p.join(directory.path, 'manifest.json')).existsSync(),
          )
          .toList(growable: false);

      expect(outputDirectories, hasLength(1));
      expect(
        File(
          p.join(
            outputDirectories.single.path,
            'recordings',
            'host-ios-acceptance.mp4',
          ),
        ).readAsBytesSync(),
        <int>[7, 7, 7, 7],
      );
    },
  );

  test('run-script can resolve its base URL from an app handle', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final tempDir = await Directory.systemTemp.createTemp(
      'cockpit_run_remote_cli_handle',
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
                sessionId: 'cli-session-handle-demo',
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
          final body =
              jsonDecode(await utf8.decoder.bind(request).join())
                  as Map<String, Object?>;
          final command = CockpitCommand.fromJson(body);
          request.response.write(
            jsonEncode(
              CockpitRemoteCommandResponse(
                result: CockpitCommandResult(
                  success: true,
                  commandId: command.commandId,
                  commandType: command.commandType,
                  durationMs: 12,
                  snapshot: CockpitSnapshot(routeName: '/done').toJson(),
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

    final sessionFile = File(p.join(tempDir.path, 'sessionHandle.json'));
    await sessionFile.writeAsString(
      jsonEncode(<String, Object?>{
        'appId': 'dev.cockpit.cockpitDemo',
        'mode': 'automation',
        'platform': 'ios',
        'deviceId': 'simulator',
        'projectDir': '/workspace/examples/cockpit_demo',
        'target': 'lib/main.dart',
        'baseUrl': 'http://127.0.0.1:${server.port}',
        'launchedAt': '2026-03-21T00:00:00.000Z',
      }),
    );

    final scriptFile = File(p.join(tempDir.path, 'session_script.json'));
    await scriptFile.writeAsString(
      jsonEncode(<String, Object?>{
        'sessionId': 'remote-script-handle-session',
        'taskId': 'remote-script-handle-task',
        'platform': 'ios',
        'environment': const CockpitEnvironment(
          platform: 'ios',
          flutterVersion: '3.38.9',
          dartVersion: '3.10.8',
        ).toJson(),
        'commands': <Map<String, Object?>>[
          CockpitCommand(
            commandId: 'remote-open',
            commandType: CockpitCommandType.tap,
            locator: const CockpitLocator(cockpitId: 'open_form_button'),
          ).toJson(),
        ],
      }),
    );

    final exitCode = await CockpitCommandRunner().run(<String>[
      'run-script',
      '--app-json',
      sessionFile.path,
      '--script-json',
      scriptFile.path,
      '--output-root',
      tempDir.path,
    ]);

    expect(exitCode, 0);

    final outputDirectories = tempDir
        .listSync()
        .whereType<Directory>()
        .where(
          (directory) =>
              File(p.join(directory.path, 'manifest.json')).existsSync(),
        )
        .toList(growable: false);

    expect(outputDirectories, hasLength(1));
  });

  test('run-script forwards process ids from app handles', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'cockpit_run_remote_cli_process_id',
    );
    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    final appHandleFile = File(p.join(tempDir.path, 'app.json'));
    await appHandleFile.writeAsString(
      jsonEncode(
        CockpitAppHandle(
          appId: 'remote-demo-app',
          mode: CockpitAppMode.automation,
          platform: 'windows',
          deviceId: 'windows',
          projectDir: '/workspace/examples/cockpit_demo',
          target: 'cockpit/main.dart',
          baseUrl: 'http://127.0.0.1:57331',
          launchedAt: DateTime.utc(2026, 4, 17),
          platformAppId: 'cockpit_demo',
          processId: 4101,
          remoteSession: CockpitRemoteSessionHandle(
            platform: 'windows',
            deviceId: 'windows',
            projectDir: '/workspace/examples/cockpit_demo',
            target: 'cockpit/main.dart',
            appId: 'remote-demo-app',
            platformAppId: 'cockpit_demo',
            processId: 4101,
            host: '127.0.0.1',
            hostPort: 57331,
            devicePort: 57331,
            baseUrl: 'http://127.0.0.1:57331',
            launchedAt: DateTime.utc(2026, 4, 17),
          ),
        ).toJson(),
      ),
    );
    final scriptFile = File(p.join(tempDir.path, 'remote_script.json'));
    await scriptFile.writeAsString(
      jsonEncode(<String, Object?>{
        'sessionId': 'remote-script-session',
        'taskId': 'remote-script-task',
        'platform': 'windows',
        'environment': const CockpitEnvironment(
          platform: 'windows',
          flutterVersion: '3.38.9',
          dartVersion: '3.10.8',
        ).toJson(),
        'commands': <Map<String, Object?>>[],
      }),
    );

    CockpitRunRemoteControlScriptRequest? capturedRequest;
    final runner = CommandRunner<int>('flutter_cockpit_devtools', 'test')
      ..addCommand(
        RunScriptCommand(
          runScript: (request) async {
            capturedRequest = request;
            return CockpitRunRemoteControlScriptResult(
              sessionHandle: null,
              bundleDir: Directory(tempDir.path),
              manifest: CockpitRunManifest(
                sessionId: 'remote-script-session',
                taskId: 'remote-script-task',
                platform: 'windows',
                status: CockpitTaskStatus.completed,
                startedAt: DateTime.utc(2026, 4, 17),
                finishedAt: DateTime.utc(2026, 4, 17, 0, 0, 1),
              ),
              handoff: const <String, Object?>{},
              delivery: const <String, Object?>{},
              artifactPaths: CockpitBundleArtifactPaths(),
            );
          },
        ),
      );

    final exitCode = await _runCommandRunner(runner, [
      'run-script',
      '--app-json',
      appHandleFile.path,
      '--script-json',
      scriptFile.path,
      '--output-root',
      tempDir.path,
    ]);

    expect(exitCode, 0);
    expect(capturedRequest?.platformAppId, 'cockpit_demo');
    expect(capturedRequest?.processId, 4101);
    expect(capturedRequest?.sessionHandle?.baseUrl, 'http://127.0.0.1:57331');
    expect(capturedRequest?.sessionHandle?.processId, 4101);
  });

  test(
    'run-script returns non-zero when the written bundle is failed',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_run_remote_cli_failed_bundle',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final appHandleFile = File(p.join(tempDir.path, 'app.json'));
      await appHandleFile.writeAsString(
        jsonEncode(
          CockpitAppHandle(
            appId: 'remote-demo-app',
            mode: CockpitAppMode.automation,
            platform: 'macos',
            deviceId: 'macos',
            projectDir: '/workspace/examples/cockpit_demo',
            target: 'cockpit/main.dart',
            baseUrl: 'http://127.0.0.1:57331',
            launchedAt: DateTime.utc(2026, 3, 30),
            platformAppId: 'dev.cockpit.demo',
          ).toJson(),
        ),
      );
      final scriptFile = File(p.join(tempDir.path, 'remote_script.json'));
      await scriptFile.writeAsString(
        jsonEncode(<String, Object?>{
          'sessionId': 'remote-script-session',
          'taskId': 'remote-script-task',
          'platform': 'macos',
          'environment': const CockpitEnvironment(
            platform: 'macos',
            flutterVersion: '3.38.9',
            dartVersion: '3.10.8',
          ).toJson(),
          'commands': <Map<String, Object?>>[],
        }),
      );

      final bundleDir = Directory(p.join(tempDir.path, 'bundle'))
        ..createSync(recursive: true);
      final runner = CommandRunner<int>('flutter_cockpit_devtools', 'test')
        ..addCommand(
          RunScriptCommand(
            runScript: (_) async => CockpitRunRemoteControlScriptResult(
              sessionHandle: null,
              bundleDir: bundleDir,
              manifest: CockpitRunManifest(
                sessionId: 'remote-script-session',
                taskId: 'remote-script-task',
                platform: 'macos',
                status: CockpitTaskStatus.failed,
                startedAt: DateTime.utc(2026, 3, 30),
                finishedAt: DateTime.utc(2026, 3, 30, 0, 0, 1),
                failureSummary: 'The script assertion failed.',
              ),
              handoff: const <String, Object?>{},
              delivery: const <String, Object?>{},
              artifactPaths: CockpitBundleArtifactPaths(),
            ),
          ),
        );

      final exitCode = await _runCommandRunner(runner, [
        'run-script',
        '--app-json',
        appHandleFile.path,
        '--script-json',
        scriptFile.path,
        '--output-root',
        tempDir.path,
      ]);

      expect(exitCode, isNonZero);
    },
  );
}

Future<int> _runCommandRunner(
  CommandRunner<int> runner,
  List<String> args,
) async {
  try {
    return await runner.run(args) ?? 0;
  } on Object {
    return 1;
  }
}

final class _FakeAndroidPortForwarder extends CockpitAndroidPortForwarder {
  const _FakeAndroidPortForwarder({required this.forwardedHostPort});

  final int forwardedHostPort;

  @override
  Future<int> ensureForwarded({
    required String deviceId,
    required int preferredHostPort,
    required int devicePort,
  }) async {
    return forwardedHostPort;
  }
}

final class _FakeRecordingAdapter implements CockpitRecordingAdapter {
  _FakeRecordingAdapter.fromSourceFile(this.sourceFilePath);

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
      durationMs: 800,
    );
  }
}

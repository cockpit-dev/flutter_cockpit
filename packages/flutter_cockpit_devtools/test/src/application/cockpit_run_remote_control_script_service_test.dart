import 'dart:convert';
import 'dart:io';

import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_application_service_exception.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_run_remote_control_script_service.dart';
import 'package:flutter_cockpit_devtools/src/cli/cockpit_control_script.dart';
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
}

import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:cockpit/cockpit.dart';
import 'package:cockpit/src/cli/cockpit_interactive_cli_support.dart';
import 'package:cockpit/src/application/cockpit_app_reference_resolver.dart';
import 'package:cockpit/src/cli/commands/query_remote_session_command.dart';
import 'package:cockpit/src/cli/commands/read_app_command.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test(
    'query-remote-session reuses the default latest remote session handle',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_query_remote_session_default',
      );
      final previousCurrent = Directory.current;
      Directory.current = tempDir;
      addTearDown(() async {
        Directory.current = previousCurrent;
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final defaultHandleFile = File(
        cockpitDefaultRemoteSessionHandlePath(tempDir.path),
      );
      await defaultHandleFile.parent.create(recursive: true);
      await defaultHandleFile.writeAsString(
        jsonEncode(
          CockpitRemoteSessionHandle(
            platform: 'ios',
            deviceId: 'simulator',
            projectDir: '/workspace/examples/cockpit_demo',
            target: 'lib/main.dart',
            appId: 'dev.cockpit.cockpitDemo',
            host: '127.0.0.1',
            hostPort: 47331,
            devicePort: 47331,
            baseUrl: 'http://127.0.0.1:47331',
            launchedAt: DateTime.utc(2026, 3, 21),
          ).toJson(),
        ),
      );

      final output = StringBuffer();
      final runner = CommandRunner<int>('cockpit', 'test')
        ..addCommand(
          QueryRemoteSessionCommand(
            stdoutSink: output,
            service: CockpitQueryRemoteSessionService(
              statusReader: (_) async => CockpitRemoteSessionStatus(
                sessionId: 'default-remote-session',
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
              ),
            ),
          ),
        );

      final exitCode =
          await runner.run(<String>[
            'query-remote-session',
            '--stdout-format',
            'json',
          ]) ??
          0;

      expect(exitCode, 0);
      final decoded = jsonDecode(output.toString()) as Map<String, Object?>;
      expect(
        (decoded['status'] as Map<String, Object?>)['sessionId'],
        'default-remote-session',
      );
      expect(decoded['recommendedNextStep'], 'ready_for_commands');
    },
  );

  test('read-app writes the running app payload', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final tempDir = await Directory.systemTemp.createTemp(
      'cockpit_query_remote_cli',
    );
    final previousCurrent = Directory.current;
    Directory.current = tempDir;
    addTearDown(() async {
      Directory.current = previousCurrent;
      await server.close(force: true);
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    server.listen((request) async {
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode(
          CockpitRemoteSessionStatus(
            sessionId: 'query-demo',
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
              supportedCommands: <CockpitCommandType>[CockpitCommandType.tap],
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
      await request.response.close();
    });

    final outputFile = File(p.join(tempDir.path, 'session.json'));
    final exitCode = await CockpitCommandRunner().run(<String>[
      'read-app',
      '--base-url',
      'http://127.0.0.1:${server.port}',
      '--output',
      outputFile.path,
      '--output-format',
      'json',
    ]);

    expect(exitCode, 0);
    final decoded = jsonDecode(await outputFile.readAsString());
    expect(decoded['sessionId'], 'query-demo');
    expect(decoded['currentRouteName'], '/home');
  });

  test('read-app uses the forwarded host port for Android devices', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final tempDir = await Directory.systemTemp.createTemp(
      'cockpit_query_remote_cli_android',
    );
    final previousCurrent = Directory.current;
    Directory.current = tempDir;
    addTearDown(() async {
      Directory.current = previousCurrent;
      await server.close(force: true);
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    server.listen((request) async {
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode(
          CockpitRemoteSessionStatus(
            sessionId: 'query-android-demo',
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
              supportedCommands: <CockpitCommandType>[CockpitCommandType.tap],
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
      await request.response.close();
    });

    final outputFile = File(p.join(tempDir.path, 'android_session.json'));
    final runner =
        CommandRunner<int>('cockpit', 'Host-side tooling for flutter_cockpit.')
          ..addCommand(
            ReadAppCommand(
              service: CockpitReadAppService(
                appReferenceResolver: CockpitAppReferenceResolver(
                  portForwarder: _FakeAndroidPortForwarder(
                    forwardedHostPort: server.port,
                  ),
                ),
              ),
            ),
          );
    final exitCode =
        await runner.run(<String>[
          'read-app',
          '--base-url',
          'http://127.0.0.1:47331',
          '--output',
          outputFile.path,
          '--output-format',
          'json',
          '--android-device-id',
          'emulator-5554',
        ]) ??
        0;

    expect(exitCode, 0);
    final decoded = jsonDecode(await outputFile.readAsString());
    expect(decoded['sessionId'], 'query-android-demo');
  });

  test('read-app can resolve its base URL from an app handle', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final tempDir = await Directory.systemTemp.createTemp(
      'cockpit_query_remote_cli_handle',
    );
    final previousCurrent = Directory.current;
    Directory.current = tempDir;
    addTearDown(() async {
      Directory.current = previousCurrent;
      await server.close(force: true);
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    server.listen((request) async {
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode(
          CockpitRemoteSessionStatus(
            sessionId: 'query-handle-demo',
            platform: 'ios',
            transportType: 'remoteHttp',
            currentRouteName: '/success',
            capabilities: CockpitCapabilities(
              platform: 'ios',
              transportType: 'remoteHttp',
              supportsInAppControl: true,
              supportsFlutterViewCapture: true,
              supportsNativeScreenCapture: true,
              supportsHostAutomation: false,
              supportedCommands: <CockpitCommandType>[CockpitCommandType.tap],
              supportedLocatorStrategies: CockpitLocatorKind.values,
            ),
            recordingCapabilities: CockpitRecordingCapabilities(
              supportsNativeRecording: true,
              preferredAcceptanceRecordingKind:
                  CockpitRecordingKind.nativeScreen,
            ),
            snapshot: CockpitSnapshot(routeName: '/success'),
          ).toJson(),
        ),
      );
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

    final outputFile = File(p.join(tempDir.path, 'session_status.json'));
    final exitCode = await CockpitCommandRunner().run(<String>[
      'read-app',
      '--app-json',
      sessionFile.path,
      '--output',
      outputFile.path,
      '--output-format',
      'json',
    ]);

    expect(exitCode, 0);
    final decoded = jsonDecode(await outputFile.readAsString());
    expect(decoded['sessionId'], 'query-handle-demo');
    expect(decoded['currentRouteName'], '/success');
  });

  test(
    'read-app uses the default latest app handle path in the current working directory',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_query_remote_cli_default_handle',
      );
      final previousCurrent = Directory.current;
      Directory.current = tempDir;
      addTearDown(() async {
        Directory.current = previousCurrent;
        await server.close(force: true);
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      server.listen((request) async {
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode(
            CockpitRemoteSessionStatus(
              sessionId: 'query-default-handle-demo',
              platform: 'ios',
              transportType: 'remoteHttp',
              currentRouteName: '/settings',
              capabilities: CockpitCapabilities(
                platform: 'ios',
                transportType: 'remoteHttp',
                supportsInAppControl: true,
                supportsFlutterViewCapture: true,
                supportsNativeScreenCapture: true,
                supportsHostAutomation: false,
                supportedCommands: <CockpitCommandType>[CockpitCommandType.tap],
                supportedLocatorStrategies: CockpitLocatorKind.values,
              ),
              recordingCapabilities: CockpitRecordingCapabilities(
                supportsNativeRecording: true,
                preferredAcceptanceRecordingKind:
                    CockpitRecordingKind.nativeScreen,
              ),
              snapshot: CockpitSnapshot(routeName: '/settings'),
            ).toJson(),
          ),
        );
        await request.response.close();
      });

      final sessionFile = File(cockpitDefaultAppHandlePath(tempDir.path));
      await sessionFile.parent.create(recursive: true);
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

      final outputFile = File(p.join(tempDir.path, 'session_status.json'));
      final exitCode = await CockpitCommandRunner().run(<String>[
        'read-app',
        '--output',
        outputFile.path,
        '--output-format',
        'json',
      ]);

      expect(exitCode, 0);
      final decoded = jsonDecode(await outputFile.readAsString());
      expect(decoded['sessionId'], 'query-default-handle-demo');
      expect(decoded['currentRouteName'], '/settings');
    },
  );

  test(
    'read-app prefers an explicit base-url over the implicit default app handle',
    () async {
      final implicitServer = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      final explicitServer = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_query_remote_cli_base_url_precedence',
      );
      final previousCurrent = Directory.current;
      Directory.current = tempDir;
      addTearDown(() async {
        Directory.current = previousCurrent;
        await implicitServer.close(force: true);
        await explicitServer.close(force: true);
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      Future<void> respond(
        HttpRequest request,
        String sessionId,
        String route,
      ) async {
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode(
            CockpitRemoteSessionStatus(
              sessionId: sessionId,
              platform: 'ios',
              transportType: 'remoteHttp',
              currentRouteName: route,
              capabilities: CockpitCapabilities(
                platform: 'ios',
                transportType: 'remoteHttp',
                supportsInAppControl: true,
                supportsFlutterViewCapture: true,
                supportsNativeScreenCapture: true,
                supportsHostAutomation: false,
                supportedCommands: <CockpitCommandType>[CockpitCommandType.tap],
                supportedLocatorStrategies: CockpitLocatorKind.values,
              ),
              recordingCapabilities: CockpitRecordingCapabilities(
                supportsNativeRecording: true,
                preferredAcceptanceRecordingKind:
                    CockpitRecordingKind.nativeScreen,
              ),
              snapshot: CockpitSnapshot(routeName: route),
            ).toJson(),
          ),
        );
        await request.response.close();
      }

      implicitServer.listen(
        (request) =>
            respond(request, 'query-implicit-handle-demo', '/implicit'),
      );
      explicitServer.listen(
        (request) =>
            respond(request, 'query-explicit-base-url-demo', '/explicit'),
      );

      final sessionFile = File(cockpitDefaultAppHandlePath(tempDir.path));
      await sessionFile.parent.create(recursive: true);
      await sessionFile.writeAsString(
        jsonEncode(<String, Object?>{
          'appId': 'dev.cockpit.cockpitDemo',
          'mode': 'automation',
          'platform': 'ios',
          'deviceId': 'simulator',
          'projectDir': '/workspace/examples/cockpit_demo',
          'target': 'lib/main.dart',
          'baseUrl': 'http://127.0.0.1:${implicitServer.port}',
          'launchedAt': '2026-03-21T00:00:00.000Z',
        }),
      );

      final outputFile = File(p.join(tempDir.path, 'session_status.json'));
      final exitCode = await CockpitCommandRunner().run(<String>[
        'read-app',
        '--base-url',
        'http://127.0.0.1:${explicitServer.port}',
        '--output',
        outputFile.path,
        '--output-format',
        'json',
      ]);

      expect(exitCode, 0);
      final decoded = jsonDecode(await outputFile.readAsString());
      expect(decoded['sessionId'], 'query-explicit-base-url-demo');
      expect(decoded['currentRouteName'], '/explicit');
    },
  );

  test(
    'read-app uses explicit app-json metadata with an explicit base-url connection override',
    () async {
      final appHandleServer = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      final baseUrlServer = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_query_remote_cli_app_json_precedence',
      );
      final previousCurrent = Directory.current;
      Directory.current = tempDir;
      addTearDown(() async {
        Directory.current = previousCurrent;
        await appHandleServer.close(force: true);
        await baseUrlServer.close(force: true);
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      Future<void> respond(
        HttpRequest request,
        String sessionId,
        String route,
      ) async {
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode(
            CockpitRemoteSessionStatus(
              sessionId: sessionId,
              platform: 'ios',
              transportType: 'remoteHttp',
              currentRouteName: route,
              capabilities: CockpitCapabilities(
                platform: 'ios',
                transportType: 'remoteHttp',
                supportsInAppControl: true,
                supportsFlutterViewCapture: true,
                supportsNativeScreenCapture: true,
                supportsHostAutomation: false,
                supportedCommands: <CockpitCommandType>[CockpitCommandType.tap],
                supportedLocatorStrategies: CockpitLocatorKind.values,
              ),
              recordingCapabilities: CockpitRecordingCapabilities(
                supportsNativeRecording: true,
                preferredAcceptanceRecordingKind:
                    CockpitRecordingKind.nativeScreen,
              ),
              snapshot: CockpitSnapshot(routeName: route),
            ).toJson(),
          ),
        );
        await request.response.close();
      }

      appHandleServer.listen(
        (request) =>
            respond(request, 'query-explicit-app-json-demo', '/handle'),
      );
      baseUrlServer.listen(
        (request) =>
            respond(request, 'query-explicit-base-url-demo', '/base-url'),
      );

      final sessionFile = File(p.join(tempDir.path, 'explicit_app.json'));
      await sessionFile.writeAsString(
        jsonEncode(<String, Object?>{
          'appId': 'dev.cockpit.cockpitDemo',
          'mode': 'automation',
          'platform': 'ios',
          'deviceId': 'simulator',
          'projectDir': '/workspace/examples/cockpit_demo',
          'target': 'lib/main.dart',
          'baseUrl': 'http://127.0.0.1:${appHandleServer.port}',
          'launchedAt': '2026-03-21T00:00:00.000Z',
        }),
      );

      final outputFile = File(p.join(tempDir.path, 'session_status.json'));
      final exitCode = await CockpitCommandRunner().run(<String>[
        'read-app',
        '--app-json',
        sessionFile.path,
        '--base-url',
        'http://127.0.0.1:${baseUrlServer.port}',
        '--output',
        outputFile.path,
        '--output-format',
        'json',
      ]);

      expect(exitCode, 0);
      final decoded = jsonDecode(await outputFile.readAsString());
      expect(decoded['sessionId'], 'query-explicit-base-url-demo');
      expect(decoded['currentRouteName'], '/base-url');
    },
  );
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

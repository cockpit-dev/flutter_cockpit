import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_cockpit_devtools/flutter_cockpit_devtools.dart';
import 'package:flutter_cockpit_devtools/src/cli/commands/query_remote_session_command.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('query-remote-session writes the running app health payload', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final tempDir = await Directory.systemTemp.createTemp(
      'cockpit_query_remote_cli',
    );
    addTearDown(() async {
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
      'query-remote-session',
      '--base-url',
      'http://127.0.0.1:${server.port}',
      '--output-json',
      outputFile.path,
    ]);

    expect(exitCode, 0);
    final decoded = jsonDecode(await outputFile.readAsString());
    expect(decoded['sessionId'], 'query-demo');
    expect(decoded['currentRouteName'], '/home');
  });

  test(
    'query-remote-session uses the forwarded host port for Android devices',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_query_remote_cli_android',
      );
      addTearDown(() async {
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
      final runner = CommandRunner<int>(
        'flutter_cockpit_devtools',
        'Host-side tooling for flutter_cockpit.',
      )..addCommand(
          QueryRemoteSessionCommand(
            portForwarder: _FakeAndroidPortForwarder(
              forwardedHostPort: server.port,
            ),
          ),
        );
      final exitCode = await runner.run(<String>[
            'query-remote-session',
            '--base-url',
            'http://127.0.0.1:47331',
            '--output-json',
            outputFile.path,
            '--android-device-id',
            'emulator-5554',
          ]) ??
          0;

      expect(exitCode, 0);
      final decoded = jsonDecode(await outputFile.readAsString());
      expect(decoded['sessionId'], 'query-android-demo');
    },
  );

  test(
    'query-remote-session can resolve its base URL from a session handle',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_query_remote_cli_handle',
      );
      addTearDown(() async {
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

      final sessionFile = File(p.join(tempDir.path, 'session_handle.json'));
      await sessionFile.writeAsString(
        jsonEncode(<String, Object?>{
          'platform': 'ios',
          'deviceId': 'simulator',
          'projectDir': '/workspace/examples/cockpit_demo',
          'target': 'lib/main.dart',
          'appId': 'dev.cockpit.cockpitDemo',
          'host': '127.0.0.1',
          'hostPort': server.port,
          'devicePort': server.port,
          'baseUrl': 'http://127.0.0.1:${server.port}',
          'launchedAt': '2026-03-21T00:00:00.000Z',
        }),
      );

      final outputFile = File(p.join(tempDir.path, 'session_status.json'));
      final exitCode = await CockpitCommandRunner().run(<String>[
        'query-remote-session',
        '--session-json',
        sessionFile.path,
        '--output-json',
        outputFile.path,
      ]);

      expect(exitCode, 0);
      final decoded = jsonDecode(await outputFile.readAsString());
      expect(decoded['sessionId'], 'query-handle-demo');
      expect(decoded['currentRouteName'], '/success');
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

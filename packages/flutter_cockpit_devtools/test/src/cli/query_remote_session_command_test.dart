import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_cockpit_devtools/flutter_cockpit_devtools.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_app_reference_resolver.dart';
import 'package:flutter_cockpit_devtools/src/cli/commands/read_app_command.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('read-app writes the running app payload', () async {
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
      'read-app',
      '--base-url',
      'http://127.0.0.1:${server.port}',
      '--output-json',
      outputFile.path,
    ]);

    expect(exitCode, 0);
    final decoded = jsonDecode(await outputFile.readAsString());
    expect(decoded['session_id'], 'query-demo');
    expect(decoded['current_route_name'], '/home');
  });

  test(
    'read-app uses the forwarded host port for Android devices',
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
      final exitCode = await runner.run(<String>[
            'read-app',
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
      expect(decoded['session_id'], 'query-android-demo');
    },
  );

  test(
    'read-app can resolve its base URL from an app handle',
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
          'app_id': 'dev.cockpit.cockpitDemo',
          'mode': 'automation',
          'platform': 'ios',
          'device_id': 'simulator',
          'project_dir': '/workspace/examples/cockpit_demo',
          'target': 'lib/main.dart',
          'base_url': 'http://127.0.0.1:${server.port}',
          'launched_at': '2026-03-21T00:00:00.000Z',
        }),
      );

      final outputFile = File(p.join(tempDir.path, 'session_status.json'));
      final exitCode = await CockpitCommandRunner().run(<String>[
        'read-app',
        '--app-json',
        sessionFile.path,
        '--output-json',
        outputFile.path,
      ]);

      expect(exitCode, 0);
      final decoded = jsonDecode(await outputFile.readAsString());
      expect(decoded['session_id'], 'query-handle-demo');
      expect(decoded['current_route_name'], '/success');
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

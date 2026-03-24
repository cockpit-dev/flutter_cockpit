import 'dart:convert';
import 'dart:io';

import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_cockpit_devtools/flutter_cockpit_devtools.dart';
import 'package:test/test.dart';

void main() {
  test(
    'remote automation adapter exposes capabilities and executes commands',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
      });

      server.listen((request) async {
        request.response.headers.contentType = ContentType.json;
        switch ((request.method, request.uri.path)) {
          case ('GET', '/health'):
            request.response.write(
              jsonEncode(
                CockpitRemoteSessionStatus(
                  sessionId: 'adapter-demo',
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
            request.response.write(
              jsonEncode(
                CockpitRemoteCommandResponse(
                  result: CockpitCommandResult(
                    success: true,
                    commandId: 'tap-open',
                    commandType: CockpitCommandType.tap,
                    durationMs: 21,
                    snapshot: CockpitSnapshot(routeName: '/form').toJson(),
                  ),
                  artifactPayloads: const <CockpitRemoteArtifactPayload>[
                    CockpitRemoteArtifactPayload(
                      artifact: CockpitArtifactRef(
                        role: 'screenshot',
                        relativePath: 'screenshots/form_after_action.png',
                      ),
                      bytes: <int>[2, 4, 6],
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

      final client = CockpitRemoteSessionClient(
        baseUri: Uri.parse('http://127.0.0.1:${server.port}'),
      );
      final adapter = CockpitRemoteAutomationAdapter(client: client);

      final capabilities = await adapter.describeCapabilities();
      final execution = await adapter.execute(
        CockpitCommand(
          commandId: 'tap-open',
          commandType: CockpitCommandType.tap,
          locator: const CockpitLocator(
            kind: CockpitLocatorKind.cockpitId,
            value: 'open_form_button',
          ),
        ),
      );

      expect(capabilities.transportType, 'remoteHttp');
      expect(execution.result.success, isTrue);
      expect(execution.result.snapshot?['routeName'], '/form');
      expect(
        execution.artifactPayloads['screenshots/form_after_action.png'],
        <int>[2, 4, 6],
      );
    },
  );
}

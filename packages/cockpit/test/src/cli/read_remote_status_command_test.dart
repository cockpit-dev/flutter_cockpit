import 'dart:convert';

import 'package:args/command_runner.dart';
import 'package:cockpit_protocol/cockpit_protocol.dart';
import 'package:cockpit/src/application/cockpit_read_remote_status_service.dart';
import 'package:cockpit/src/cli/commands/read_remote_status_command.dart';
import 'package:test/test.dart';

void main() {
  test('read-remote-status writes structured JSON', () async {
    CockpitReadRemoteStatusRequest? capturedRequest;
    final stdoutBuffer = StringBuffer();
    final runner = CommandRunner<int>('cockpit', 'test')
      ..addCommand(
        ReadRemoteStatusCommand(
          stdoutSink: stdoutBuffer,
          read: (request) async {
            capturedRequest = request;
            return CockpitReadRemoteStatusResult(
              sessionId: 'session-1',
              platform: 'macos',
              transportType: 'remoteHttp',
              currentRouteName: '/home',
              capabilities: CockpitCapabilities(
                platform: 'macos',
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
                preferredAcceptanceRecordingKind:
                    CockpitRecordingKind.nativeScreen,
              ),
            );
          },
        ),
      );

    final exitCode =
        await runner.run(<String>[
          'read-remote-status',
          '--stdout-format',
          'json',
          '--base-url',
          'http://127.0.0.1:47331',
          '--profile',
          'minimal',
        ]) ??
        0;

    expect(exitCode, 0);
    expect(capturedRequest?.resultProfile.name.jsonValue, 'minimal');
    final decoded = jsonDecode(stdoutBuffer.toString()) as Map<String, Object?>;
    expect(decoded['sessionId'], 'session-1');
    expect(decoded.containsKey('activeRecording'), isFalse);
    expect(decoded.containsKey('environment'), isFalse);
    expect(decoded.containsKey('snapshot'), isFalse);
    expect(decoded.containsKey('snapshotRef'), isFalse);
  });
}

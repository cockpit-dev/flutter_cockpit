import 'dart:convert';

import 'package:args/command_runner.dart';
import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_read_remote_snapshot_service.dart';
import 'package:flutter_cockpit_devtools/src/cli/commands/read_remote_snapshot_command.dart';
import 'package:test/test.dart';

void main() {
  test('read-remote-snapshot parses options and compare refs', () async {
    CockpitReadRemoteSnapshotRequest? capturedRequest;
    final stdoutBuffer = StringBuffer();
    final runner = CommandRunner<int>('flutter_cockpit_devtools', 'test')
      ..addCommand(
        ReadRemoteSnapshotCommand(
          stdoutSink: stdoutBuffer,
          read: (request) async {
            capturedRequest = request;
            return const CockpitReadRemoteSnapshotResult(
              routeName: '/details',
              diagnosticLevel: 'baseline',
              truncated: false,
            );
          },
        ),
      );

    final exitCode =
        await runner.run(<String>[
          'read-remote-snapshot',
          '--stdout-format',
          'json',
          '--base-url',
          'http://127.0.0.1:47331',
          '--profile',
          'inspect',
          '--snapshot-options-json',
          jsonEncode(const <String, Object?>{'profile': 'forensic'}),
          '--compare-against-snapshot-ref',
          'snapshot-1',
        ]) ??
        0;

    expect(exitCode, 0);
    expect(capturedRequest?.resultProfile.name.jsonValue, 'inspect');
    expect(
      capturedRequest?.snapshotOptions?.profile,
      CockpitSnapshotProfile.forensic,
    );
    expect(capturedRequest?.compareAgainstSnapshotRef, 'snapshot-1');
    final decoded = jsonDecode(stdoutBuffer.toString()) as Map<String, Object?>;
    expect(decoded['routeName'], '/details');
  });
}

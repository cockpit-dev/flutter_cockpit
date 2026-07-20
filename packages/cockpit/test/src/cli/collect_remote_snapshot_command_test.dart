import 'dart:convert';

import 'package:args/command_runner.dart';
import 'package:cockpit_protocol/cockpit_protocol.dart';
import 'package:cockpit/src/application/cockpit_collect_remote_snapshot_service.dart';
import 'package:cockpit/src/cli/commands/collect_remote_snapshot_command.dart';
import 'package:cockpit/src/session/cockpit_remote_session_handle.dart';
import 'package:test/test.dart';

void main() {
  test(
    'collect-remote-snapshot writes snapshot payload, effective options, and warnings',
    () async {
      CockpitCollectRemoteSnapshotRequest? capturedRequest;
      final output = StringBuffer();
      final commandRunner = CommandRunner<int>('cockpit', 'test')
        ..addCommand(
          CollectRemoteSnapshotCommand(
            stdoutSink: output,
            collect: (request) async {
              capturedRequest = request;
              return CockpitCollectRemoteSnapshotResult(
                snapshot: CockpitSnapshot(
                  routeName: '/network',
                  diagnosticLevel: request.options.profile,
                ),
                effectiveOptions: request.options.copyWith(
                  emitArtifactWhenLarge: false,
                ),
                warnings: const <String>[
                  'Direct remote snapshots do not support downloadable diagnostic artifacts; falling back to inline diagnostics.',
                ],
                sessionHandle: CockpitRemoteSessionHandle(
                  platform: 'android',
                  deviceId: 'emulator-5554',
                  projectDir: '/workspace/examples/cockpit_demo',
                  target: 'lib/main.dart',
                  appId: 'dev.cockpit.cockpit_demo',
                  host: '127.0.0.1',
                  hostPort: 47331,
                  devicePort: 47331,
                  baseUrl: 'http://127.0.0.1:47331',
                  launchedAt: DateTime.utc(2026, 3, 22, 0, 0),
                ),
              );
            },
          ),
        );

      final exitCode =
          await commandRunner.run(<String>[
            'collect-remote-snapshot',
            '--stdout-format',
            'json',
            '--base-url',
            'http://127.0.0.1:47331',
            '--profile',
            'investigate',
            '--include-accessibility-summary',
            '--max-accessibility-entries',
            '5',
            '--include-network-activity',
            '--include-runtime-activity',
            '--network-method',
            'POST',
            '--network-uri-contains',
            '/tasks',
            '--network-only-failures',
            '--runtime-only-errors',
            '--runtime-message-contains',
            'runtime probe',
            '--emit-artifact-when-large',
            '--download-diagnostics-artifacts',
          ]) ??
          0;

      expect(exitCode, 0);
      expect(capturedRequest?.baseUri, Uri.parse('http://127.0.0.1:47331'));
      expect(
        capturedRequest?.options.profile,
        CockpitSnapshotProfile.investigate,
      );
      expect(capturedRequest?.options.includeNetworkActivity, isTrue);
      expect(capturedRequest?.options.networkQuery.method, 'POST');
      expect(capturedRequest?.options.networkQuery.uriContains, '/tasks');
      expect(capturedRequest?.options.networkQuery.onlyFailures, isTrue);
      expect(capturedRequest?.options.includeRuntimeActivity, isTrue);
      expect(capturedRequest?.options.runtimeQuery.onlyErrors, isTrue);
      expect(
        capturedRequest?.options.runtimeQuery.messageContains,
        'runtime probe',
      );
      expect(capturedRequest?.options.includeAccessibilitySummary, isTrue);
      expect(capturedRequest?.options.maxAccessibilityEntries, 5);
      expect(capturedRequest?.options.emitArtifactWhenLarge, isTrue);
      expect(capturedRequest?.downloadDiagnosticsArtifacts, isTrue);

      final decoded =
          jsonDecode(output.toString().trim()) as Map<String, Object?>;
      expect(
        (decoded['snapshot'] as Map<String, Object?>)['routeName'],
        '/network',
      );
      expect(
        (decoded['effectiveOptions'] as Map<String, Object?>)['profile'],
        'investigate',
      );
      expect(
        (decoded['warnings'] as List<Object?>).single,
        contains('inline diagnostics'),
      );
    },
  );

  test(
    'collect-remote-snapshot lets callers override forensic network failure filtering',
    () async {
      CockpitCollectRemoteSnapshotRequest? capturedRequest;
      final commandRunner = CommandRunner<int>('cockpit', 'test')
        ..addCommand(
          CollectRemoteSnapshotCommand(
            stdoutSink: StringBuffer(),
            collect: (request) async {
              capturedRequest = request;
              return CockpitCollectRemoteSnapshotResult(
                snapshot: CockpitSnapshot(
                  routeName: '/network',
                  diagnosticLevel: request.options.profile,
                ),
                effectiveOptions: request.options,
              );
            },
          ),
        );

      final exitCode =
          await commandRunner.run(<String>[
            'collect-remote-snapshot',
            '--base-url',
            'http://127.0.0.1:47331',
            '--profile',
            'forensic',
            '--include-network-activity',
            '--no-network-only-failures',
            '--include-runtime-activity',
            '--no-runtime-only-errors',
          ]) ??
          0;

      expect(exitCode, 0);
      expect(capturedRequest?.options.profile, CockpitSnapshotProfile.forensic);
      expect(capturedRequest?.options.includeNetworkActivity, isTrue);
      expect(capturedRequest?.options.networkQuery.onlyFailures, isFalse);
      expect(capturedRequest?.options.includeRuntimeActivity, isTrue);
      expect(capturedRequest?.options.runtimeQuery.onlyErrors, isFalse);
    },
  );

  test('collect-remote-snapshot rejects negative collection limits', () async {
    final commandRunner = CommandRunner<int>('cockpit', 'test')
      ..addCommand(
        CollectRemoteSnapshotCommand(
          stdoutSink: StringBuffer(),
          collect: (_) async => CockpitCollectRemoteSnapshotResult(
            snapshot: CockpitSnapshot(routeName: '/home'),
            effectiveOptions: const CockpitSnapshotOptions(),
          ),
        ),
      );

    expect(
      () => commandRunner.run(<String>[
        'collect-remote-snapshot',
        '--base-url',
        'http://127.0.0.1:47331',
        '--max-network-entries',
        '-1',
      ]),
      throwsA(
        isA<UsageException>().having(
          (error) => error.message,
          'message',
          contains('--max-network-entries must be a non-negative integer.'),
        ),
      ),
    );
  });

  test(
    'collect-remote-snapshot leaves externalized diagnostics deferred by default',
    () async {
      CockpitCollectRemoteSnapshotRequest? capturedRequest;
      final commandRunner = CommandRunner<int>('cockpit', 'test')
        ..addCommand(
          CollectRemoteSnapshotCommand(
            stdoutSink: StringBuffer(),
            collect: (request) async {
              capturedRequest = request;
              return CockpitCollectRemoteSnapshotResult(
                snapshot: CockpitSnapshot(
                  routeName: '/network',
                  diagnosticLevel: request.options.profile,
                ),
                effectiveOptions: request.options,
              );
            },
          ),
        );

      final exitCode =
          await commandRunner.run(<String>[
            'collect-remote-snapshot',
            '--base-url',
            'http://127.0.0.1:47331',
            '--profile',
            'forensic',
            '--emit-artifact-when-large',
          ]) ??
          0;

      expect(exitCode, 0);
      expect(capturedRequest?.options.emitArtifactWhenLarge, isTrue);
      expect(capturedRequest?.downloadDiagnosticsArtifacts, isFalse);
    },
  );
}

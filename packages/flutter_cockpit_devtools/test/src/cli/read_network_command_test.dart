import 'dart:convert';

import 'package:args/command_runner.dart';
import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_read_network_service.dart';
import 'package:flutter_cockpit_devtools/src/cli/commands/read_network_command.dart';
import 'package:test/test.dart';

void main() {
  test('read-network accepts app references and query controls', () async {
    CockpitReadNetworkRequest? capturedRequest;
    final stdoutBuffer = StringBuffer();
    final runner = CommandRunner<int>('flutter_cockpit_devtools', 'test')
      ..addCommand(
        ReadNetworkCommand(
          stdoutSink: stdoutBuffer,
          read: (request) async {
            capturedRequest = request;
            return CockpitReadNetworkResult(
              appId: 'dev.example.app',
              source: 'app_snapshot',
              available: true,
              routeName: '/inbox',
              summary: const CockpitReadNetworkSummary(
                totalEntryCount: 3,
                failureCount: 1,
                capturedEntryCount: 5,
                inFlightCount: 0,
                truncated: false,
                query: CockpitNetworkQuery(uriContains: '/api'),
              ),
              endpointSummaries: const <CockpitNetworkEndpointSummary>[],
              endpointSummariesTruncated: false,
              recentFailures: const <CockpitNetworkEntry>[],
            );
          },
        ),
      );

    final exitCode = await runner.run(<String>[
          'read-network',
          '--app-json',
          '/tmp/app.json',
          '--max-entries',
          '12',
          '--max-endpoints',
          '4',
          '--method',
          'POST',
          '--uri-contains',
          '/api/send',
          '--status-code-at-least',
          '400',
          '--only-failures',
          '--include-entries',
          '--stdout-format',
          'json',
        ]) ??
        0;

    expect(exitCode, 0);
    expect(capturedRequest?.appHandlePath, '/tmp/app.json');
    expect(capturedRequest?.maxEntries, 12);
    expect(capturedRequest?.maxEndpointSummaries, 4);
    expect(capturedRequest?.method, 'POST');
    expect(capturedRequest?.uriContains, '/api/send');
    expect(capturedRequest?.statusCodeAtLeast, 400);
    expect(capturedRequest?.onlyFailures, isTrue);
    expect(capturedRequest?.includeEntries, isTrue);
    final decoded = jsonDecode(stdoutBuffer.toString()) as Map<String, Object?>;
    expect(decoded['appId'], 'dev.example.app');
    expect(decoded['available'], isTrue);
    expect(decoded['summary'], isA<Map<String, Object?>>());
  });
}

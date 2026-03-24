import 'dart:convert';

import 'package:args/command_runner.dart';
import 'package:flutter_cockpit_devtools/flutter_cockpit_devtools.dart';
import 'package:flutter_cockpit_devtools/src/cli/commands/compare_development_probe_command.dart';
import 'package:test/test.dart';

void main() {
  test(
    'compare-development-probe accepts explicit from/to probe paths',
    () async {
      CockpitCompareDevelopmentProbeRequest? capturedRequest;
      final output = StringBuffer();
      final runner = CommandRunner<int>('flutter_cockpit_devtools', 'test')
        ..addCommand(
          CompareDevelopmentProbeCommand(
            stdoutSink: output,
            compare: (request) async {
              capturedRequest = request;
              return CockpitCompareDevelopmentProbeResult(
                fromProbe: _probe('probe-before'),
                toProbe: _probe('probe-after'),
                delta: const CockpitDevelopmentProbeDelta(
                  fromProbeId: 'probe-before',
                  toProbeId: 'probe-after',
                  reloadGenerationChanged: true,
                  routeChanged: true,
                  focusChanged: false,
                  overlayChanged: false,
                  visualChanged: false,
                  screenshotChanged: false,
                  changeSummary: 'route changed',
                ),
              );
            },
          ),
        );

      final exitCode = await runner.run(<String>[
            'compare-development-probe',
            '--from-probe-json',
            '/tmp/before.json',
            '--to-probe-json',
            '/tmp/after.json',
          ]) ??
          0;

      expect(exitCode, 0);
      expect(capturedRequest?.fromProbePath, '/tmp/before.json');
      expect(capturedRequest?.toProbePath, '/tmp/after.json');
      final decoded = jsonDecode(output.toString()) as Map<String, Object?>;
      expect(
        (decoded['delta'] as Map<String, Object?>)['routeChanged'],
        isTrue,
      );
    },
  );
}

CockpitDevelopmentProbe _probe(String probeId) {
  return CockpitDevelopmentProbe(
    probeId: probeId,
    sessionId: 'dev-session-1',
    reloadGeneration: 1,
    capturedAt: DateTime.utc(2026, 3, 23),
    reason: CockpitDevelopmentProbeReason.manual,
    profile: CockpitDevelopmentProbeProfile.quick,
    routeName: '/home',
  );
}

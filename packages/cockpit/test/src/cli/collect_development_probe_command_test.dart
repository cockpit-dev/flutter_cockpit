import 'dart:convert';

import 'package:args/command_runner.dart';
import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:cockpit/cockpit.dart';
import 'package:cockpit/src/cli/commands/collect_development_probe_command.dart';
import 'package:test/test.dart';

void main() {
  test(
    'collect-development-probe forwards profile, reason, and checkpoint',
    () async {
      CockpitCollectDevelopmentProbeRequest? capturedRequest;
      final output = StringBuffer();
      final runner = CommandRunner<int>('cockpit', 'test')
        ..addCommand(
          CollectDevelopmentProbeCommand(
            stdoutSink: output,
            collect: (request) async {
              capturedRequest = request;
              return CockpitCollectDevelopmentProbeResult(
                probe: CockpitDevelopmentProbe(
                  probeId: 'probe-1',
                  sessionId: 'dev-session-1',
                  reloadGeneration: 2,
                  capturedAt: DateTime.utc(2026, 3, 23),
                  reason: request.reason,
                  checkpoint: request.checkpoint,
                  profile: request.profile,
                  routeName: '/settings',
                ),
                sessionHandle: _handle(),
                effectiveSnapshotOptions:
                    const CockpitSnapshotOptions.baseline(),
              );
            },
          ),
        );

      final exitCode =
          await runner.run(<String>[
            'collect-development-probe',
            '--stdout-format',
            'json',
            '--session-json',
            '/tmp/dev-session.json',
            '--profile',
            'interactive',
            '--reason',
            'post_reload',
            '--checkpoint',
            'after_reload',
          ]) ??
          0;

      expect(exitCode, 0);
      expect(
        capturedRequest?.profile,
        CockpitDevelopmentProbeProfile.interactive,
      );
      expect(capturedRequest?.reason, CockpitDevelopmentProbeReason.postReload);
      expect(capturedRequest?.checkpoint, 'after_reload');
      final decoded = jsonDecode(output.toString()) as Map<String, Object?>;
      expect(
        (((decoded['probe'] as Map<String, Object?>)['profile'] as String)),
        'interactive',
      );
      expect(decoded.containsKey('effectiveSnapshotOptions'), isTrue);
    },
  );
}

CockpitDevelopmentSessionHandle _handle() {
  return CockpitDevelopmentSessionHandle(
    developmentSessionId: 'dev-session-1',
    platform: 'ios',
    deviceId: 'simulator',
    projectDir: '/workspace/examples/cockpit_demo',
    target: 'lib/main.dart',
    appId: 'dev.cockpit.cockpit_demo',
    appBaseUrl: 'http://127.0.0.1:58421',
    supervisorBaseUrl: 'http://127.0.0.1:59421',
    remoteSessionHandle: CockpitRemoteSessionHandle(
      platform: 'ios',
      deviceId: 'simulator',
      projectDir: '/workspace/examples/cockpit_demo',
      target: 'lib/main.dart',
      appId: 'dev.cockpit.cockpit_demo',
      host: '127.0.0.1',
      hostPort: 58421,
      devicePort: 47331,
      baseUrl: 'http://127.0.0.1:58421',
      launchedAt: DateTime.utc(2026, 3, 23),
    ),
    launchedAt: DateTime.utc(2026, 3, 23),
    reloadGeneration: 2,
  );
}

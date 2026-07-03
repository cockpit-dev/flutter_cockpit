import 'package:flutter_cockpit_protocol/flutter_cockpit_protocol.dart';
import 'package:cockpit/cockpit.dart';
import 'package:cockpit/src/mcp/tools/cockpit_collect_development_probe_tool.dart';
import 'package:test/test.dart';

void main() {
  test(
    'collect development probe tool forwards profile, reason, and checkpoint',
    () async {
      CockpitCollectDevelopmentProbeRequest? capturedRequest;
      final tool = CockpitCollectDevelopmentProbeTool(
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
            effectiveSnapshotOptions: const CockpitSnapshotOptions.baseline(),
          );
        },
      );

      final result = await tool.call(<String, Object?>{
        'sessionHandle': _handle().toJson(),
        'profile': 'interactive',
        'reason': 'post_reload',
        'checkpoint': 'after_reload',
      });

      expect(
        capturedRequest?.profile,
        CockpitDevelopmentProbeProfile.interactive,
      );
      expect(capturedRequest?.reason, CockpitDevelopmentProbeReason.postReload);
      final structured = result['structuredContent'] as Map<String, Object?>;
      expect(
        (structured['probe'] as Map<String, Object?>)['checkpoint'],
        'after_reload',
      );
    },
  );
}

CockpitDevelopmentSessionHandle _handle() => CockpitDevelopmentSessionHandle(
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

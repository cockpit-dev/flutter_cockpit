import 'package:flutter_cockpit_devtools/flutter_cockpit_devtools.dart';
import 'package:flutter_cockpit_devtools/src/mcp/tools/cockpit_compare_development_probe_tool.dart';
import 'package:test/test.dart';

void main() {
  test(
    'compare development probe tool accepts explicit from/to probes',
    () async {
      CockpitCompareDevelopmentProbeRequest? capturedRequest;
      final tool = CockpitCompareDevelopmentProbeTool(
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
            ),
          );
        },
      );

      final result = await tool.call(<String, Object?>{
        'from_probe': _probe('probe-before').toJson(),
        'to_probe': _probe('probe-after').toJson(),
      });

      expect(capturedRequest?.fromProbe?.probeId, 'probe-before');
      expect(capturedRequest?.toProbe?.probeId, 'probe-after');
      final structured = result['structuredContent'] as Map<String, Object?>;
      expect(
        (structured['delta'] as Map<String, Object?>)['routeChanged'],
        isTrue,
      );
    },
  );
}

CockpitDevelopmentProbe _probe(String probeId) => CockpitDevelopmentProbe(
      probeId: probeId,
      sessionId: 'dev-session-1',
      reloadGeneration: 1,
      capturedAt: DateTime.utc(2026, 3, 23),
      reason: CockpitDevelopmentProbeReason.manual,
      profile: CockpitDevelopmentProbeProfile.quick,
      routeName: '/home',
    );

import 'package:flutter_cockpit_devtools/src/application/cockpit_list_launch_targets_service.dart';
import 'package:flutter_cockpit_devtools/src/mcp/tools/cockpit_list_launch_targets_tool.dart';
import 'package:test/test.dart';

void main() {
  test(
    'list_targets exposes normalized launch platform in structured content',
    () async {
      final tool = CockpitListLaunchTargetsTool(
        listTargets: (_) async => const CockpitListLaunchTargetsResult(
          targets: <CockpitLaunchTarget>[
            CockpitLaunchTarget(
              id: 'macos',
              name: 'macOS',
              platform: 'macos',
              platformType: 'darwin',
              emulator: false,
              ephemeral: false,
              sdk: 'macos',
            ),
          ],
        ),
      );

      final result = await tool.call(const <String, Object?>{});
      final structured = result['structuredContent'] as Map<String, Object?>;
      final targets = structured['targets'] as List<Object?>;
      final target = targets.single as Map<String, Object?>;

      expect(target['id'], 'macos');
      expect(target['platform'], 'macos');
      expect(target['platformType'], 'darwin');
    },
  );
}

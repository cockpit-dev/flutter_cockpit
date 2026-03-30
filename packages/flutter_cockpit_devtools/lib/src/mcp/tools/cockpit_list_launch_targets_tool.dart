import '../../application/cockpit_list_launch_targets_service.dart';
import '../cockpit_mcp_tool.dart';

typedef CockpitListLaunchTargetsToolFunction
    = Future<CockpitListLaunchTargetsResult> Function();

final class CockpitListLaunchTargetsTool extends CockpitMcpTool {
  CockpitListLaunchTargetsTool({
    CockpitListLaunchTargetsService? service,
    CockpitListLaunchTargetsToolFunction? listTargets,
  }) : _listTargets =
            listTargets ?? (service ?? CockpitListLaunchTargetsService()).list;

  final CockpitListLaunchTargetsToolFunction _listTargets;

  @override
  String get name => 'list_launch_targets';

  @override
  String get description =>
      'List available Flutter launch targets from flutter devices --machine.';

  @override
  CockpitMcpToolAnnotations get annotations => const CockpitMcpToolAnnotations(
        readOnly: true,
        destructive: false,
        idempotent: true,
        longRunning: false,
        requiresSession: false,
        producesBundleEvidence: false,
      );

  @override
  List<CockpitMcpFeatureCategory> get categories =>
      const <CockpitMcpFeatureCategory>[
        CockpitMcpFeatureCategory.workspace,
        CockpitMcpFeatureCategory.sessionManagement,
      ];

  @override
  Map<String, Object?> get inputSchema => const <String, Object?>{
        'type': 'object',
        'properties': <String, Object?>{},
      };

  @override
  Future<Map<String, Object?>> call(Map<String, Object?> arguments) async {
    try {
      final result = await _listTargets();
      return cockpitMcpResult(
        text: 'Launch targets loaded.',
        structuredContent: result.toJson(),
      );
    } on Object catch (error) {
      cockpitRethrowAsMcpError(error);
    }
  }
}

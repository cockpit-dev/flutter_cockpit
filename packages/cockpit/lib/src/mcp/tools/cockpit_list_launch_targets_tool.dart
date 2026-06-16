import '../../application/cockpit_list_launch_targets_service.dart';
import '../cockpit_mcp_tool.dart';

typedef CockpitListLaunchTargetsToolFunction =
    Future<CockpitListLaunchTargetsResult> Function(Duration timeout);

final class CockpitListLaunchTargetsTool extends CockpitMcpTool {
  CockpitListLaunchTargetsTool({
    CockpitListLaunchTargetsService? service,
    CockpitListLaunchTargetsToolFunction? listTargets,
  }) : _listTargets =
           listTargets ??
           ((timeout) => (service ?? CockpitListLaunchTargetsService()).list(
             timeout: timeout,
           ));

  final CockpitListLaunchTargetsToolFunction _listTargets;

  @override
  String get name => 'list_targets';

  @override
  String get description =>
      'List reachable Flutter devices and platforms from flutter devices --machine.';

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
    'properties': <String, Object?>{
      'timeoutSeconds': <String, Object?>{'type': 'integer'},
    },
  };

  @override
  Future<Map<String, Object?>> call(Map<String, Object?> arguments) async {
    try {
      final timeoutSeconds =
          cockpitReadOptionalPositiveInt(arguments, 'timeoutSeconds') ?? 60;
      final result = await _listTargets(Duration(seconds: timeoutSeconds));
      return cockpitMcpResult(
        text: 'Launch targets loaded.',
        structuredContent: result.toJson(),
      );
    } on Object catch (error) {
      cockpitRethrowAsMcpError(error);
    }
  }
}

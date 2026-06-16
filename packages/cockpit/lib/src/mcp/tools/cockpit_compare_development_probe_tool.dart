import '../../application/cockpit_compare_development_probe_service.dart';
import '../cockpit_mcp_tool.dart';

typedef CockpitCompareDevelopmentProbeToolFunction =
    Future<CockpitCompareDevelopmentProbeResult> Function(
      CockpitCompareDevelopmentProbeRequest request,
    );

final class CockpitCompareDevelopmentProbeTool extends CockpitMcpTool {
  CockpitCompareDevelopmentProbeTool({
    CockpitCompareDevelopmentProbeService? service,
    CockpitCompareDevelopmentProbeToolFunction? compare,
  }) : _compare =
           compare ??
           (service ?? const CockpitCompareDevelopmentProbeService()).compare;

  final CockpitCompareDevelopmentProbeToolFunction _compare;

  @override
  String get name => 'compare_development_probe';

  @override
  String get description =>
      'Compare two development probes and return route/UI/network/runtime/rebuild deltas.';

  @override
  Map<String, Object?> get inputSchema => const <String, Object?>{
    'type': 'object',
    'properties': <String, Object?>{
      'fromProbe': <String, Object?>{'type': 'object'},
      'fromProbePath': <String, Object?>{'type': 'string'},
      'toProbe': <String, Object?>{'type': 'object'},
      'toProbePath': <String, Object?>{'type': 'string'},
    },
  };

  @override
  Future<Map<String, Object?>> call(Map<String, Object?> arguments) async {
    try {
      final result = await _compare(
        CockpitCompareDevelopmentProbeRequest(
          fromProbe: cockpitReadOptionalDevelopmentProbe(
            arguments,
            'fromProbe',
          ),
          fromProbePath: cockpitReadOptionalString(arguments, 'fromProbePath'),
          toProbe: cockpitReadOptionalDevelopmentProbe(arguments, 'toProbe'),
          toProbePath: cockpitReadOptionalString(arguments, 'toProbePath'),
        ),
      );
      return cockpitMcpResult(
        text: 'Development probes compared.',
        structuredContent: <String, Object?>{
          'fromProbe': result.fromProbe.toJson(),
          'toProbe': result.toProbe.toJson(),
          'delta': result.delta.toJson(),
        },
      );
    } on Object catch (error) {
      cockpitRethrowAsMcpError(error);
    }
  }
}

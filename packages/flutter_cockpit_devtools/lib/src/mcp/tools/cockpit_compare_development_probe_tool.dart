import '../../application/cockpit_compare_development_probe_service.dart';
import '../cockpit_mcp_tool.dart';

typedef CockpitCompareDevelopmentProbeToolFunction
    = Future<CockpitCompareDevelopmentProbeResult> Function(
  CockpitCompareDevelopmentProbeRequest request,
);

final class CockpitCompareDevelopmentProbeTool extends CockpitMcpTool {
  CockpitCompareDevelopmentProbeTool({
    CockpitCompareDevelopmentProbeService? service,
    CockpitCompareDevelopmentProbeToolFunction? compare,
  }) : _compare = compare ??
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
          'from_probe': <String, Object?>{'type': 'object'},
          'from_probe_path': <String, Object?>{'type': 'string'},
          'to_probe': <String, Object?>{'type': 'object'},
          'to_probe_path': <String, Object?>{'type': 'string'},
        },
      };

  @override
  Future<Map<String, Object?>> call(Map<String, Object?> arguments) async {
    try {
      final result = await _compare(
        CockpitCompareDevelopmentProbeRequest(
          fromProbe: cockpitReadOptionalDevelopmentProbe(
            arguments,
            'from_probe',
          ),
          fromProbePath: cockpitReadOptionalString(
            arguments,
            'from_probe_path',
          ),
          toProbe: cockpitReadOptionalDevelopmentProbe(arguments, 'to_probe'),
          toProbePath: cockpitReadOptionalString(arguments, 'to_probe_path'),
        ),
      );
      return cockpitMcpResult(
        text: 'Development probes compared.',
        structuredContent: <String, Object?>{
          'from_probe': result.fromProbe.toJson(),
          'to_probe': result.toProbe.toJson(),
          'delta': result.delta.toJson(),
        },
      );
    } on Object catch (error) {
      cockpitRethrowAsMcpError(error);
    }
  }
}

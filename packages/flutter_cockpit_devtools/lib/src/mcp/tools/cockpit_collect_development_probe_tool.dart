import '../../application/cockpit_collect_development_probe_service.dart';
import '../../development/cockpit_development_probe.dart';
import '../cockpit_mcp_tool.dart';

typedef CockpitCollectDevelopmentProbeToolFunction =
    Future<CockpitCollectDevelopmentProbeResult> Function(
      CockpitCollectDevelopmentProbeRequest request,
    );

final class CockpitCollectDevelopmentProbeTool extends CockpitMcpTool {
  CockpitCollectDevelopmentProbeTool({
    CockpitCollectDevelopmentProbeService? service,
    CockpitCollectDevelopmentProbeToolFunction? collect,
  }) : _collect =
           collect ??
           (service ?? CockpitCollectDevelopmentProbeService()).collect;

  final CockpitCollectDevelopmentProbeToolFunction _collect;

  @override
  String get name => 'collect_development_probe';

  @override
  String get description =>
      'Collect a quick, interactive, diagnostic, or forensic development probe from the current app state.';

  @override
  Map<String, Object?> get inputSchema => <String, Object?>{
    'type': 'object',
    'properties': <String, Object?>{
      'sessionHandle': const <String, Object?>{'type': 'object'},
      'sessionHandlePath': const <String, Object?>{'type': 'string'},
      'profile': <String, Object?>{
        'type': 'string',
        'enum': CockpitDevelopmentProbeProfile.values
            .map((value) => value.jsonValue)
            .toList(growable: false),
      },
      'reason': <String, Object?>{
        'type': 'string',
        'enum': CockpitDevelopmentProbeReason.values
            .map((value) => value.jsonValue)
            .toList(growable: false),
      },
      'checkpoint': const <String, Object?>{'type': 'string'},
    },
  };

  @override
  Future<Map<String, Object?>> call(Map<String, Object?> arguments) async {
    try {
      final result = await _collect(
        CockpitCollectDevelopmentProbeRequest(
          sessionHandle: cockpitReadOptionalDevelopmentSessionHandle(arguments),
          sessionHandlePath: cockpitReadOptionalString(
            arguments,
            'sessionHandlePath',
          ),
          profile: CockpitDevelopmentProbeProfile.fromJson(
            cockpitReadOptionalString(arguments, 'profile') ??
                CockpitDevelopmentProbeProfile.quick.jsonValue,
          ),
          reason: CockpitDevelopmentProbeReason.fromJson(
            cockpitReadOptionalString(arguments, 'reason') ??
                CockpitDevelopmentProbeReason.manual.jsonValue,
          ),
          checkpoint: cockpitReadOptionalString(arguments, 'checkpoint'),
        ),
      );
      return cockpitMcpResult(
        text: 'Development probe collected.',
        structuredContent: <String, Object?>{
          'probe': result.probe.toJson(),
          'sessionHandle': result.sessionHandle.toJson(),
          'effectiveSnapshotOptions': result.effectiveSnapshotOptions.toJson(),
          'warnings': result.warnings,
        },
      );
    } on Object catch (error) {
      cockpitRethrowAsMcpError(error);
    }
  }
}

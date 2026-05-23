import 'package:flutter_cockpit/flutter_cockpit.dart';

import '../../application/cockpit_collect_remote_snapshot_service.dart';
import '../cockpit_mcp_tool.dart';

typedef CockpitCollectRemoteSnapshotToolFunction =
    Future<CockpitCollectRemoteSnapshotResult> Function(
      CockpitCollectRemoteSnapshotRequest request,
    );

final class CockpitCollectRemoteSnapshotTool extends CockpitMcpTool {
  CockpitCollectRemoteSnapshotTool({
    CockpitCollectRemoteSnapshotService? service,
    CockpitCollectRemoteSnapshotToolFunction? collect,
  }) : _collect =
           collect ??
           (service ?? CockpitCollectRemoteSnapshotService()).collect;

  final CockpitCollectRemoteSnapshotToolFunction _collect;

  @override
  String get name => 'collect_remote_snapshot';

  @override
  String get description =>
      'Collect a remote flutter_cockpit snapshot with explicit diagnostic and network detail controls.';

  @override
  Map<String, Object?> get inputSchema => const <String, Object?>{
    'type': 'object',
    'properties': <String, Object?>{
      'sessionHandle': <String, Object?>{'type': 'object'},
      'sessionHandlePath': <String, Object?>{'type': 'string'},
      'snapshotOptions': <String, Object?>{'type': 'object'},
      'downloadDiagnosticsArtifacts': <String, Object?>{'type': 'boolean'},
    },
  };

  @override
  Future<Map<String, Object?>> call(Map<String, Object?> arguments) async {
    try {
      final snapshotOptionsJson = cockpitReadOptionalObject(
        arguments,
        'snapshotOptions',
      );
      final result = await _collect(
        CockpitCollectRemoteSnapshotRequest(
          sessionHandle: cockpitReadOptionalSessionHandle(arguments),
          sessionHandlePath: cockpitReadOptionalString(
            arguments,
            'sessionHandlePath',
          ),
          options: snapshotOptionsJson == null
              ? const CockpitSnapshotOptions.live()
              : CockpitSnapshotOptions.fromJson(snapshotOptionsJson),
          downloadDiagnosticsArtifacts:
              cockpitReadOptionalBool(
                arguments,
                'downloadDiagnosticsArtifacts',
              ) ??
              false,
        ),
      );

      return cockpitMcpResult(
        text: 'Remote snapshot collected.',
        structuredContent: <String, Object?>{
          'snapshot': result.snapshot.toJson(),
          'effectiveOptions': result.effectiveOptions.toJson(),
          'sessionHandle': result.sessionHandle?.toJson(),
          'warnings': result.warnings,
        },
      );
    } on Object catch (error) {
      cockpitRethrowAsMcpError(error);
    }
  }
}

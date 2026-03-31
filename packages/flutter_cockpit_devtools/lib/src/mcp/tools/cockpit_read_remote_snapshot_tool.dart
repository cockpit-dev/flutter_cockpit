import 'package:flutter_cockpit/flutter_cockpit.dart';

import '../../application/cockpit_interactive_result_profile.dart';
import '../../application/cockpit_read_remote_snapshot_service.dart';
import '../cockpit_mcp_tool.dart';

typedef CockpitReadRemoteSnapshotToolFunction
    = Future<CockpitReadRemoteSnapshotResult> Function(
  CockpitReadRemoteSnapshotRequest request,
);

final class CockpitReadRemoteSnapshotTool extends CockpitMcpTool {
  CockpitReadRemoteSnapshotTool({
    CockpitReadRemoteSnapshotService? service,
    CockpitReadRemoteSnapshotToolFunction? read,
  }) : _read = read ?? (service ?? CockpitReadRemoteSnapshotService()).read;

  final CockpitReadRemoteSnapshotToolFunction _read;

  @override
  String get name => 'read_remote_snapshot';

  @override
  String get description =>
      'Read a remote flutter_cockpit snapshot with layered interactive output.';

  @override
  CockpitMcpToolAnnotations get annotations => const CockpitMcpToolAnnotations(
        readOnly: true,
        destructive: false,
        idempotent: true,
        longRunning: false,
        requiresSession: true,
        producesBundleEvidence: false,
      );

  @override
  List<CockpitMcpFeatureCategory> get categories =>
      const <CockpitMcpFeatureCategory>[
        CockpitMcpFeatureCategory.inspection,
      ];

  @override
  Map<String, Object?> get inputSchema => const <String, Object?>{
        'type': 'object',
        'properties': <String, Object?>{
          'session_handle': <String, Object?>{'type': 'object'},
          'session_handle_path': <String, Object?>{'type': 'string'},
          'profile': <String, Object?>{'type': 'string'},
          'snapshot_options': <String, Object?>{'type': 'object'},
          'compare_against_snapshot_ref': <String, Object?>{'type': 'string'},
        },
      };

  @override
  Future<Map<String, Object?>> call(Map<String, Object?> arguments) async {
    try {
      final result = await _read(
        CockpitReadRemoteSnapshotRequest(
          sessionHandle: cockpitReadOptionalSessionHandle(arguments),
          sessionHandlePath: cockpitReadOptionalString(
            arguments,
            'session_handle_path',
          ),
          resultProfile: _readProfile(arguments),
          snapshotOptions: _readOptionalSnapshotOptions(arguments),
          compareAgainstSnapshotRef: cockpitReadOptionalString(
                arguments,
                'compare_against_snapshot_ref',
              ) ??
              cockpitReadOptionalString(arguments, 'compareAgainstSnapshotRef'),
        ),
      );
      return cockpitMcpResult(
        text: 'Remote snapshot read.',
        structuredContent: result.toJson(),
      );
    } on Object catch (error) {
      cockpitRethrowAsMcpError(error);
    }
  }

  CockpitInteractiveResultProfile _readProfile(Map<String, Object?> arguments) {
    final value = arguments['profile'] ??
        arguments['result_profile'] ??
        arguments['resultProfile'];
    if (value == null) {
      return const CockpitInteractiveResultProfile.standard();
    }
    return CockpitInteractiveResultProfile.preset(
      CockpitInteractiveResultProfileName.fromJson(value),
    );
  }

  CockpitSnapshotOptions? _readOptionalSnapshotOptions(
    Map<String, Object?> arguments,
  ) {
    final json = cockpitReadOptionalObject(arguments, 'snapshot_options') ??
        cockpitReadOptionalObject(arguments, 'snapshotOptions');
    if (json == null) {
      return null;
    }
    return CockpitSnapshotOptions.fromJson(json);
  }
}

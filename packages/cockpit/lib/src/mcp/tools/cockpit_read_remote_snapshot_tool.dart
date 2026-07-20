import 'package:cockpit_protocol/cockpit_protocol.dart';

import '../../application/cockpit_interactive_result_profile.dart';
import '../../application/cockpit_read_remote_snapshot_service.dart';
import '../cockpit_mcp_tool.dart';

typedef CockpitReadRemoteSnapshotToolFunction =
    Future<CockpitReadRemoteSnapshotResult> Function(
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
      const <CockpitMcpFeatureCategory>[CockpitMcpFeatureCategory.inspection];

  @override
  Map<String, Object?> get inputSchema => const <String, Object?>{
    'type': 'object',
    'properties': <String, Object?>{
      'sessionHandle': <String, Object?>{'type': 'object'},
      'sessionHandlePath': <String, Object?>{'type': 'string'},
      'iosDeviceId': <String, Object?>{'type': 'string'},
      'profile': <String, Object?>{'type': 'string'},
      'snapshotOptions': <String, Object?>{'type': 'object'},
      'compareAgainstSnapshotRef': <String, Object?>{'type': 'string'},
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
            'sessionHandlePath',
          ),
          iosDeviceId: cockpitReadOptionalString(arguments, 'iosDeviceId'),
          resultProfile: _readProfile(arguments),
          snapshotOptions: _readOptionalSnapshotOptions(arguments),
          compareAgainstSnapshotRef: cockpitReadOptionalString(
            arguments,
            'compareAgainstSnapshotRef',
          ),
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
    final value = cockpitReadOptionalString(arguments, 'profile');
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
    final json = cockpitReadOptionalObject(arguments, 'snapshotOptions');
    if (json == null) {
      return null;
    }
    return CockpitSnapshotOptions.fromJson(json);
  }
}

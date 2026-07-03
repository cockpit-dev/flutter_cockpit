import 'package:flutter_cockpit_protocol/flutter_cockpit_protocol.dart';

import '../../application/cockpit_inspect_surface_service.dart';
import '../../application/cockpit_interactive_result_profile.dart';
import '../cockpit_mcp_tool.dart';

typedef CockpitInspectSurfaceToolFunction =
    Future<CockpitInspectSurfaceResult> Function(
      CockpitInspectSurfaceRequest request,
    );

final class CockpitInspectSurfaceTool extends CockpitMcpTool {
  CockpitInspectSurfaceTool({
    CockpitInspectSurfaceService? service,
    CockpitInspectSurfaceToolFunction? inspect,
  }) : _inspect =
           inspect ?? (service ?? CockpitInspectSurfaceService()).inspect;

  final CockpitInspectSurfaceToolFunction _inspect;

  @override
  String get name => 'inspect_surface';

  @override
  String get description =>
      'Inspect a target surface with richer layering than read_target.';

  @override
  Map<String, Object?> get inputSchema => const <String, Object?>{
    'type': 'object',
    'properties': <String, Object?>{
      'targetJson': <String, Object?>{'type': 'string'},
      'appJson': <String, Object?>{'type': 'string'},
      'baseUrl': <String, Object?>{'type': 'string'},
      'androidDeviceId': <String, Object?>{'type': 'string'},
      'profile': <String, Object?>{'type': 'string'},
      'snapshotOptions': <String, Object?>{'type': 'object'},
      'compareAgainstSnapshotRef': <String, Object?>{'type': 'string'},
    },
  };

  @override
  Future<Map<String, Object?>> call(Map<String, Object?> arguments) async {
    try {
      final result = await _inspect(
        CockpitInspectSurfaceRequest(
          targetHandlePath: cockpitReadOptionalString(arguments, 'targetJson'),
          appHandlePath: cockpitReadOptionalString(arguments, 'appJson'),
          baseUri: _readOptionalBaseUri(arguments),
          androidDeviceId: cockpitReadOptionalString(
            arguments,
            'androidDeviceId',
          ),
          resultProfile: _readProfile(arguments),
          snapshotOptions: _readOptionalSnapshotOptions(arguments),
          compareAgainstSnapshotRef: cockpitReadOptionalString(
            arguments,
            'compareAgainstSnapshotRef',
          ),
        ),
      );
      return cockpitMcpResult(
        text: 'Target surface inspected.',
        structuredContent: result.toJson(),
      );
    } on Object catch (error) {
      cockpitRethrowAsMcpError(error);
    }
  }

  CockpitInteractiveResultProfile _readProfile(Map<String, Object?> arguments) {
    final value = arguments['profile'];
    if (value == null) {
      return const CockpitInteractiveResultProfile.inspect();
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

  Uri? _readOptionalBaseUri(Map<String, Object?> arguments) {
    final baseUrl = cockpitReadOptionalString(arguments, 'baseUrl');
    if (baseUrl == null || baseUrl.isEmpty) {
      return null;
    }
    return Uri.parse(baseUrl);
  }
}

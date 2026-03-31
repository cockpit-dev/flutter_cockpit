import 'package:flutter_cockpit/flutter_cockpit.dart';

import '../../application/cockpit_interactive_result_profile.dart';
import '../../application/cockpit_json_key_normalizer.dart';
import '../../application/cockpit_read_app_service.dart';
import '../cockpit_mcp_tool.dart';

typedef CockpitReadAppToolFunction = Future<CockpitReadAppResult> Function(
  CockpitReadAppRequest request,
);

final class CockpitReadAppTool extends CockpitMcpTool {
  CockpitReadAppTool({
    CockpitReadAppService? service,
    CockpitReadAppToolFunction? read,
  }) : _read = read ?? (service ?? CockpitReadAppService()).read;

  final CockpitReadAppToolFunction _read;

  @override
  String get name => 'read_app';

  @override
  String get description =>
      'Read lightweight app status with optional richer UI layering.';

  @override
  Map<String, Object?> get inputSchema => const <String, Object?>{
        'type': 'object',
        'properties': <String, Object?>{
          'app_id': <String, Object?>{'type': 'string'},
          'app_json': <String, Object?>{'type': 'string'},
          'base_url': <String, Object?>{'type': 'string'},
          'profile': <String, Object?>{'type': 'string'},
          'snapshot_options': <String, Object?>{'type': 'object'},
        },
      };

  @override
  Future<Map<String, Object?>> call(Map<String, Object?> arguments) async {
    try {
      final result = await _read(
        CockpitReadAppRequest(
          appId: cockpitReadOptionalString(arguments, 'app_id'),
          appHandlePath: cockpitReadOptionalString(arguments, 'app_json'),
          baseUri: _readOptionalBaseUri(arguments),
          resultProfile: _readProfile(arguments),
          snapshotOptions: _readOptionalSnapshotOptions(arguments),
        ),
      );
      return cockpitMcpResult(
        text: 'App status loaded.',
        structuredContent: result.toJson(),
      );
    } on Object catch (error) {
      cockpitRethrowAsMcpError(error);
    }
  }

  CockpitInteractiveResultProfile _readProfile(Map<String, Object?> arguments) {
    final value = arguments['profile'] ?? arguments['result_profile'];
    if (value == null) {
      return const CockpitInteractiveResultProfile.minimal();
    }
    return CockpitInteractiveResultProfile.preset(
      CockpitInteractiveResultProfileName.fromJson(value),
    );
  }

  CockpitSnapshotOptions? _readOptionalSnapshotOptions(
    Map<String, Object?> arguments,
  ) {
    final json = cockpitReadOptionalObject(arguments, 'snapshot_options');
    if (json == null) {
      return null;
    }
    return CockpitSnapshotOptions.fromJson(cockpitNormalizeJsonKeys(json));
  }

  Uri? _readOptionalBaseUri(Map<String, Object?> arguments) {
    final baseUrl = cockpitReadOptionalString(arguments, 'base_url');
    if (baseUrl == null || baseUrl.isEmpty) {
      return null;
    }
    return Uri.parse(baseUrl);
  }
}

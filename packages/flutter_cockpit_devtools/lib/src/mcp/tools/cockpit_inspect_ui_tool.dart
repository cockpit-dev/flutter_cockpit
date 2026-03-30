import 'package:flutter_cockpit/flutter_cockpit.dart';

import '../../application/cockpit_inspect_ui_service.dart';
import '../../application/cockpit_interactive_result_profile.dart';
import '../../application/cockpit_json_key_normalizer.dart';
import '../cockpit_mcp_tool.dart';

typedef CockpitInspectUiToolFunction = Future<CockpitInspectUiResult> Function(
  CockpitInspectUiRequest request,
);

final class CockpitInspectUiTool extends CockpitMcpTool {
  CockpitInspectUiTool({
    CockpitInspectUiService? service,
    CockpitInspectUiToolFunction? inspect,
  }) : _inspect = inspect ?? (service ?? CockpitInspectUiService()).inspect;

  final CockpitInspectUiToolFunction _inspect;

  @override
  String get name => 'inspect_ui';

  @override
  String get description =>
      'Inspect the current UI tree with summary, diagnostics, delta, and snapshot layers.';

  @override
  Map<String, Object?> get inputSchema => const <String, Object?>{
        'type': 'object',
        'properties': <String, Object?>{
          'app_id': <String, Object?>{'type': 'string'},
          'app_json': <String, Object?>{'type': 'string'},
          'base_url': <String, Object?>{'type': 'string'},
          'result_profile': <String, Object?>{'type': 'string'},
          'snapshot_options': <String, Object?>{'type': 'object'},
          'compare_against_snapshot_ref': <String, Object?>{'type': 'string'},
        },
      };

  @override
  Future<Map<String, Object?>> call(Map<String, Object?> arguments) async {
    try {
      final result = await _inspect(
        CockpitInspectUiRequest(
          appId: cockpitReadOptionalString(arguments, 'app_id'),
          appHandlePath: cockpitReadOptionalString(arguments, 'app_json'),
          baseUri: _readOptionalBaseUri(arguments),
          resultProfile: _readProfile(arguments),
          snapshotOptions: _readOptionalSnapshotOptions(arguments),
          compareAgainstSnapshotRef: cockpitReadOptionalString(
            arguments,
            'compare_against_snapshot_ref',
          ),
        ),
      );
      return cockpitMcpResult(
        text: 'UI inspection loaded.',
        structuredContent: result.toJson(),
      );
    } on Object catch (error) {
      cockpitRethrowAsMcpError(error);
    }
  }

  CockpitInteractiveResultProfile _readProfile(Map<String, Object?> arguments) {
    final value = arguments['result_profile'];
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

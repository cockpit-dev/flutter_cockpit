import 'package:flutter_cockpit/flutter_cockpit.dart';

import '../../application/cockpit_interactive_result_profile.dart';
import '../../application/cockpit_json_key_normalizer.dart';
import '../../application/cockpit_run_command_service.dart';
import '../cockpit_mcp_tool.dart';

typedef CockpitRunCommandToolFunction = Future<CockpitRunCommandResult>
    Function(
  CockpitRunCommandRequest request,
);

final class CockpitRunCommandTool extends CockpitMcpTool {
  CockpitRunCommandTool({
    CockpitRunCommandService? service,
    CockpitRunCommandToolFunction? runCommand,
  }) : _runCommand = runCommand ?? (service ?? CockpitRunCommandService()).run;

  final CockpitRunCommandToolFunction _runCommand;

  @override
  String get name => 'run_command';

  @override
  String get description =>
      'Execute one cockpit command against a running app and return layered interactive results.';

  @override
  Map<String, Object?> get inputSchema => const <String, Object?>{
        'type': 'object',
        'required': <String>['command'],
        'properties': <String, Object?>{
          'app_id': <String, Object?>{'type': 'string'},
          'app_json': <String, Object?>{'type': 'string'},
          'base_url': <String, Object?>{'type': 'string'},
          'command': <String, Object?>{'type': 'object'},
          'timeout_ms': <String, Object?>{'type': 'integer'},
          'profile': <String, Object?>{'type': 'string'},
          'snapshot_options': <String, Object?>{'type': 'object'},
          'compare_against_snapshot_ref': <String, Object?>{'type': 'string'},
        },
      };

  @override
  Future<Map<String, Object?>> call(Map<String, Object?> arguments) async {
    try {
      final result = await _runCommand(
        CockpitRunCommandRequest(
          appId: cockpitReadOptionalString(arguments, 'app_id'),
          appHandlePath: cockpitReadOptionalString(arguments, 'app_json'),
          baseUri: _readOptionalBaseUri(arguments),
          command: CockpitCommand.fromJson(
            cockpitNormalizeJsonKeys(
              cockpitReadRequiredObject(arguments, 'command'),
            ),
          ),
          defaultCommandTimeout: Duration(
            milliseconds:
                cockpitReadOptionalInt(arguments, 'timeout_ms') ?? 4000,
          ),
          resultProfile: _readProfile(arguments),
          snapshotOptions: _readOptionalSnapshotOptions(arguments),
          compareAgainstSnapshotRef: cockpitReadOptionalString(
            arguments,
            'compare_against_snapshot_ref',
          ),
        ),
      );
      return cockpitMcpResult(
        text: 'Command executed.',
        structuredContent: result.toJson(),
      );
    } on Object catch (error) {
      cockpitRethrowAsMcpError(error);
    }
  }

  CockpitInteractiveResultProfile _readProfile(Map<String, Object?> arguments) {
    final value = arguments['profile'] ?? arguments['result_profile'];
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

import 'package:cockpit_protocol/cockpit_protocol.dart';

import '../../application/cockpit_interactive_result_profile.dart';
import '../../application/cockpit_run_command_service.dart';
import '../cockpit_mcp_tool.dart';

typedef CockpitRunCommandToolFunction =
    Future<CockpitRunCommandResult> Function(CockpitRunCommandRequest request);

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
      'appId': <String, Object?>{'type': 'string'},
      'appJson': <String, Object?>{'type': 'string'},
      'baseUrl': <String, Object?>{'type': 'string'},
      'androidDeviceId': <String, Object?>{'type': 'string'},
      'iosDeviceId': <String, Object?>{'type': 'string'},
      'command': <String, Object?>{'type': 'object'},
      'timeoutMs': <String, Object?>{'type': 'integer'},
      'profile': <String, Object?>{'type': 'string'},
      'snapshotOptions': <String, Object?>{'type': 'object'},
      'compareAgainstSnapshotRef': <String, Object?>{'type': 'string'},
    },
  };

  @override
  Future<Map<String, Object?>> call(Map<String, Object?> arguments) async {
    try {
      final result = await _runCommand(
        CockpitRunCommandRequest(
          appId: cockpitReadOptionalString(arguments, 'appId'),
          appHandlePath: cockpitReadOptionalString(arguments, 'appJson'),
          baseUri: _readOptionalBaseUri(arguments),
          androidDeviceId: cockpitReadOptionalString(
            arguments,
            'androidDeviceId',
          ),
          iosDeviceId: cockpitReadOptionalString(arguments, 'iosDeviceId'),
          command: CockpitCommand.fromJson(
            cockpitReadRequiredObject(arguments, 'command'),
          ),
          defaultCommandTimeout: Duration(
            milliseconds:
                cockpitReadOptionalPositiveInt(arguments, 'timeoutMs') ?? 30000,
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
        text: 'Command executed.',
        structuredContent: result.toJson(),
      );
    } on Object catch (error) {
      cockpitRethrowAsMcpError(error);
    }
  }

  CockpitInteractiveResultProfile _readProfile(Map<String, Object?> arguments) {
    final value = arguments['profile'];
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

  Uri? _readOptionalBaseUri(Map<String, Object?> arguments) {
    final baseUrl = cockpitReadOptionalString(arguments, 'baseUrl');
    if (baseUrl == null || baseUrl.isEmpty) {
      return null;
    }
    return Uri.parse(baseUrl);
  }
}

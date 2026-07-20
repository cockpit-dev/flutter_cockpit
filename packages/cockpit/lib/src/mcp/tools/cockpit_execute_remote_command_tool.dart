import 'package:cockpit_protocol/cockpit_protocol.dart';

import '../../application/cockpit_execute_remote_command_service.dart';
import '../../application/cockpit_interactive_result_profile.dart';
import '../cockpit_mcp_tool.dart';

typedef CockpitExecuteRemoteCommandToolFunction =
    Future<CockpitExecuteRemoteCommandResult> Function(
      CockpitExecuteRemoteCommandRequest request,
    );

final class CockpitExecuteRemoteCommandTool extends CockpitMcpTool {
  CockpitExecuteRemoteCommandTool({
    CockpitExecuteRemoteCommandService? service,
    CockpitExecuteRemoteCommandToolFunction? execute,
  }) : _execute =
           execute ?? (service ?? CockpitExecuteRemoteCommandService()).execute;

  final CockpitExecuteRemoteCommandToolFunction _execute;

  @override
  String get name => 'execute_remote_command';

  @override
  String get description =>
      'Execute one flutter_cockpit command against a live remote session and return layered interactive results.';

  @override
  CockpitMcpToolAnnotations get annotations => const CockpitMcpToolAnnotations(
    readOnly: false,
    destructive: false,
    idempotent: false,
    longRunning: false,
    requiresSession: true,
    producesBundleEvidence: false,
  );

  @override
  List<CockpitMcpFeatureCategory> get categories =>
      const <CockpitMcpFeatureCategory>[
        CockpitMcpFeatureCategory.execution,
        CockpitMcpFeatureCategory.inspection,
      ];

  @override
  Map<String, Object?> get inputSchema => const <String, Object?>{
    'type': 'object',
    'required': <String>['command'],
    'properties': <String, Object?>{
      'sessionHandle': <String, Object?>{'type': 'object'},
      'sessionHandlePath': <String, Object?>{'type': 'string'},
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
      final result = await _execute(
        CockpitExecuteRemoteCommandRequest(
          sessionHandle: cockpitReadOptionalSessionHandle(arguments),
          sessionHandlePath: cockpitReadOptionalString(
            arguments,
            'sessionHandlePath',
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
        text: 'Remote command executed.',
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
}

import 'package:flutter_cockpit/flutter_cockpit.dart';

import '../../application/cockpit_execute_remote_command_service.dart';
import '../../application/cockpit_interactive_result_profile.dart';
import '../cockpit_mcp_tool.dart';

typedef CockpitExecuteRemoteCommandToolFunction
    = Future<CockpitExecuteRemoteCommandResult> Function(
  CockpitExecuteRemoteCommandRequest request,
);

final class CockpitExecuteRemoteCommandTool extends CockpitMcpTool {
  CockpitExecuteRemoteCommandTool({
    CockpitExecuteRemoteCommandService? service,
    CockpitExecuteRemoteCommandToolFunction? execute,
  }) : _execute = execute ??
            (service ?? CockpitExecuteRemoteCommandService()).execute;

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
          'session_handle': <String, Object?>{'type': 'object'},
          'session_handle_path': <String, Object?>{'type': 'string'},
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
      final result = await _execute(
        CockpitExecuteRemoteCommandRequest(
          sessionHandle: cockpitReadOptionalSessionHandle(arguments),
          sessionHandlePath: cockpitReadOptionalString(
            arguments,
            'session_handle_path',
          ),
          command: CockpitCommand.fromJson(
            cockpitReadRequiredObject(arguments, 'command'),
          ),
          defaultCommandTimeout: Duration(
            milliseconds:
                cockpitReadOptionalInt(arguments, 'timeout_ms') ?? 4000,
          ),
          resultProfile: _readProfile(
              arguments, 'profile', 'result_profile', 'resultProfile'),
          snapshotOptions: _readOptionalSnapshotOptions(
            arguments,
            'snapshot_options',
            'snapshotOptions',
          ),
          compareAgainstSnapshotRef: cockpitReadOptionalString(
                arguments,
                'compare_against_snapshot_ref',
              ) ??
              cockpitReadOptionalString(arguments, 'compareAgainstSnapshotRef'),
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

  CockpitInteractiveResultProfile _readProfile(
    Map<String, Object?> arguments,
    String canonicalKey,
    String legacySnakeCaseKey,
    String legacyCamelCaseKey,
  ) {
    final value = arguments[canonicalKey] ??
        arguments[legacySnakeCaseKey] ??
        arguments[legacyCamelCaseKey];
    if (value == null) {
      return const CockpitInteractiveResultProfile.standard();
    }
    return CockpitInteractiveResultProfile.preset(
      CockpitInteractiveResultProfileName.fromJson(value),
    );
  }

  CockpitSnapshotOptions? _readOptionalSnapshotOptions(
    Map<String, Object?> arguments,
    String snakeCaseKey,
    String camelCaseKey,
  ) {
    final json = arguments.containsKey(snakeCaseKey)
        ? cockpitReadOptionalObject(arguments, snakeCaseKey)
        : cockpitReadOptionalObject(arguments, camelCaseKey);
    if (json == null) {
      return null;
    }
    return CockpitSnapshotOptions.fromJson(json);
  }
}

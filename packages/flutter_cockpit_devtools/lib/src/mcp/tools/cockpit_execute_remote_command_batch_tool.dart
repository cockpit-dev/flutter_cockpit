import 'package:flutter_cockpit/flutter_cockpit.dart';

import '../../application/cockpit_execute_remote_command_batch_service.dart';
import '../../application/cockpit_interactive_result_profile.dart';
import '../cockpit_mcp_tool.dart';

typedef CockpitExecuteRemoteCommandBatchToolFunction
    = Future<CockpitExecuteRemoteCommandBatchResult> Function(
  CockpitExecuteRemoteCommandBatchRequest request,
);

final class CockpitExecuteRemoteCommandBatchTool extends CockpitMcpTool {
  CockpitExecuteRemoteCommandBatchTool({
    CockpitExecuteRemoteCommandBatchService? service,
    CockpitExecuteRemoteCommandBatchToolFunction? execute,
  }) : _execute = execute ??
            (service ?? CockpitExecuteRemoteCommandBatchService()).execute;

  final CockpitExecuteRemoteCommandBatchToolFunction _execute;

  @override
  String get name => 'execute_remote_command_batch';

  @override
  String get description =>
      'Execute multiple flutter_cockpit commands in order against a live remote session.';

  @override
  CockpitMcpToolAnnotations get annotations => const CockpitMcpToolAnnotations(
        readOnly: false,
        destructive: false,
        idempotent: false,
        longRunning: true,
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
        'required': <String>['commands'],
        'properties': <String, Object?>{
          'session_handle': <String, Object?>{'type': 'object'},
          'session_handle_path': <String, Object?>{'type': 'string'},
          'commands': <String, Object?>{'type': 'array'},
          'default_timeout_ms': <String, Object?>{'type': 'integer'},
          'default_profile': <String, Object?>{'type': 'string'},
          'fail_fast': <String, Object?>{'type': 'boolean'},
          'recording': <String, Object?>{'type': 'object'},
          'final_profile': <String, Object?>{'type': 'string'},
          'final_snapshot_options': <String, Object?>{'type': 'object'},
        },
      };

  @override
  Future<Map<String, Object?>> call(Map<String, Object?> arguments) async {
    try {
      final result = await _execute(
        CockpitExecuteRemoteCommandBatchRequest(
          sessionHandle: cockpitReadOptionalSessionHandle(arguments),
          sessionHandlePath: cockpitReadOptionalString(
            arguments,
            'session_handle_path',
          ),
          commands: cockpitReadRequiredObjectList(arguments, 'commands')
              .map(_readBatchCommand)
              .toList(growable: false),
          defaultResultProfile: (_readOptionalProfile(
                    arguments,
                    'default_profile',
                  ) ??
                  _readOptionalProfile(arguments, 'default_result_profile')) ??
              const CockpitInteractiveResultProfile.standard(),
          defaultCommandTimeout: Duration(
            milliseconds:
                cockpitReadOptionalInt(arguments, 'default_timeout_ms') ?? 4000,
          ),
          failFast: cockpitReadOptionalBool(arguments, 'fail_fast') ??
              cockpitReadOptionalBool(arguments, 'failFast') ??
              true,
          recording: _readOptionalRecording(arguments),
          finalSnapshotProfile:
              _readOptionalProfile(arguments, 'final_profile') ??
                  _readOptionalProfile(arguments, 'final_snapshot_profile') ??
                  _readOptionalProfile(arguments, 'finalSnapshotProfile'),
          finalSnapshotOptions: _readOptionalSnapshotOptions(
            arguments,
            'final_snapshot_options',
            'finalSnapshotOptions',
          ),
        ),
      );
      return cockpitMcpResult(
        text: 'Remote command batch executed.',
        structuredContent: result.toJson(),
      );
    } on Object catch (error) {
      cockpitRethrowAsMcpError(error);
    }
  }

  CockpitInteractiveBatchCommand _readBatchCommand(Map<String, Object?> json) {
    final commandJson = json['command'];
    final normalized = commandJson is Map<Object?, Object?>
        ? Map<String, Object?>.from(commandJson)
        : json;
    final snapshotOptionsJson =
        json['snapshot_options'] ?? json['snapshotOptions'];
    return CockpitInteractiveBatchCommand(
      command: CockpitCommand.fromJson(normalized),
      resultProfile: _readOptionalProfileFromValue(
        json['profile'] ?? json['result_profile'] ?? json['resultProfile'],
      ),
      snapshotOptions: snapshotOptionsJson is Map<Object?, Object?>
          ? CockpitSnapshotOptions.fromJson(
              Map<String, Object?>.from(snapshotOptionsJson),
            )
          : null,
      compareAgainstSnapshotRef:
          json['compare_against_snapshot_ref'] as String? ??
              json['compareAgainstSnapshotRef'] as String?,
    );
  }

  CockpitInteractiveResultProfile? _readOptionalProfile(
    Map<String, Object?> arguments,
    String key,
  ) {
    final value = arguments[key];
    return _readOptionalProfileFromValue(value);
  }

  CockpitInteractiveResultProfile? _readOptionalProfileFromValue(
      Object? value) {
    if (value == null) {
      return null;
    }
    return CockpitInteractiveResultProfile.preset(
      CockpitInteractiveResultProfileName.fromJson(value),
    );
  }

  CockpitRecordingRequest? _readOptionalRecording(
    Map<String, Object?> arguments,
  ) {
    final recordingJson = cockpitReadOptionalObject(arguments, 'recording');
    if (recordingJson == null) {
      return null;
    }
    return CockpitRecordingRequest.fromJson(recordingJson);
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

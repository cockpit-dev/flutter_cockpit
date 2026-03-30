import 'package:flutter_cockpit/flutter_cockpit.dart';

import '../../application/cockpit_interactive_result_profile.dart';
import '../../application/cockpit_json_key_normalizer.dart';
import '../../application/cockpit_run_batch_service.dart';
import '../cockpit_mcp_tool.dart';

typedef CockpitRunBatchToolFunction = Future<CockpitRunBatchResult> Function(
  CockpitRunBatchRequest request,
);

final class CockpitRunBatchTool extends CockpitMcpTool {
  CockpitRunBatchTool({
    CockpitRunBatchService? service,
    CockpitRunBatchToolFunction? runBatch,
  }) : _runBatch = runBatch ?? (service ?? CockpitRunBatchService()).run;

  final CockpitRunBatchToolFunction _runBatch;

  @override
  String get name => 'run_batch';

  @override
  String get description =>
      'Execute multiple cockpit commands in order against a running app.';

  @override
  Map<String, Object?> get inputSchema => const <String, Object?>{
        'type': 'object',
        'required': <String>['commands'],
        'properties': <String, Object?>{
          'app_id': <String, Object?>{'type': 'string'},
          'app_json': <String, Object?>{'type': 'string'},
          'base_url': <String, Object?>{'type': 'string'},
          'commands': <String, Object?>{'type': 'array'},
          'default_result_profile': <String, Object?>{'type': 'string'},
          'fail_fast': <String, Object?>{'type': 'boolean'},
          'recording': <String, Object?>{'type': 'object'},
          'final_snapshot_profile': <String, Object?>{'type': 'string'},
          'final_snapshot_options': <String, Object?>{'type': 'object'},
        },
      };

  @override
  Future<Map<String, Object?>> call(Map<String, Object?> arguments) async {
    try {
      final result = await _runBatch(
        CockpitRunBatchRequest(
          appId: cockpitReadOptionalString(arguments, 'app_id'),
          appHandlePath: cockpitReadOptionalString(arguments, 'app_json'),
          baseUri: _readOptionalBaseUri(arguments),
          commands: cockpitReadRequiredObjectList(arguments, 'commands')
              .map(_readBatchCommand)
              .toList(growable: false),
          defaultResultProfile:
              _readOptionalProfile(arguments, 'default_result_profile') ??
                  const CockpitInteractiveResultProfile.standard(),
          failFast: cockpitReadOptionalBool(arguments, 'fail_fast') ?? true,
          recording: _readOptionalRecording(arguments),
          finalSnapshotProfile: _readOptionalProfile(
            arguments,
            'final_snapshot_profile',
          ),
          finalSnapshotOptions: _readOptionalSnapshotOptions(arguments),
        ),
      );
      return cockpitMcpResult(
        text: 'Command batch executed.',
        structuredContent: result.toJson(),
      );
    } on Object catch (error) {
      cockpitRethrowAsMcpError(error);
    }
  }

  CockpitRunBatchCommand _readBatchCommand(Map<String, Object?> json) {
    final normalizedJson = cockpitNormalizeJsonKeys(json);
    final commandJson = normalizedJson['command'];
    final normalized = commandJson is Map<Object?, Object?>
        ? Map<String, Object?>.from(commandJson)
        : normalizedJson;
    final snapshotOptionsJson = normalizedJson['snapshotOptions'];
    return CockpitRunBatchCommand(
      command: CockpitCommand.fromJson(normalized),
      resultProfile: _readOptionalProfileFromValue(
        normalizedJson['resultProfile'],
      ),
      snapshotOptions: snapshotOptionsJson is Map<Object?, Object?>
          ? CockpitSnapshotOptions.fromJson(
              cockpitNormalizeJsonKeys(
                Map<String, Object?>.from(snapshotOptionsJson),
              ),
            )
          : null,
      compareAgainstSnapshotRef:
          normalizedJson['compareAgainstSnapshotRef'] as String?,
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
    return CockpitRecordingRequest.fromJson(
      cockpitNormalizeJsonKeys(recordingJson),
    );
  }

  CockpitSnapshotOptions? _readOptionalSnapshotOptions(
    Map<String, Object?> arguments,
  ) {
    final json = cockpitReadOptionalObject(arguments, 'final_snapshot_options');
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

import 'package:cockpit_protocol/cockpit_protocol.dart';

import '../../application/cockpit_interactive_result_profile.dart';
import '../../application/cockpit_run_batch_service.dart';
import '../cockpit_mcp_tool.dart';

typedef CockpitRunBatchToolFunction =
    Future<CockpitRunBatchResult> Function(CockpitRunBatchRequest request);

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
      'appId': <String, Object?>{'type': 'string'},
      'appJson': <String, Object?>{'type': 'string'},
      'baseUrl': <String, Object?>{'type': 'string'},
      'androidDeviceId': <String, Object?>{'type': 'string'},
      'iosDeviceId': <String, Object?>{'type': 'string'},
      'commands': <String, Object?>{'type': 'array'},
      'defaultTimeoutMs': <String, Object?>{'type': 'integer'},
      'defaultProfile': <String, Object?>{'type': 'string'},
      'failFast': <String, Object?>{'type': 'boolean'},
      'recording': <String, Object?>{'type': 'object'},
      'finalProfile': <String, Object?>{'type': 'string'},
      'finalSnapshotOptions': <String, Object?>{'type': 'object'},
    },
  };

  @override
  Future<Map<String, Object?>> call(Map<String, Object?> arguments) async {
    try {
      final result = await _runBatch(
        CockpitRunBatchRequest(
          appId: cockpitReadOptionalString(arguments, 'appId'),
          appHandlePath: cockpitReadOptionalString(arguments, 'appJson'),
          baseUri: _readOptionalBaseUri(arguments),
          androidDeviceId: cockpitReadOptionalString(
            arguments,
            'androidDeviceId',
          ),
          iosDeviceId: cockpitReadOptionalString(arguments, 'iosDeviceId'),
          commands: cockpitReadRequiredObjectList(
            arguments,
            'commands',
          ).map(_readBatchCommand).toList(growable: false),
          defaultResultProfile:
              _readOptionalProfile(arguments, 'defaultProfile') ??
              const CockpitInteractiveResultProfile.standard(),
          defaultCommandTimeout: Duration(
            milliseconds:
                cockpitReadOptionalPositiveInt(arguments, 'defaultTimeoutMs') ??
                30000,
          ),
          failFast: cockpitReadOptionalBool(arguments, 'failFast') ?? true,
          recording: _readOptionalRecording(arguments),
          finalSnapshotProfile: _readOptionalProfile(arguments, 'finalProfile'),
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
    final commandJson = json['command'];
    final normalized = commandJson is Map<Object?, Object?>
        ? Map<String, Object?>.from(commandJson)
        : json;
    final snapshotOptionsJson = json['snapshotOptions'];
    return CockpitRunBatchCommand(
      command: CockpitCommand.fromJson(normalized),
      resultProfile: _readOptionalProfileFromValue(json['profile']),
      snapshotOptions: snapshotOptionsJson is Map<Object?, Object?>
          ? CockpitSnapshotOptions.fromJson(
              Map<String, Object?>.from(snapshotOptionsJson),
            )
          : null,
      compareAgainstSnapshotRef: json['compareAgainstSnapshotRef'] as String?,
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
    Object? value,
  ) {
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
  ) {
    final json = cockpitReadOptionalObject(arguments, 'finalSnapshotOptions');
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

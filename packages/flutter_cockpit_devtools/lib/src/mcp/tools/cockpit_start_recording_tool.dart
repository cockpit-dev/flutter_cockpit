import 'package:flutter_cockpit/flutter_cockpit.dart';

import '../../application/cockpit_json_key_normalizer.dart';
import '../../application/cockpit_start_recording_service.dart';
import '../cockpit_mcp_tool.dart';

typedef CockpitStartRecordingToolFunction = Future<CockpitStartRecordingResult>
    Function(
  CockpitStartRecordingRequest request,
);

final class CockpitStartRecordingTool extends CockpitMcpTool {
  CockpitStartRecordingTool({
    CockpitStartRecordingService? service,
    CockpitStartRecordingToolFunction? start,
  }) : _start = start ?? (service ?? CockpitStartRecordingService()).start;

  final CockpitStartRecordingToolFunction _start;

  @override
  String get name => 'start_recording';

  @override
  String get description =>
      'Start an on-demand recording session for a running app.';

  @override
  Map<String, Object?> get inputSchema => const <String, Object?>{
        'type': 'object',
        'required': <String>['recording'],
        'properties': <String, Object?>{
          'appId': <String, Object?>{'type': 'string'},
          'appJson': <String, Object?>{'type': 'string'},
          'baseUrl': <String, Object?>{'type': 'string'},
          'recording': <String, Object?>{'type': 'object'},
        },
      };

  @override
  Future<Map<String, Object?>> call(Map<String, Object?> arguments) async {
    try {
      final result = await _start(
        CockpitStartRecordingRequest(
          appId: cockpitReadOptionalString(arguments, 'app_id'),
          appHandlePath: cockpitReadOptionalString(arguments, 'app_json'),
          baseUri: _readOptionalBaseUri(arguments),
          recording: CockpitRecordingRequest.fromJson(
            cockpitNormalizeJsonKeys(
              cockpitReadRequiredObject(arguments, 'recording'),
            ),
          ),
        ),
      );
      return cockpitMcpResult(
        text: 'Recording started.',
        structuredContent: result.toJson(),
      );
    } on Object catch (error) {
      cockpitRethrowAsMcpError(error);
    }
  }

  Uri? _readOptionalBaseUri(Map<String, Object?> arguments) {
    final baseUrl = cockpitReadOptionalString(arguments, 'base_url');
    if (baseUrl == null || baseUrl.isEmpty) {
      return null;
    }
    return Uri.parse(baseUrl);
  }
}

import '../../application/cockpit_stop_recording_service.dart';
import '../cockpit_mcp_tool.dart';

typedef CockpitStopRecordingToolFunction = Future<CockpitStopRecordingResult>
    Function(
  CockpitStopRecordingRequest request,
);

final class CockpitStopRecordingTool extends CockpitMcpTool {
  CockpitStopRecordingTool({
    CockpitStopRecordingService? service,
    CockpitStopRecordingToolFunction? stop,
  }) : _stop = stop ?? (service ?? CockpitStopRecordingService()).stop;

  final CockpitStopRecordingToolFunction _stop;

  @override
  String get name => 'stop_recording';

  @override
  String get description => 'Stop the active recording for a running app.';

  @override
  Map<String, Object?> get inputSchema => const <String, Object?>{
        'type': 'object',
        'properties': <String, Object?>{
          'app_id': <String, Object?>{'type': 'string'},
          'app_json': <String, Object?>{'type': 'string'},
          'base_url': <String, Object?>{'type': 'string'},
        },
      };

  @override
  Future<Map<String, Object?>> call(Map<String, Object?> arguments) async {
    try {
      final result = await _stop(
        CockpitStopRecordingRequest(
          appId: cockpitReadOptionalString(arguments, 'app_id'),
          appHandlePath: cockpitReadOptionalString(arguments, 'app_json'),
          baseUri: _readOptionalBaseUri(arguments),
        ),
      );
      return cockpitMcpResult(
        text: 'Recording stopped.',
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

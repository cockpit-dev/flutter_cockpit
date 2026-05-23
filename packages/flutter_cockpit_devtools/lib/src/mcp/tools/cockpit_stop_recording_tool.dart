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
          'appId': <String, Object?>{'type': 'string'},
          'appJson': <String, Object?>{'type': 'string'},
          'baseUrl': <String, Object?>{'type': 'string'},
          'androidDeviceId': <String, Object?>{'type': 'string'},
          'iosDeviceId': <String, Object?>{'type': 'string'},
        },
      };

  @override
  Future<Map<String, Object?>> call(Map<String, Object?> arguments) async {
    try {
      final result = await _stop(
        CockpitStopRecordingRequest(
          appId: cockpitReadOptionalString(arguments, 'appId'),
          appHandlePath: cockpitReadOptionalString(arguments, 'appJson'),
          baseUri: _readOptionalBaseUri(arguments),
          androidDeviceId: cockpitReadOptionalString(
            arguments,
            'androidDeviceId',
          ),
          iosDeviceId: cockpitReadOptionalString(arguments, 'iosDeviceId'),
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
    final baseUrl = cockpitReadOptionalString(arguments, 'baseUrl');
    if (baseUrl == null || baseUrl.isEmpty) {
      return null;
    }
    return Uri.parse(baseUrl);
  }
}

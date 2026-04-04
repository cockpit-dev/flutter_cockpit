import '../../application/cockpit_stop_remote_recording_service.dart';
import '../cockpit_mcp_tool.dart';

typedef CockpitStopRemoteRecordingToolFunction
    = Future<CockpitStopRemoteRecordingResult> Function(
  CockpitStopRemoteRecordingRequest request,
);

final class CockpitStopRemoteRecordingTool extends CockpitMcpTool {
  CockpitStopRemoteRecordingTool({
    CockpitStopRemoteRecordingService? service,
    CockpitStopRemoteRecordingToolFunction? stop,
  }) : _stop = stop ?? (service ?? CockpitStopRemoteRecordingService()).stop;

  final CockpitStopRemoteRecordingToolFunction _stop;

  @override
  String get name => 'stop_remote_recording';

  @override
  String get description =>
      'Stop the active on-demand remote recording session and return artifact metadata.';

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
      ];

  @override
  Map<String, Object?> get inputSchema => const <String, Object?>{
        'type': 'object',
        'properties': <String, Object?>{
          'sessionHandle': <String, Object?>{'type': 'object'},
          'sessionHandlePath': <String, Object?>{'type': 'string'},
        },
      };

  @override
  Future<Map<String, Object?>> call(Map<String, Object?> arguments) async {
    try {
      final result = await _stop(
        CockpitStopRemoteRecordingRequest(
          sessionHandle: cockpitReadOptionalSessionHandle(arguments),
          sessionHandlePath: cockpitReadOptionalString(
            arguments,
            'session_handle_path',
          ),
        ),
      );
      return cockpitMcpResult(
        text: 'Remote recording stopped.',
        structuredContent: result.toJson(),
      );
    } on Object catch (error) {
      cockpitRethrowAsMcpError(error);
    }
  }
}

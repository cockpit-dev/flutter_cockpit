import 'package:flutter_cockpit_protocol/flutter_cockpit_protocol.dart';

import '../../application/cockpit_start_remote_recording_service.dart';
import '../cockpit_mcp_tool.dart';

typedef CockpitStartRemoteRecordingToolFunction =
    Future<CockpitStartRemoteRecordingResult> Function(
      CockpitStartRemoteRecordingRequest request,
    );

final class CockpitStartRemoteRecordingTool extends CockpitMcpTool {
  CockpitStartRemoteRecordingTool({
    CockpitStartRemoteRecordingService? service,
    CockpitStartRemoteRecordingToolFunction? start,
  }) : _start =
           start ?? (service ?? CockpitStartRemoteRecordingService()).start;

  final CockpitStartRemoteRecordingToolFunction _start;

  @override
  String get name => 'start_remote_recording';

  @override
  String get description =>
      'Start an on-demand remote recording session for interactive debugging.';

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
      const <CockpitMcpFeatureCategory>[CockpitMcpFeatureCategory.execution];

  @override
  Map<String, Object?> get inputSchema => const <String, Object?>{
    'type': 'object',
    'required': <String>['recording'],
    'properties': <String, Object?>{
      'sessionHandle': <String, Object?>{'type': 'object'},
      'sessionHandlePath': <String, Object?>{'type': 'string'},
      'iosDeviceId': <String, Object?>{'type': 'string'},
      'recording': <String, Object?>{'type': 'object'},
    },
  };

  @override
  Future<Map<String, Object?>> call(Map<String, Object?> arguments) async {
    try {
      final result = await _start(
        CockpitStartRemoteRecordingRequest(
          sessionHandle: cockpitReadOptionalSessionHandle(arguments),
          sessionHandlePath: cockpitReadOptionalString(
            arguments,
            'sessionHandlePath',
          ),
          iosDeviceId: cockpitReadOptionalString(arguments, 'iosDeviceId'),
          recording: CockpitRecordingRequest.fromJson(
            cockpitReadRequiredObject(arguments, 'recording'),
          ),
        ),
      );
      return cockpitMcpResult(
        text: 'Remote recording started.',
        structuredContent: result.toJson(),
      );
    } on Object catch (error) {
      cockpitRethrowAsMcpError(error);
    }
  }
}

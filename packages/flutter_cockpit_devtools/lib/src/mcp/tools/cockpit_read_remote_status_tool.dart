import '../../application/cockpit_interactive_result_profile.dart';
import '../../application/cockpit_read_remote_status_service.dart';
import '../cockpit_mcp_tool.dart';

typedef CockpitReadRemoteStatusToolFunction
    = Future<CockpitReadRemoteStatusResult> Function(
  CockpitReadRemoteStatusRequest request,
);

final class CockpitReadRemoteStatusTool extends CockpitMcpTool {
  CockpitReadRemoteStatusTool({
    CockpitReadRemoteStatusService? service,
    CockpitReadRemoteStatusToolFunction? read,
  }) : _read = read ?? (service ?? CockpitReadRemoteStatusService()).read;

  final CockpitReadRemoteStatusToolFunction _read;

  @override
  String get name => 'read_remote_status';

  @override
  String get description =>
      'Read lightweight remote session status with optional richer snapshot layering.';

  @override
  CockpitMcpToolAnnotations get annotations => const CockpitMcpToolAnnotations(
        readOnly: true,
        destructive: false,
        idempotent: true,
        longRunning: false,
        requiresSession: true,
        producesBundleEvidence: false,
      );

  @override
  List<CockpitMcpFeatureCategory> get categories =>
      const <CockpitMcpFeatureCategory>[
        CockpitMcpFeatureCategory.sessionManagement,
        CockpitMcpFeatureCategory.inspection,
      ];

  @override
  Map<String, Object?> get inputSchema => const <String, Object?>{
        'type': 'object',
        'properties': <String, Object?>{
          'session_handle': <String, Object?>{'type': 'object'},
          'session_handle_path': <String, Object?>{'type': 'string'},
          'result_profile': <String, Object?>{'type': 'string'},
        },
      };

  @override
  Future<Map<String, Object?>> call(Map<String, Object?> arguments) async {
    try {
      final result = await _read(
        CockpitReadRemoteStatusRequest(
          sessionHandle: cockpitReadOptionalSessionHandle(arguments),
          sessionHandlePath: cockpitReadOptionalString(
            arguments,
            'session_handle_path',
          ),
          resultProfile: _readProfile(arguments),
        ),
      );
      return cockpitMcpResult(
        text: 'Remote session status loaded.',
        structuredContent: result.toJson(),
      );
    } on Object catch (error) {
      cockpitRethrowAsMcpError(error);
    }
  }

  CockpitInteractiveResultProfile _readProfile(Map<String, Object?> arguments) {
    final value = arguments['result_profile'] ?? arguments['resultProfile'];
    if (value == null) {
      return const CockpitInteractiveResultProfile.minimal();
    }
    return CockpitInteractiveResultProfile.preset(
      CockpitInteractiveResultProfileName.fromJson(value),
    );
  }
}

import '../../application/cockpit_read_runtime_errors_service.dart';
import '../cockpit_mcp_tool.dart';

typedef CockpitReadRuntimeErrorsToolFunction = CockpitReadRuntimeErrorsResult
    Function(
  CockpitReadRuntimeErrorsRequest request,
);

final class CockpitReadRuntimeErrorsTool extends CockpitMcpTool {
  CockpitReadRuntimeErrorsTool({
    required CockpitReadRuntimeErrorsService service,
    CockpitReadRuntimeErrorsToolFunction? read,
  }) : _read = read ?? service.read;

  final CockpitReadRuntimeErrorsToolFunction _read;

  @override
  String get name => 'read_runtime_errors';

  @override
  String get description =>
      'Read the current runtime errors known from active development sessions and the latest recorded task bundle.';

  @override
  CockpitMcpToolAnnotations get annotations => const CockpitMcpToolAnnotations(
        readOnly: true,
        destructive: false,
        idempotent: true,
        longRunning: false,
        requiresSession: false,
        producesBundleEvidence: false,
      );

  @override
  List<CockpitMcpFeatureCategory> get categories =>
      const <CockpitMcpFeatureCategory>[
        CockpitMcpFeatureCategory.closedLoop,
        CockpitMcpFeatureCategory.inspection,
        CockpitMcpFeatureCategory.delivery,
      ];

  @override
  Map<String, Object?> get inputSchema => const <String, Object?>{
        'type': 'object',
        'properties': <String, Object?>{
          'include_latest_task': <String, Object?>{'type': 'boolean'},
          'include_sessions': <String, Object?>{'type': 'boolean'},
        },
      };

  @override
  Future<Map<String, Object?>> call(Map<String, Object?> arguments) async {
    try {
      final result = _read(
        CockpitReadRuntimeErrorsRequest(
          includeLatestTask:
              cockpitReadOptionalBool(arguments, 'include_latest_task') ?? true,
          includeSessions:
              cockpitReadOptionalBool(arguments, 'include_sessions') ?? true,
        ),
      );
      return cockpitMcpResult(
        text: 'Runtime errors loaded.',
        structuredContent: result.toJson(),
      );
    } on Object catch (error) {
      cockpitRethrowAsMcpError(error);
    }
  }
}

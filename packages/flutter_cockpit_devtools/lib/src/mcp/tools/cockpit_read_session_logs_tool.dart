import '../../application/cockpit_read_session_logs_service.dart';
import '../cockpit_mcp_tool.dart';

typedef CockpitReadSessionLogsToolFunction
    = Future<CockpitReadSessionLogsResult> Function(
  CockpitReadSessionLogsRequest request,
);

final class CockpitReadSessionLogsTool extends CockpitMcpTool {
  CockpitReadSessionLogsTool({
    required CockpitReadSessionLogsService service,
    CockpitReadSessionLogsToolFunction? read,
  }) : _read = read ?? service.read;

  final CockpitReadSessionLogsToolFunction _read;

  @override
  String get name => 'read_session_logs';

  @override
  String get description =>
      'Read the tail of the registered supervisor log for a development session.';

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
        CockpitMcpFeatureCategory.closedLoop,
        CockpitMcpFeatureCategory.sessionManagement,
        CockpitMcpFeatureCategory.inspection,
      ];

  @override
  Map<String, Object?> get inputSchema => const <String, Object?>{
        'type': 'object',
        'required': <String>['development_session_id'],
        'properties': <String, Object?>{
          'development_session_id': <String, Object?>{'type': 'string'},
          'max_lines': <String, Object?>{'type': 'integer'},
        },
      };

  @override
  Future<Map<String, Object?>> call(Map<String, Object?> arguments) async {
    try {
      final result = await _read(
        CockpitReadSessionLogsRequest(
          developmentSessionId: cockpitReadRequiredString(
            arguments,
            'development_session_id',
          ),
          maxLines: cockpitReadOptionalInt(arguments, 'max_lines') ?? 200,
        ),
      );
      return cockpitMcpResult(
        text: 'Session logs loaded.',
        structuredContent: result.toJson(),
      );
    } on Object catch (error) {
      cockpitRethrowAsMcpError(error);
    }
  }
}

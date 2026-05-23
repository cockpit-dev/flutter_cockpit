import '../../application/cockpit_read_runtime_errors_service.dart';
import '../cockpit_mcp_tool.dart';

typedef CockpitReadRuntimeErrorsToolFunction
    = Future<CockpitReadRuntimeErrorsResult> Function(
  CockpitReadRuntimeErrorsRequest request,
);

final class CockpitReadRuntimeErrorsTool extends CockpitMcpTool {
  CockpitReadRuntimeErrorsTool({
    required CockpitReadRuntimeErrorsService service,
    CockpitReadRuntimeErrorsToolFunction? read,
  }) : _read = read ?? service.read;

  final CockpitReadRuntimeErrorsToolFunction _read;

  @override
  String get name => 'read_errors';

  @override
  String get description =>
      'Read current runtime errors for a running app, optionally merged with active sessions and the latest recorded task bundle.';

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
          'appId': <String, Object?>{'type': 'string'},
          'appJson': <String, Object?>{'type': 'string'},
          'baseUrl': <String, Object?>{'type': 'string'},
          'androidDeviceId': <String, Object?>{'type': 'string'},
          'maxErrors': <String, Object?>{'type': 'integer'},
          'includeLatestTask': <String, Object?>{'type': 'boolean'},
          'includeSessions': <String, Object?>{'type': 'boolean'},
        },
      };

  @override
  Future<Map<String, Object?>> call(Map<String, Object?> arguments) async {
    try {
      final hasAppReference = arguments.containsKey('appId') ||
          arguments.containsKey('appJson') ||
          arguments.containsKey('baseUrl');
      final baseUrl = cockpitReadOptionalString(arguments, 'baseUrl');
      final result = await _read(
        CockpitReadRuntimeErrorsRequest(
          appId: cockpitReadOptionalString(arguments, 'appId'),
          appHandlePath: cockpitReadOptionalString(arguments, 'appJson'),
          baseUri: baseUrl == null ? null : Uri.parse(baseUrl),
          androidDeviceId: cockpitReadOptionalString(
            arguments,
            'androidDeviceId',
          ),
          maxErrors:
              cockpitReadOptionalPositiveInt(arguments, 'maxErrors') ?? 20,
          includeLatestTask: hasAppReference &&
                  !arguments.containsKey('includeLatestTask')
              ? null
              : cockpitReadOptionalBool(arguments, 'includeLatestTask') ?? true,
          includeSessions: hasAppReference &&
                  !arguments.containsKey('includeSessions')
              ? null
              : cockpitReadOptionalBool(arguments, 'includeSessions') ?? true,
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

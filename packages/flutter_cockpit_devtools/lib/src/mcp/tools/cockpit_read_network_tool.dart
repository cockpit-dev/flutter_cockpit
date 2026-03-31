import '../../application/cockpit_read_network_service.dart';
import '../cockpit_mcp_tool.dart';

typedef CockpitReadNetworkToolFunction = Future<CockpitReadNetworkResult>
    Function(
  CockpitReadNetworkRequest request,
);

final class CockpitReadNetworkTool extends CockpitMcpTool {
  CockpitReadNetworkTool({
    required CockpitReadNetworkService service,
    CockpitReadNetworkToolFunction? read,
  }) : _read = read ?? service.read;

  final CockpitReadNetworkToolFunction _read;

  @override
  String get name => 'read_network';

  @override
  String get description =>
      'Read bounded app-centric network activity with endpoint summaries and recent failures.';

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
      ];

  @override
  Map<String, Object?> get inputSchema => const <String, Object?>{
        'type': 'object',
        'properties': <String, Object?>{
          'app_id': <String, Object?>{'type': 'string'},
          'app_json': <String, Object?>{'type': 'string'},
          'base_url': <String, Object?>{'type': 'string'},
          'android_device_id': <String, Object?>{'type': 'string'},
          'max_entries': <String, Object?>{'type': 'integer'},
          'max_endpoint_summaries': <String, Object?>{'type': 'integer'},
          'include_entries': <String, Object?>{'type': 'boolean'},
          'method': <String, Object?>{'type': 'string'},
          'uri_contains': <String, Object?>{'type': 'string'},
          'status_code_at_least': <String, Object?>{'type': 'integer'},
          'only_failures': <String, Object?>{'type': 'boolean'},
        },
      };

  @override
  Future<Map<String, Object?>> call(Map<String, Object?> arguments) async {
    try {
      final result = await _read(
        CockpitReadNetworkRequest(
          appId: cockpitReadOptionalString(arguments, 'app_id'),
          appHandlePath: cockpitReadOptionalString(arguments, 'app_json'),
          baseUri: _readOptionalBaseUri(arguments),
          androidDeviceId: cockpitReadOptionalString(
            arguments,
            'android_device_id',
          ),
          maxEntries: cockpitReadOptionalInt(arguments, 'max_entries') ?? 8,
          maxEndpointSummaries:
              cockpitReadOptionalInt(arguments, 'max_endpoint_summaries') ?? 8,
          includeEntries:
              cockpitReadOptionalBool(arguments, 'include_entries') ?? false,
          method: cockpitReadOptionalString(arguments, 'method'),
          uriContains: cockpitReadOptionalString(arguments, 'uri_contains'),
          statusCodeAtLeast:
              cockpitReadOptionalInt(arguments, 'status_code_at_least'),
          onlyFailures:
              cockpitReadOptionalBool(arguments, 'only_failures') ?? false,
        ),
      );
      return cockpitMcpResult(
        text: 'Network activity loaded.',
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

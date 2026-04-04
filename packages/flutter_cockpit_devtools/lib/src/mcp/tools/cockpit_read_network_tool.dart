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
          'appId': <String, Object?>{'type': 'string'},
          'appJson': <String, Object?>{'type': 'string'},
          'baseUrl': <String, Object?>{'type': 'string'},
          'androidDeviceId': <String, Object?>{'type': 'string'},
          'maxEntries': <String, Object?>{'type': 'integer'},
          'maxEndpointSummaries': <String, Object?>{'type': 'integer'},
          'includeEntries': <String, Object?>{'type': 'boolean'},
          'method': <String, Object?>{'type': 'string'},
          'uriContains': <String, Object?>{'type': 'string'},
          'statusCodeAtLeast': <String, Object?>{'type': 'integer'},
          'onlyFailures': <String, Object?>{'type': 'boolean'},
        },
      };

  @override
  Future<Map<String, Object?>> call(Map<String, Object?> arguments) async {
    try {
      final result = await _read(
        CockpitReadNetworkRequest(
          appId: cockpitReadOptionalString(arguments, 'appId'),
          appHandlePath: cockpitReadOptionalString(arguments, 'appJson'),
          baseUri: _readOptionalBaseUri(arguments),
          androidDeviceId: cockpitReadOptionalString(
            arguments,
            'androidDeviceId',
          ),
          maxEntries: cockpitReadOptionalInt(arguments, 'maxEntries') ?? 8,
          maxEndpointSummaries:
              cockpitReadOptionalInt(arguments, 'maxEndpointSummaries') ?? 8,
          includeEntries:
              cockpitReadOptionalBool(arguments, 'includeEntries') ?? false,
          method: cockpitReadOptionalString(arguments, 'method'),
          uriContains: cockpitReadOptionalString(arguments, 'uriContains'),
          statusCodeAtLeast: cockpitReadOptionalInt(
            arguments,
            'statusCodeAtLeast',
          ),
          onlyFailures:
              cockpitReadOptionalBool(arguments, 'onlyFailures') ?? false,
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
    final baseUrl = cockpitReadOptionalString(arguments, 'baseUrl');
    if (baseUrl == null || baseUrl.isEmpty) {
      return null;
    }
    return Uri.parse(baseUrl);
  }
}

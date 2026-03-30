import '../../application/cockpit_pub_dev_search_service.dart';
import '../cockpit_mcp_tool.dart';

typedef CockpitPubDevSearchToolFunction = Future<CockpitPubDevSearchResult>
    Function(CockpitPubDevSearchRequest request);

final class CockpitPubDevSearchTool extends CockpitMcpTool {
  CockpitPubDevSearchTool({
    CockpitPubDevSearchService? service,
    CockpitPubDevSearchToolFunction? search,
  }) : _search = search ?? (service ?? CockpitPubDevSearchService()).search;

  final CockpitPubDevSearchToolFunction _search;

  @override
  String get name => 'pub_dev_search';

  @override
  String get description =>
      'Search pub.dev for packages and return bounded package quality summaries.';

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
        CockpitMcpFeatureCategory.workspace,
        CockpitMcpFeatureCategory.dependencyIntelligence,
      ];

  @override
  Map<String, Object?> get inputSchema => const <String, Object?>{
        'type': 'object',
        'required': <String>['query'],
        'properties': <String, Object?>{
          'query': <String, Object?>{'type': 'string'},
          'max_results': <String, Object?>{'type': 'integer'},
        },
      };

  @override
  Future<Map<String, Object?>> call(Map<String, Object?> arguments) async {
    try {
      final result = await _search(
        CockpitPubDevSearchRequest(
          query: cockpitReadRequiredString(arguments, 'query'),
          maxResults: cockpitReadOptionalInt(arguments, 'max_results') ?? 5,
        ),
      );
      return cockpitMcpResult(
        text: 'pub.dev search completed.',
        structuredContent: result.toJson(),
      );
    } on Object catch (error) {
      cockpitRethrowAsMcpError(error);
    }
  }
}

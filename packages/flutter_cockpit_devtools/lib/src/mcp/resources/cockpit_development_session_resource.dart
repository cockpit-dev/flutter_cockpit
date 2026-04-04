import '../../application/cockpit_json_key_normalizer.dart';
import '../../application/cockpit_session_registry.dart';
import '../core/cockpit_mcp_feature_category.dart';
import '../core/cockpit_mcp_resource.dart';
import '../core/cockpit_mcp_resource_definition.dart';

final class CockpitDevelopmentSessionResource extends CockpitMcpResource {
  const CockpitDevelopmentSessionResource({
    required CockpitSessionRegistry registry,
  }) : _registry = registry;

  final CockpitSessionRegistry _registry;

  @override
  CockpitMcpResourceDefinition get definition =>
      const CockpitMcpResourceDefinition.template(
        name: 'development_session',
        uriTemplate: 'cockpit://session/development{?developmentSessionId}',
        description:
            'Read a tracked development session record by developmentSessionId.',
        mimeType: 'application/json',
        categories: <CockpitMcpFeatureCategory>[
          CockpitMcpFeatureCategory.closedLoop,
          CockpitMcpFeatureCategory.sessionManagement,
          CockpitMcpFeatureCategory.contextResources,
        ],
      );

  @override
  Future<CockpitMcpResourceResult?> read(
      CockpitMcpResourceRequest request) async {
    final uri = request.parsedUri;
    if (uri.host != 'session' || uri.path != '/development') {
      return null;
    }
    final developmentSessionId = uri.queryParameters['developmentSessionId'];
    if (developmentSessionId == null || developmentSessionId.isEmpty) {
      throw StateError(
        'development session resource requires developmentSessionId.',
      );
    }
    final record = _registry.developmentSession(developmentSessionId);
    if (record == null) {
      return CockpitMcpResourceResult(
        contents: <CockpitMcpResourceContents>[
          CockpitMcpTextResourceContents(
            uri: request.uri,
            text: cockpitPrettyJsonText(<String, Object?>{
              'state': 'missing',
              'developmentSessionId': developmentSessionId,
            }),
            mimeType: definition.mimeType,
          ),
        ],
      );
    }
    return CockpitMcpResourceResult(
      contents: <CockpitMcpResourceContents>[
        CockpitMcpTextResourceContents(
          uri: request.uri,
          text: cockpitPrettyJsonText(record.toJson()),
          mimeType: definition.mimeType,
        ),
      ],
    );
  }
}

import '../../application/cockpit_app_handle.dart';
import '../../application/cockpit_json_key_normalizer.dart';
import '../../application/cockpit_list_apps_service.dart';
import '../../application/cockpit_session_registry.dart';
import '../core/cockpit_mcp_feature_category.dart';
import '../core/cockpit_mcp_resource.dart';
import '../core/cockpit_mcp_resource_definition.dart';

final class CockpitAppsResource extends CockpitMcpResource {
  const CockpitAppsResource({
    required CockpitListAppsService service,
  }) : _service = service;

  final CockpitListAppsService _service;

  @override
  CockpitMcpResourceDefinition get definition =>
      const CockpitMcpResourceDefinition.fixed(
        name: 'apps',
        uri: 'cockpit://app/list',
        description: 'Known running apps tracked by this MCP server process.',
        mimeType: 'application/json',
        categories: <CockpitMcpFeatureCategory>[
          CockpitMcpFeatureCategory.closedLoop,
          CockpitMcpFeatureCategory.sessionManagement,
          CockpitMcpFeatureCategory.contextResources,
        ],
      );

  @override
  Future<CockpitMcpResourceResult?> read(
    CockpitMcpResourceRequest request,
  ) async {
    if (request.uri != definition.uri) {
      return null;
    }
    return CockpitMcpResourceResult(
      contents: <CockpitMcpResourceContents>[
        CockpitMcpTextResourceContents(
          uri: request.uri,
          text: cockpitPrettyJsonText(_service.list().toJson()),
          mimeType: definition.mimeType,
        ),
      ],
    );
  }
}

final class CockpitAppResource extends CockpitMcpResource {
  const CockpitAppResource({
    required CockpitSessionRegistry registry,
  }) : _registry = registry;

  final CockpitSessionRegistry _registry;

  @override
  CockpitMcpResourceDefinition get definition =>
      const CockpitMcpResourceDefinition.template(
        name: 'app',
        uriTemplate: 'cockpit://app/details{?appId}',
        description: 'Read the latest tracked app record by appId.',
        mimeType: 'application/json',
        categories: <CockpitMcpFeatureCategory>[
          CockpitMcpFeatureCategory.closedLoop,
          CockpitMcpFeatureCategory.sessionManagement,
          CockpitMcpFeatureCategory.contextResources,
        ],
      );

  @override
  Future<CockpitMcpResourceResult?> read(
    CockpitMcpResourceRequest request,
  ) async {
    final uri = request.parsedUri;
    if (uri.host != 'app' || uri.path != '/details') {
      return null;
    }
    final appId = uri.queryParameters['appId'];
    if (appId == null || appId.isEmpty) {
      throw StateError('app resource requires appId.');
    }

    final developmentRecord = _registry.developmentSessionByAppId(appId);
    if (developmentRecord != null) {
      final payload = <String, Object?>{
        'state': developmentRecord.status.state.jsonValue,
        'updatedAt': developmentRecord.updatedAt.toUtc().toIso8601String(),
        'lastError': developmentRecord.status.lastError,
        'app': CockpitAppHandle.fromDevelopmentSession(
          developmentRecord.handle,
          supervisorLogPath: developmentRecord.supervisorLogPath,
        ).toJson(),
      };
      return _textResult(request.uri, payload);
    }

    final remoteRecord = _registry.remoteSessionByAppId(appId);
    if (remoteRecord != null) {
      final payload = <String, Object?>{
        'state': remoteRecord.recommendedNextStep,
        'updatedAt': remoteRecord.updatedAt.toUtc().toIso8601String(),
        'lastError': null,
        'app': CockpitAppHandle.fromRemoteSession(remoteRecord.handle).toJson(),
      };
      return _textResult(request.uri, payload);
    }

    return _textResult(
      request.uri,
      <String, Object?>{
        'state': 'missing',
        'appId': appId,
      },
    );
  }

  CockpitMcpResourceResult _textResult(
      String uri, Map<String, Object?> payload) {
    return CockpitMcpResourceResult(
      contents: <CockpitMcpResourceContents>[
        CockpitMcpTextResourceContents(
          uri: uri,
          text: cockpitPrettyJsonText(payload),
          mimeType: definition.mimeType,
        ),
      ],
    );
  }
}

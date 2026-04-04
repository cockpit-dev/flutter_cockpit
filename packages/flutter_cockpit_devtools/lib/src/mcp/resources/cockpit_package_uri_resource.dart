import '../../application/cockpit_json_key_normalizer.dart';
import '../../application/cockpit_read_package_uris_service.dart';
import '../../application/cockpit_workspace_tooling_support.dart';
import '../core/cockpit_mcp_feature_category.dart';
import '../core/cockpit_mcp_resource.dart';
import '../core/cockpit_mcp_resource_definition.dart';
import '../core/cockpit_mcp_roots_tracker.dart';

final class CockpitPackageUriResource extends CockpitMcpResource {
  CockpitPackageUriResource({
    required CockpitMcpRootsTracker rootsTracker,
    CockpitReadPackageUrisService? service,
  })  : _rootsTracker = rootsTracker,
        _service = service ?? CockpitReadPackageUrisService();

  final CockpitMcpRootsTracker _rootsTracker;
  final CockpitReadPackageUrisService _service;

  @override
  CockpitMcpResourceDefinition get definition =>
      const CockpitMcpResourceDefinition.template(
        name: 'package_uri',
        uriTemplate: 'cockpit://package/read{?workspaceRoot,uri}',
        description:
            'Read a package: or package-root: URI using a workspace package_config.',
        mimeType: 'application/json',
        categories: <CockpitMcpFeatureCategory>[
          CockpitMcpFeatureCategory.workspace,
          CockpitMcpFeatureCategory.dependencyIntelligence,
          CockpitMcpFeatureCategory.contextResources,
        ],
      );

  @override
  Future<CockpitMcpResourceResult?> read(
      CockpitMcpResourceRequest request) async {
    final uri = request.parsedUri;
    if (uri.host != 'package' || uri.path != '/read') {
      return null;
    }
    final workspaceRootPath = uri.queryParameters['workspaceRoot'];
    final workspaceRoot = resolveWorkspaceRoot(
      workspaceRoot: workspaceRootPath,
      allowedRoots: cockpitPathsFromRootUris(
        _rootsTracker.effectiveRoots.map((root) => root.uri),
      ),
      argumentName: 'workspaceRoot',
    );
    final packageUri = uri.queryParameters['uri'];
    if (packageUri == null || packageUri.isEmpty) {
      throw StateError('package uri resource requires a uri query parameter.');
    }

    final result = await _service.read(
      CockpitReadPackageUrisRequest(
        workspaceRoot: workspaceRoot,
        uri: packageUri,
        allowedRoots: cockpitPathsFromRootUris(
          _rootsTracker.effectiveRoots.map((root) => root.uri),
        ),
      ),
    );
    final payload = <String, Object?>{
      'workspaceRoot': workspaceRoot,
      'uri': packageUri,
      'kind': result.kind.name,
      'contentKind': result.contentKind.name,
      'resolvedPath': result.resolvedPath,
      'preview': result.preview,
      'text': result.text,
      'mediaType': result.mediaType,
      'totalBytes': result.totalBytes,
      'entryCount': result.entryCount,
      'truncated': result.truncated,
      'entries': result.entries
          .map(
            (entry) => <String, Object?>{
              'path': entry.path,
              'name': entry.name,
              'isDirectory': entry.isDirectory,
            },
          )
          .toList(growable: false),
    };
    return CockpitMcpResourceResult(
      contents: <CockpitMcpResourceContents>[
        CockpitMcpTextResourceContents(
          uri: request.uri,
          text: cockpitPrettyJsonText(payload),
          mimeType: definition.mimeType,
        ),
      ],
    );
  }
}

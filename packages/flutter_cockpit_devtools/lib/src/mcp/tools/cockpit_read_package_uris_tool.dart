import '../../application/cockpit_read_package_uris_service.dart';
import '../cockpit_mcp_error.dart';
import '../cockpit_mcp_tool.dart';
import '../core/cockpit_mcp_roots_tracker.dart';
import '../core/cockpit_mcp_workspace_tooling_support.dart';

typedef CockpitReadPackageUrisToolFunction =
    Future<CockpitReadPackageUrisResult> Function(
      CockpitReadPackageUrisRequest request,
    );

final class CockpitReadPackageUrisTool extends CockpitMcpTool {
  CockpitReadPackageUrisTool({
    required CockpitMcpRootsTracker rootsTracker,
    CockpitReadPackageUrisService? service,
    CockpitReadPackageUrisToolFunction? read,
  }) : _rootsTracker = rootsTracker,
       _read = read ?? (service ?? CockpitReadPackageUrisService()).read;

  final CockpitMcpRootsTracker _rootsTracker;
  final CockpitReadPackageUrisToolFunction _read;

  @override
  String get name => 'read_package_uris';

  @override
  String get description =>
      'Read package: and package-root: URIs from dependencies resolved in a workspace package_config.';

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
    'required': <String>['uris'],
    'properties': <String, Object?>{
      'workspaceRoot': <String, Object?>{'type': 'string'},
      'uris': <String, Object?>{
        'type': 'array',
        'items': <String, Object?>{'type': 'string'},
      },
      'maxPreviewChars': <String, Object?>{'type': 'integer'},
      'maxEntries': <String, Object?>{'type': 'integer'},
      'includeFullText': <String, Object?>{'type': 'boolean'},
    },
  };

  @override
  Future<Map<String, Object?>> call(Map<String, Object?> arguments) async {
    try {
      final workspaceRoot = cockpitResolveWorkspaceRootFromArguments(
        arguments,
        _rootsTracker,
      );
      final uris = cockpitReadOptionalStringList(arguments, 'uris');
      if (uris.isEmpty) {
        throw CockpitMcpError.invalidArguments(
          'uris must contain at least one package URI.',
          details: const <String, Object?>{'argument': 'uris'},
        );
      }
      final allowedRoots = cockpitAllowedWorkspaceRootPaths(_rootsTracker);
      final maxPreviewChars =
          cockpitReadOptionalPositiveInt(arguments, 'maxPreviewChars') ?? 1200;
      final maxEntries =
          cockpitReadOptionalPositiveInt(arguments, 'maxEntries') ?? 40;
      final includeFullText =
          cockpitReadOptionalBool(arguments, 'includeFullText') ?? false;
      final results = <Map<String, Object?>>[];
      for (final uri in uris) {
        final result = await _read(
          CockpitReadPackageUrisRequest(
            workspaceRoot: workspaceRoot,
            uri: uri,
            allowedRoots: allowedRoots,
            maxPreviewChars: maxPreviewChars,
            maxEntries: maxEntries,
            includeFullText: includeFullText,
          ),
        );
        results.add(<String, Object?>{'uri': uri, ...result.toJson()});
      }
      return cockpitMcpResult(
        text: 'Package URIs resolved.',
        structuredContent: <String, Object?>{
          'workspaceRoot': workspaceRoot,
          'results': results,
        },
      );
    } on Object catch (error) {
      cockpitRethrowAsMcpError(error);
    }
  }
}

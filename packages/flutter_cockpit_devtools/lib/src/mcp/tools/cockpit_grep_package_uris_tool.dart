import '../../application/cockpit_grep_package_uris_service.dart';
import '../cockpit_mcp_error.dart';
import '../cockpit_mcp_tool.dart';
import '../core/cockpit_mcp_roots_tracker.dart';
import '../core/cockpit_mcp_workspace_tooling_support.dart';

typedef CockpitGrepPackageUrisToolFunction
    = Future<CockpitGrepPackageUrisResult> Function(
  CockpitGrepPackageUrisRequest request,
);

final class CockpitGrepPackageUrisTool extends CockpitMcpTool {
  CockpitGrepPackageUrisTool({
    required CockpitMcpRootsTracker rootsTracker,
    CockpitGrepPackageUrisService? service,
    CockpitGrepPackageUrisToolFunction? grep,
  })  : _rootsTracker = rootsTracker,
        _grep = grep ?? (service ?? CockpitGrepPackageUrisService()).grep;

  final CockpitMcpRootsTracker _rootsTracker;
  final CockpitGrepPackageUrisToolFunction _grep;

  @override
  String get name => 'grep_package_uris';

  @override
  String get description =>
      'Search bounded matches inside resolved dependency packages and return compact structured hits.';

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
        'required': <String>['packageNames', 'query'],
        'properties': <String, Object?>{
          'workspaceRoot': <String, Object?>{'type': 'string'},
          'packageNames': <String, Object?>{
            'type': 'array',
            'items': <String, Object?>{'type': 'string'},
          },
          'query': <String, Object?>{'type': 'string'},
          'searchDir': <String, Object?>{'type': 'string'},
          'useRegex': <String, Object?>{'type': 'boolean'},
          'caseSensitive': <String, Object?>{'type': 'boolean'},
          'maxMatches': <String, Object?>{'type': 'integer'},
          'maxMatchesPerFile': <String, Object?>{'type': 'integer'},
          'maxLineLength': <String, Object?>{'type': 'integer'},
          'timeoutSeconds': <String, Object?>{'type': 'integer'},
        },
      };

  @override
  Future<Map<String, Object?>> call(Map<String, Object?> arguments) async {
    try {
      final workspaceRoot = cockpitResolveWorkspaceRootFromArguments(
        arguments,
        _rootsTracker,
      );
      final packageNames =
          cockpitReadOptionalStringList(arguments, 'packageNames');
      if (packageNames.isEmpty) {
        throw CockpitMcpError.invalidArguments(
          'packageNames must contain at least one dependency package.',
          details: const <String, Object?>{'argument': 'packageNames'},
        );
      }
      final allowedRoots = cockpitAllowedWorkspaceRootPaths(_rootsTracker);
      final result = await _grep(
        CockpitGrepPackageUrisRequest(
          workspaceRoot: workspaceRoot,
          packageNames: packageNames,
          query: cockpitReadRequiredString(arguments, 'query'),
          allowedRoots: allowedRoots,
          searchDir: cockpitReadOptionalString(arguments, 'searchDir') ?? 'lib',
          useRegex: cockpitReadOptionalBool(arguments, 'useRegex') ?? false,
          caseSensitive:
              cockpitReadOptionalBool(arguments, 'caseSensitive') ?? false,
          maxMatches:
              cockpitReadOptionalPositiveInt(arguments, 'maxMatches') ?? 60,
          maxMatchesPerFile: cockpitReadOptionalPositiveInt(
                arguments,
                'maxMatchesPerFile',
              ) ??
              5,
          maxLineLength:
              cockpitReadOptionalPositiveInt(arguments, 'maxLineLength') ?? 240,
          timeout: Duration(
            seconds: cockpitReadOptionalPositiveInt(
                  arguments,
                  'timeoutSeconds',
                ) ??
                20,
          ),
        ),
      );
      return cockpitMcpResult(
        text: 'Dependency package search completed.',
        structuredContent: result.toJson(),
      );
    } on Object catch (error) {
      cockpitRethrowAsMcpError(error);
    }
  }
}

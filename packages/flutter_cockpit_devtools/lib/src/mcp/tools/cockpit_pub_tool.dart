import '../../application/cockpit_pub_service.dart';
import '../cockpit_mcp_error.dart';
import '../cockpit_mcp_tool.dart';
import '../core/cockpit_mcp_roots_tracker.dart';
import '../core/cockpit_mcp_workspace_tooling_support.dart';

typedef CockpitPubToolFunction = Future<CockpitPubResult> Function(
  CockpitPubRequest request,
);

final class CockpitPubTool extends CockpitMcpTool {
  CockpitPubTool({
    required CockpitMcpRootsTracker rootsTracker,
    CockpitPubService? service,
    CockpitPubToolFunction? run,
  })  : _rootsTracker = rootsTracker,
        _run = run ?? (service ?? CockpitPubService()).run;

  final CockpitMcpRootsTracker _rootsTracker;
  final CockpitPubToolFunction _run;

  @override
  String get name => 'pub';

  @override
  String get description =>
      'Run bounded pub commands inside a workspace root. Use packages only for add and remove.';

  @override
  CockpitMcpToolAnnotations get annotations => const CockpitMcpToolAnnotations(
        readOnly: false,
        destructive: false,
        idempotent: false,
        longRunning: true,
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
        'required': <String>['command'],
        'properties': <String, Object?>{
          'workspaceRoot': <String, Object?>{'type': 'string'},
          'command': <String, Object?>{
            'type': 'string',
            'enum': <String>[
              'add',
              'deps',
              'get',
              'outdated',
              'remove',
              'upgrade',
            ],
          },
          'packages': <String, Object?>{
            'type': 'array',
            'items': <String, Object?>{'type': 'string'},
          },
          'maxOutputChars': <String, Object?>{'type': 'integer'},
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
      final result = await _run(
        CockpitPubRequest(
          workspaceRoot: workspaceRoot,
          command: _commandFromArgument(
            cockpitReadRequiredString(arguments, 'command'),
          ),
          packages: cockpitReadOptionalStringList(arguments, 'packages'),
          allowedRoots: cockpitAllowedWorkspaceRootPaths(_rootsTracker),
          maxOutputChars:
              cockpitReadOptionalInt(arguments, 'max_output_chars') ?? 1600,
          timeout: Duration(
            seconds:
                cockpitReadOptionalInt(arguments, 'timeout_seconds') ?? 240,
          ),
        ),
      );
      return cockpitMcpResult(
        text: 'pub command completed.',
        structuredContent: result.toJson(),
      );
    } on Object catch (error) {
      cockpitRethrowAsMcpError(error);
    }
  }

  CockpitPubCommand _commandFromArgument(String value) {
    return CockpitPubCommand.values.firstWhere(
      (command) => command.name == value,
      orElse: () => throw CockpitMcpError.invalidArguments(
        'command must be one of add, deps, get, outdated, remove, or upgrade.',
        details: const <String, Object?>{'argument': 'command'},
      ),
    );
  }
}

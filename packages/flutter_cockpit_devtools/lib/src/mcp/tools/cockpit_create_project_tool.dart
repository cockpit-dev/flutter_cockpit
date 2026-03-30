import '../../application/cockpit_create_project_service.dart';
import '../cockpit_mcp_error.dart';
import '../cockpit_mcp_tool.dart';
import '../core/cockpit_mcp_roots_tracker.dart';
import '../core/cockpit_mcp_workspace_tooling_support.dart';

typedef CockpitCreateProjectToolFunction = Future<CockpitCreateProjectResult>
    Function(CockpitCreateProjectRequest request);

final class CockpitCreateProjectTool extends CockpitMcpTool {
  CockpitCreateProjectTool({
    required CockpitMcpRootsTracker rootsTracker,
    CockpitCreateProjectService? service,
    CockpitCreateProjectToolFunction? create,
  })  : _rootsTracker = rootsTracker,
        _create = create ?? (service ?? CockpitCreateProjectService()).create;

  final CockpitMcpRootsTracker _rootsTracker;
  final CockpitCreateProjectToolFunction _create;

  @override
  String get name => 'create_project';

  @override
  String get description =>
      'Create a new Dart CLI or Flutter app project inside an allowed workspace root.';

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
        CockpitMcpFeatureCategory.projectScaffolding,
      ];

  @override
  Map<String, Object?> get inputSchema => const <String, Object?>{
        'type': 'object',
        'required': <String>['project_name', 'template'],
        'properties': <String, Object?>{
          'parent_directory': <String, Object?>{'type': 'string'},
          'project_name': <String, Object?>{'type': 'string'},
          'template': <String, Object?>{
            'type': 'string',
            'enum': <String>['dart_cli', 'flutter_app'],
          },
          'organization': <String, Object?>{'type': 'string'},
          'platforms': <String, Object?>{
            'type': 'array',
            'items': <String, Object?>{'type': 'string'},
          },
        },
      };

  @override
  Future<Map<String, Object?>> call(Map<String, Object?> arguments) async {
    try {
      final template = _templateFromArgument(
        cockpitReadRequiredString(arguments, 'template'),
      );
      final parentDirectory = cockpitResolveParentDirectoryFromArguments(
        arguments,
        _rootsTracker,
      );
      final result = await _create(
        CockpitCreateProjectRequest(
          parentDirectory: parentDirectory,
          projectName: cockpitReadRequiredString(arguments, 'project_name'),
          template: template,
          organization: cockpitReadOptionalString(arguments, 'organization'),
          platforms: cockpitReadOptionalStringList(arguments, 'platforms'),
          allowedRoots: cockpitAllowedWorkspaceRootPaths(_rootsTracker),
        ),
      );
      return cockpitMcpResult(
        text: 'Project created.',
        structuredContent: result.toJson(),
      );
    } on Object catch (error) {
      cockpitRethrowAsMcpError(error);
    }
  }

  CockpitProjectTemplate _templateFromArgument(String value) {
    return switch (value) {
      'dart_cli' => CockpitProjectTemplate.dartCli,
      'flutter_app' => CockpitProjectTemplate.flutterApp,
      _ => throw CockpitMcpError.invalidArguments(
          'template must be dart_cli or flutter_app.',
          details: const <String, Object?>{'argument': 'template'},
        ),
    };
  }
}

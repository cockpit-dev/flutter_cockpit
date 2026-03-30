import 'package:dart_mcp/server.dart' show Root;
import 'package:flutter_cockpit_devtools/src/application/cockpit_create_project_service.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_pub_dev_search_service.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_read_package_uris_service.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_workspace_command_result.dart';
import 'package:flutter_cockpit_devtools/src/mcp/core/cockpit_mcp_roots_tracker.dart';
import 'package:flutter_cockpit_devtools/src/mcp/tools/cockpit_add_roots_tool.dart';
import 'package:flutter_cockpit_devtools/src/mcp/tools/cockpit_create_project_tool.dart';
import 'package:flutter_cockpit_devtools/src/mcp/tools/cockpit_pub_dev_search_tool.dart';
import 'package:flutter_cockpit_devtools/src/mcp/tools/cockpit_read_package_uris_tool.dart';
import 'package:flutter_cockpit_devtools/src/mcp/tools/cockpit_remove_roots_tool.dart';
import 'package:test/test.dart';

void main() {
  test('read_package_uris defaults to the single configured root', () async {
    final rootsTracker = CockpitMcpRootsTracker(forceFallback: true)
      ..addFallbackRoots(
          <Root>[Root(uri: 'file:///workspace/', name: 'workspace')]);
    CockpitReadPackageUrisRequest? capturedRequest;
    final tool = CockpitReadPackageUrisTool(
      rootsTracker: rootsTracker,
      read: (request) async {
        capturedRequest = request;
        return const CockpitReadPackageUrisResult(
          kind: CockpitPackageUriEntryKind.file,
          resolvedPath: '/deps/example/lib/example.dart',
          text: 'library example;',
        );
      },
    );

    final result = await tool.call(<String, Object?>{
      'uris': <String>['package:example/example.dart'],
    });

    expect(capturedRequest?.workspaceRoot, '/workspace');
    expect(capturedRequest?.allowedRoots, <String>['/workspace']);
    final structured = result['structuredContent'] as Map<String, Object?>;
    expect((structured['results'] as List<Object?>), hasLength(1));
  });

  test('create_project defaults parent_directory to the single configured root',
      () async {
    final rootsTracker = CockpitMcpRootsTracker(forceFallback: true)
      ..addFallbackRoots(
          <Root>[Root(uri: 'file:///workspace/', name: 'workspace')]);
    CockpitCreateProjectRequest? capturedRequest;
    final tool = CockpitCreateProjectTool(
      rootsTracker: rootsTracker,
      create: (request) async {
        capturedRequest = request;
        return CockpitCreateProjectResult(
          projectDirectory: '/workspace/new_app',
          command: const CockpitWorkspaceCommand(
            executable: 'flutter',
            arguments: <String>['create', '/workspace/new_app'],
            workingDirectory: '/workspace',
          ),
          success: true,
          stdout: 'created',
          stderr: '',
        );
      },
    );

    final result = await tool.call(<String, Object?>{
      'project_name': 'new_app',
      'template': 'flutter_app',
    });

    expect(capturedRequest?.parentDirectory, '/workspace');
    expect(capturedRequest?.allowedRoots, <String>['/workspace']);
    final structured = result['structuredContent'] as Map<String, Object?>;
    expect(structured['projectDirectory'], '/workspace/new_app');
  });

  test('pub_dev_search returns shaped package summaries', () async {
    final tool = CockpitPubDevSearchTool(
      search: (_) async => const CockpitPubDevSearchResult(
        results: <CockpitPubDevPackageSummary>[
          CockpitPubDevPackageSummary(
            packageName: 'riverpod',
            latestVersion: '2.0.0',
            description: 'State management.',
            publisher: 'example.dev',
            grantedPoints: 140,
            maxPoints: 160,
            likeCount: 200,
            popularityScore: 0.99,
          ),
        ],
      ),
    );

    final result =
        await tool.call(<String, Object?>{'query': 'state management'});
    final structured = result['structuredContent'] as Map<String, Object?>;
    expect((structured['results'] as List<Object?>), hasLength(1));
  });

  test('add_roots and remove_roots mutate fallback roots', () async {
    final rootsTracker = CockpitMcpRootsTracker(forceFallback: true);
    final addTool = CockpitAddRootsTool(rootsTracker: rootsTracker);
    final removeTool = CockpitRemoveRootsTool(rootsTracker: rootsTracker);

    await addTool.call(<String, Object?>{
      'roots': <Map<String, Object?>>[
        <String, Object?>{'uri': 'file:///workspace/'},
      ],
    });
    expect(rootsTracker.effectiveRoots.map((root) => root.uri), <String>[
      'file:///workspace/',
    ]);

    await removeTool.call(<String, Object?>{
      'uris': <String>['file:///workspace/'],
    });
    expect(rootsTracker.effectiveRoots, isEmpty);
  });
}

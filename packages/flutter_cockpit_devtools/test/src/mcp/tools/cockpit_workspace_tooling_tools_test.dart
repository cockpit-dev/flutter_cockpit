import 'package:dart_mcp/server.dart' show Root;
import 'package:flutter_cockpit_devtools/src/application/cockpit_create_project_service.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_grep_package_uris_service.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_analyze_files_service.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_lsp_service.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_pub_service.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_pub_dev_search_service.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_read_package_uris_service.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_workspace_command_result.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_workspace_tooling_support.dart';
import 'package:flutter_cockpit_devtools/src/mcp/tools/cockpit_analyze_files_tool.dart';
import 'package:flutter_cockpit_devtools/src/mcp/core/cockpit_mcp_roots_tracker.dart';
import 'package:flutter_cockpit_devtools/src/mcp/tools/cockpit_add_roots_tool.dart';
import 'package:flutter_cockpit_devtools/src/mcp/tools/cockpit_create_project_tool.dart';
import 'package:flutter_cockpit_devtools/src/mcp/tools/cockpit_grep_package_uris_tool.dart';
import 'package:flutter_cockpit_devtools/src/mcp/tools/cockpit_lsp_tool.dart';
import 'package:flutter_cockpit_devtools/src/mcp/tools/cockpit_pub_tool.dart';
import 'package:flutter_cockpit_devtools/src/mcp/tools/cockpit_pub_dev_search_tool.dart';
import 'package:flutter_cockpit_devtools/src/mcp/tools/cockpit_read_package_uris_tool.dart';
import 'package:flutter_cockpit_devtools/src/mcp/tools/cockpit_remove_roots_tool.dart';
import 'package:test/test.dart';

void main() {
  test('read_package_uris defaults to the single configured root', () async {
    final rootsTracker = CockpitMcpRootsTracker(forceFallback: true)
      ..addFallbackRoots(<Root>[
        Root(uri: 'file:///workspace/', name: 'workspace'),
      ]);
    CockpitReadPackageUrisRequest? capturedRequest;
    final tool = CockpitReadPackageUrisTool(
      rootsTracker: rootsTracker,
      read: (request) async {
        capturedRequest = request;
        return const CockpitReadPackageUrisResult(
          kind: CockpitPackageUriEntryKind.file,
          contentKind: CockpitPackageUriContentKind.text,
          resolvedPath: '/deps/example/lib/example.dart',
          preview: 'library example;',
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

  test(
    'create_project defaults parentDirectory to the single configured root',
    () async {
      final rootsTracker = CockpitMcpRootsTracker(forceFallback: true)
        ..addFallbackRoots(<Root>[
          Root(uri: 'file:///workspace/', name: 'workspace'),
        ]);
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
        'projectName': 'new_app',
        'template': 'flutter_app',
      });

      expect(capturedRequest?.parentDirectory, '/workspace');
      expect(capturedRequest?.allowedRoots, <String>['/workspace']);
      expect(capturedRequest?.timeout, const Duration(minutes: 5));
      final structured = result['structuredContent'] as Map<String, Object?>;
      expect(structured['projectDirectory'], '/workspace/new_app');
    },
  );

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

    final result = await tool.call(<String, Object?>{
      'query': 'state management',
    });
    final structured = result['structuredContent'] as Map<String, Object?>;
    expect((structured['results'] as List<Object?>), hasLength(1));
  });

  test('grep_package_uris defaults to the single configured root', () async {
    final rootsTracker = CockpitMcpRootsTracker(forceFallback: true)
      ..addFallbackRoots(<Root>[
        Root(uri: 'file:///workspace/', name: 'workspace'),
      ]);
    CockpitGrepPackageUrisRequest? capturedRequest;
    final tool = CockpitGrepPackageUrisTool(
      rootsTracker: rootsTracker,
      grep: (request) async {
        capturedRequest = request;
        return const CockpitGrepPackageUrisResult(
          workspaceRoot: '/workspace',
          query: 'ThemeData',
          searchDir: 'lib',
          useRegex: false,
          caseSensitive: false,
          usedRipgrep: false,
          matchedPackageCount: 1,
          matchedFileCount: 1,
          totalMatches: 1,
          truncated: false,
          summary: 'Found 1 match across 1 file in 1 package.',
          packages: <CockpitGrepPackageUrisPackageResult>[
            CockpitGrepPackageUrisPackageResult(
              packageName: 'flutter',
              searchRoot: '/deps/flutter/lib',
              matchCount: 1,
              files: <CockpitGrepPackageUrisFileResult>[
                CockpitGrepPackageUrisFileResult(
                  path: '/deps/flutter/lib/src/material/theme_data.dart',
                  relativePath: 'lib/src/material/theme_data.dart',
                  packageRootUri:
                      'package-root:flutter/lib/src/material/theme_data.dart',
                  packageUri: 'package:flutter/src/material/theme_data.dart',
                  matches: <CockpitGrepPackageUrisMatch>[
                    CockpitGrepPackageUrisMatch(
                      line: 10,
                      column: 7,
                      endColumn: 15,
                      text: 'class ThemeData {',
                    ),
                  ],
                ),
              ],
            ),
          ],
        );
      },
    );

    final result = await tool.call(<String, Object?>{
      'packageNames': <String>['flutter'],
      'query': 'ThemeData',
    });

    expect(capturedRequest?.workspaceRoot, '/workspace');
    expect(capturedRequest?.allowedRoots, <String>['/workspace']);
    final structured = result['structuredContent'] as Map<String, Object?>;
    expect(structured['matchedPackageCount'], 1);
    expect((structured['packages'] as List<Object?>), hasLength(1));
  });

  test(
    'pub defaults to the single configured root and returns a bounded summary',
    () async {
      final rootsTracker = CockpitMcpRootsTracker(forceFallback: true)
        ..addFallbackRoots(<Root>[
          Root(uri: 'file:///workspace/', name: 'workspace'),
        ]);
      CockpitPubRequest? capturedRequest;
      final tool = CockpitPubTool(
        rootsTracker: rootsTracker,
        run: (request) async {
          capturedRequest = request;
          return const CockpitPubResult(
            workspaceRoot: '/workspace',
            toolchain: CockpitWorkspaceToolchain.dart,
            pubCommand: CockpitPubCommand.get,
            packages: <String>[],
            command: CockpitWorkspaceCommand(
              executable: 'dart',
              arguments: <String>['pub', 'get'],
              workingDirectory: '/workspace',
            ),
            exitCode: 0,
            success: true,
            summary: 'Got dependencies.',
          );
        },
      );

      final result = await tool.call(<String, Object?>{'command': 'get'});

      expect(capturedRequest?.workspaceRoot, '/workspace');
      expect(capturedRequest?.timeout, const Duration(minutes: 4));
      final structured = result['structuredContent'] as Map<String, Object?>;
      expect(structured['summary'], 'Got dependencies.');
    },
  );

  test(
    'analyze_files forwards bounded requests with configured roots',
    () async {
      final rootsTracker = CockpitMcpRootsTracker(forceFallback: true)
        ..addFallbackRoots(<Root>[
          Root(uri: 'file:///workspace/', name: 'workspace'),
        ]);
      CockpitAnalyzeFilesRequest? capturedRequest;
      final tool = CockpitAnalyzeFilesTool(
        rootsTracker: rootsTracker,
        analyze: (request) async {
          capturedRequest = request;
          return const CockpitAnalyzeFilesResult(
            workspaceRoot: '/workspace',
            toolchain: CockpitWorkspaceToolchain.dart,
            paths: <String>['lib/main.dart'],
            command: CockpitWorkspaceCommand(
              executable: 'dart',
              arguments: <String>['analyze', '--format=json', 'lib/main.dart'],
              workingDirectory: '/workspace',
            ),
            exitCode: 2,
            success: false,
            clean: false,
            summary: '1 analyzer diagnostics: 1 warning.',
            totalDiagnostics: 1,
            diagnostics: <CockpitAnalyzeFilesDiagnostic>[
              CockpitAnalyzeFilesDiagnostic(
                path: 'lib/main.dart',
                severity: 'warning',
                type: 'static_warning',
                code: 'unused_import',
                message: 'Unused import.',
                line: 1,
                column: 1,
                endLine: 1,
                endColumn: 5,
              ),
            ],
            diagnosticsTruncated: false,
            severityCounts: <String, int>{'warning': 1},
          );
        },
      );

      final result = await tool.call(<String, Object?>{
        'paths': <String>['lib/main.dart'],
      });

      expect(capturedRequest?.workspaceRoot, '/workspace');
      expect(capturedRequest?.paths, <String>['lib/main.dart']);
      expect(capturedRequest?.timeout, const Duration(minutes: 2));
      final structured = result['structuredContent'] as Map<String, Object?>;
      expect(structured['totalDiagnostics'], 1);
    },
  );

  test('lsp exposes concise code intelligence results', () async {
    final rootsTracker = CockpitMcpRootsTracker(forceFallback: true)
      ..addFallbackRoots(<Root>[
        Root(uri: 'file:///workspace/', name: 'workspace'),
      ]);
    CockpitLspRequest? capturedRequest;
    final tool = CockpitLspTool(
      rootsTracker: rootsTracker,
      invoke: (request) async {
        capturedRequest = request;
        return const CockpitLspResult(
          command: CockpitLspCommand.hover,
          workspaceRoot: '/workspace',
          summary: 'Hover information found.',
          payload: <String, Object?>{
            'path': 'lib/main.dart',
            'line': 1,
            'column': 1,
            'found': true,
            'contents': 'Type: `Widget`',
          },
        );
      },
    );

    final result = await tool.call(<String, Object?>{
      'command': 'hover',
      'path': 'lib/main.dart',
      'line': 1,
      'column': 1,
    });

    expect(capturedRequest?.workspaceRoot, '/workspace');
    expect(capturedRequest?.command, CockpitLspCommand.hover);
    expect(capturedRequest?.timeout, const Duration(seconds: 20));
    final structured = result['structuredContent'] as Map<String, Object?>;
    expect(structured['found'], isTrue);
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

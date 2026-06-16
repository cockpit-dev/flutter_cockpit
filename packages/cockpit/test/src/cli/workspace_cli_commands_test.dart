import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:cockpit/cockpit.dart';
import 'package:cockpit/src/application/cockpit_workspace_tooling_support.dart';
import 'package:cockpit/src/cli/commands/analyze_files_command.dart';
import 'package:cockpit/src/cli/commands/create_project_command.dart';
import 'package:cockpit/src/cli/commands/grep_package_uris_command.dart';
import 'package:cockpit/src/cli/commands/lsp_command.dart';
import 'package:cockpit/src/cli/commands/pub_command.dart';
import 'package:cockpit/src/cli/commands/pub_dev_search_command.dart';
import 'package:cockpit/src/cli/commands/read_package_uris_command.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('pub-dev-search writes bounded package summaries', () async {
    CockpitPubDevSearchRequest? capturedRequest;
    final output = StringBuffer();
    final runner = CommandRunner<int>('cockpit', 'test')
      ..addCommand(
        PubDevSearchCommand(
          stdoutSink: output,
          search: (request) async {
            capturedRequest = request;
            return const CockpitPubDevSearchResult(
              results: <CockpitPubDevPackageSummary>[
                CockpitPubDevPackageSummary(
                  packageName: 'riverpod',
                  latestVersion: '3.0.0',
                  description: 'State management.',
                  publisher: 'example.dev',
                  grantedPoints: 140,
                  maxPoints: 160,
                  likeCount: 200,
                  popularityScore: 0.98,
                ),
              ],
            );
          },
        ),
      );

    final exitCode =
        await runner.run(<String>[
          'pub-dev-search',
          '--stdout-format',
          'json',
          '--query',
          'state management',
          '--max-results',
          '1',
        ]) ??
        0;

    expect(exitCode, 0);
    expect(capturedRequest?.query, 'state management');
    expect(capturedRequest?.maxResults, 1);
    final decoded = jsonDecode(output.toString()) as Map<String, Object?>;
    expect((decoded['results'] as List<Object?>), hasLength(1));
  });

  test('pub defaults workspace-root to the current directory', () async {
    final originalCurrent = Directory.current;
    final tempDir = await Directory.systemTemp.createTemp('pub_command');
    addTearDown(() async {
      Directory.current = originalCurrent;
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });
    Directory.current = tempDir;
    final currentRoot = p.normalize(Directory.current.path);

    CockpitPubRequest? capturedRequest;
    final output = StringBuffer();
    final runner = CommandRunner<int>('cockpit', 'test')
      ..addCommand(
        PubCommand(
          stdoutSink: output,
          run: (request) async {
            capturedRequest = request;
            return const CockpitPubResult(
              workspaceRoot: '/workspace',
              toolchain: CockpitWorkspaceToolchain.dart,
              pubCommand: CockpitPubCommand.add,
              packages: <String>['riverpod'],
              command: CockpitWorkspaceCommand(
                executable: 'dart',
                arguments: <String>['pub', 'add', 'riverpod'],
                workingDirectory: '/workspace',
              ),
              exitCode: 0,
              success: true,
              summary: 'Added riverpod.',
            );
          },
        ),
      );

    final exitCode =
        await runner.run(<String>[
          'pub',
          '--stdout-format',
          'json',
          '--command',
          'add',
          '--package',
          'riverpod',
        ]) ??
        0;

    expect(exitCode, 0);
    expect(capturedRequest?.workspaceRoot, currentRoot);
    expect(capturedRequest?.command, CockpitPubCommand.add);
    expect(capturedRequest?.packages, <String>['riverpod']);
    final decoded = jsonDecode(output.toString()) as Map<String, Object?>;
    expect(decoded['summary'], 'Added riverpod.');
  });

  test(
    'read-package-uris reads multiple URIs from one workspace root',
    () async {
      final originalCurrent = Directory.current;
      final tempDir = await Directory.systemTemp.createTemp(
        'read_package_uris_command',
      );
      addTearDown(() async {
        Directory.current = originalCurrent;
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });
      Directory.current = tempDir;
      final currentRoot = p.normalize(Directory.current.path);

      final capturedRequests = <CockpitReadPackageUrisRequest>[];
      final output = StringBuffer();
      final runner = CommandRunner<int>('cockpit', 'test')
        ..addCommand(
          ReadPackageUrisCommand(
            stdoutSink: output,
            read: (request) async {
              capturedRequests.add(request);
              return const CockpitReadPackageUrisResult(
                kind: CockpitPackageUriEntryKind.file,
                contentKind: CockpitPackageUriContentKind.text,
                resolvedPath: '/deps/example/lib/example.dart',
                preview: 'library example;',
              );
            },
          ),
        );

      final exitCode =
          await runner.run(<String>[
            'read-package-uris',
            '--stdout-format',
            'json',
            '--uri',
            'package:example/example.dart',
            '--uri',
            'package:other/other.dart',
          ]) ??
          0;

      expect(exitCode, 0);
      expect(capturedRequests, hasLength(2));
      expect(
        capturedRequests.every(
          (request) => request.workspaceRoot == currentRoot,
        ),
        isTrue,
      );
      final decoded = jsonDecode(output.toString()) as Map<String, Object?>;
      expect(decoded['workspaceRoot'], currentRoot);
      expect((decoded['results'] as List<Object?>), hasLength(2));
    },
  );

  test(
    'grep-package-uris defaults workspace-root to the current directory',
    () async {
      final originalCurrent = Directory.current;
      final tempDir = await Directory.systemTemp.createTemp(
        'grep_package_uris_command',
      );
      addTearDown(() async {
        Directory.current = originalCurrent;
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });
      Directory.current = tempDir;
      final currentRoot = p.normalize(Directory.current.path);

      CockpitGrepPackageUrisRequest? capturedRequest;
      final output = StringBuffer();
      final runner = CommandRunner<int>('cockpit', 'test')
        ..addCommand(
          GrepPackageUrisCommand(
            stdoutSink: output,
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
                        packageUri:
                            'package:flutter/src/material/theme_data.dart',
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
          ),
        );

      final exitCode =
          await runner.run(<String>[
            'grep-package-uris',
            '--stdout-format',
            'json',
            '--package',
            'flutter',
            '--query',
            'ThemeData',
          ]) ??
          0;

      expect(exitCode, 0);
      expect(capturedRequest?.workspaceRoot, currentRoot);
      expect(capturedRequest?.packageNames, <String>['flutter']);
      expect(capturedRequest?.query, 'ThemeData');
      final decoded = jsonDecode(output.toString()) as Map<String, Object?>;
      expect(decoded['matchedPackageCount'], 1);
      expect((decoded['packages'] as List<Object?>), hasLength(1));
    },
  );

  test('lsp defaults workspace-root to the current directory', () async {
    final originalCurrent = Directory.current;
    final tempDir = await Directory.systemTemp.createTemp('lsp_command');
    addTearDown(() async {
      Directory.current = originalCurrent;
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });
    Directory.current = tempDir;
    final currentRoot = p.normalize(Directory.current.path);

    CockpitLspRequest? capturedRequest;
    final output = StringBuffer();
    final runner = CommandRunner<int>('cockpit', 'test')
      ..addCommand(
        LspCommand(
          stdoutSink: output,
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
                'contents': 'Type: Widget',
              },
            );
          },
        ),
      );

    final exitCode =
        await runner.run(<String>[
          'lsp',
          '--stdout-format',
          'json',
          '--command',
          'hover',
          '--path',
          'lib/main.dart',
          '--line',
          '1',
          '--column',
          '1',
        ]) ??
        0;

    expect(exitCode, 0);
    expect(capturedRequest?.workspaceRoot, currentRoot);
    expect(capturedRequest?.command, CockpitLspCommand.hover);
    final decoded = jsonDecode(output.toString()) as Map<String, Object?>;
    expect(decoded['found'], isTrue);
  });

  test('analyze-files forwards focused analysis arguments', () async {
    final originalCurrent = Directory.current;
    final tempDir = await Directory.systemTemp.createTemp('analyze_files');
    addTearDown(() async {
      Directory.current = originalCurrent;
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });
    Directory.current = tempDir;
    final currentRoot = p.normalize(Directory.current.path);

    CockpitAnalyzeFilesRequest? capturedRequest;
    final output = StringBuffer();
    final runner = CommandRunner<int>('cockpit', 'test')
      ..addCommand(
        AnalyzeFilesCommand(
          stdoutSink: output,
          analyze: (request) async {
            capturedRequest = request;
            return const CockpitAnalyzeFilesResult(
              workspaceRoot: '/workspace',
              toolchain: CockpitWorkspaceToolchain.dart,
              paths: <String>['lib/main.dart'],
              command: CockpitWorkspaceCommand(
                executable: 'dart',
                arguments: <String>['analyze', 'lib/main.dart'],
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
        ),
      );

    final exitCode =
        await runner.run(<String>[
          'analyze-files',
          '--stdout-format',
          'json',
          '--path',
          'lib/main.dart',
          '--max-diagnostics',
          '10',
        ]) ??
        0;

    expect(exitCode, 0);
    expect(capturedRequest?.workspaceRoot, currentRoot);
    expect(capturedRequest?.paths, <String>['lib/main.dart']);
    expect(capturedRequest?.maxDiagnostics, 10);
    final decoded = jsonDecode(output.toString()) as Map<String, Object?>;
    expect(decoded['totalDiagnostics'], 1);
  });

  test(
    'create-project defaults parent-directory to the current directory',
    () async {
      final originalCurrent = Directory.current;
      final tempDir = await Directory.systemTemp.createTemp('create_project');
      addTearDown(() async {
        Directory.current = originalCurrent;
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });
      Directory.current = tempDir;
      final currentRoot = p.normalize(Directory.current.path);

      CockpitCreateProjectRequest? capturedRequest;
      final output = StringBuffer();
      final runner = CommandRunner<int>('cockpit', 'test')
        ..addCommand(
          CreateProjectCommand(
            stdoutSink: output,
            create: (request) async {
              capturedRequest = request;
              return const CockpitCreateProjectResult(
                projectDirectory: '/workspace/new_app',
                command: CockpitWorkspaceCommand(
                  executable: 'flutter',
                  arguments: <String>['create', '/workspace/new_app'],
                  workingDirectory: '/workspace',
                ),
                success: true,
                stdout: 'created',
                stderr: '',
              );
            },
          ),
        );

      final exitCode =
          await runner.run(<String>[
            'create-project',
            '--stdout-format',
            'json',
            '--project-name',
            'new_app',
            '--template',
            'flutter-app',
          ]) ??
          0;

      expect(exitCode, 0);
      expect(capturedRequest?.parentDirectory, currentRoot);
      expect(capturedRequest?.template, CockpitProjectTemplate.flutterApp);
      final decoded = jsonDecode(output.toString()) as Map<String, Object?>;
      expect(decoded['projectDirectory'], '/workspace/new_app');
    },
  );
}

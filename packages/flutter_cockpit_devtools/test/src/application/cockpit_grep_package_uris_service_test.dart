import 'dart:convert';
import 'dart:io';

import 'package:file/memory.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_grep_package_uris_service.dart';
import 'package:flutter_cockpit_devtools/src/infrastructure/cockpit_file_system.dart';
import 'package:flutter_cockpit_devtools/src/infrastructure/cockpit_process_manager.dart';
import 'package:test/test.dart';

void main() {
  test('falls back to filesystem search and returns package URIs', () async {
    final fileSystem = MemoryFileSystem();
    _writePackageConfig(fileSystem);
    fileSystem.file('/deps/example_pkg/lib/src/theme_data.dart')
      ..createSync(recursive: true)
      ..writeAsStringSync(
        'class ThemeData {}\nThemeData buildTheme() => ThemeData();\n',
      );

    final service = CockpitGrepPackageUrisService(
      fileSystem: LocalCockpitFileSystem(fileSystem: fileSystem),
      processManager: _UnavailableRipgrepProcessManager(),
    );

    final result = await service.grep(
      const CockpitGrepPackageUrisRequest(
        workspaceRoot: '/workspace',
        packageNames: <String>['example_pkg'],
        query: 'ThemeData',
      ),
    );

    expect(result.usedRipgrep, isFalse);
    expect(result.matchedPackageCount, 1);
    expect(result.totalMatches, 3);
    expect(
      result.packages.single.files.single.packageUri,
      'package:example_pkg/src/theme_data.dart',
    );
    expect(result.packages.single.files.single.matches.first.line, 1);
  });

  test('parses ripgrep json output when rg is available', () async {
    final fileSystem = MemoryFileSystem();
    _writePackageConfig(fileSystem);
    fileSystem.file('/deps/example_pkg/lib/src/theme_data.dart')
      ..createSync(recursive: true)
      ..writeAsStringSync('class ThemeData {}');

    final service = CockpitGrepPackageUrisService(
      fileSystem: LocalCockpitFileSystem(fileSystem: fileSystem),
      processManager: _RipgrepProcessManager(
        stdout: <String>[
          jsonEncode(<String, Object?>{
            'type': 'match',
            'data': <String, Object?>{
              'path': <String, Object?>{
                'text': '/deps/example_pkg/lib/src/theme_data.dart',
              },
              'lines': <String, Object?>{'text': 'class ThemeData {}\n'},
              'line_number': 1,
              'submatches': <Map<String, Object?>>[
                <String, Object?>{'start': 6, 'end': 15},
              ],
            },
          }),
        ].join('\n'),
      ),
    );

    final result = await service.grep(
      const CockpitGrepPackageUrisRequest(
        workspaceRoot: '/workspace',
        packageNames: <String>['example_pkg'],
        query: 'ThemeData',
      ),
    );

    expect(result.usedRipgrep, isTrue);
    expect(result.totalMatches, 1);
    expect(
      result.packages.single.files.single.packageRootUri,
      'package-root:example_pkg/lib/src/theme_data.dart',
    );
  });
}

void _writePackageConfig(MemoryFileSystem fileSystem) {
  fileSystem.file('/workspace/.dart_tool/package_config.json')
    ..createSync(recursive: true)
    ..writeAsStringSync(
      jsonEncode(<String, Object?>{
        'configVersion': 2,
        'packages': <Map<String, Object?>>[
          <String, Object?>{
            'name': 'example_pkg',
            'rootUri': 'file:///deps/example_pkg/',
            'packageUri': 'lib/',
            'languageVersion': '3.5',
          },
        ],
      }),
    );
}

final class _UnavailableRipgrepProcessManager implements CockpitProcessManager {
  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool includeParentEnvironment = true,
    bool runInShell = false,
    Encoding? stdoutEncoding,
    Encoding? stderrEncoding,
  }) {
    throw ProcessException(executable, arguments, 'not found', 127);
  }

  @override
  Future<Process> start(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool includeParentEnvironment = true,
    bool runInShell = false,
    ProcessStartMode mode = ProcessStartMode.normal,
  }) {
    throw UnimplementedError();
  }
}

final class _RipgrepProcessManager implements CockpitProcessManager {
  _RipgrepProcessManager({required this.stdout});

  final String stdout;

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool includeParentEnvironment = true,
    bool runInShell = false,
    Encoding? stdoutEncoding,
    Encoding? stderrEncoding,
  }) async {
    if (arguments.length == 1 && arguments.single == '--version') {
      return ProcessResult(0, 0, 'ripgrep 14.0.0', '');
    }
    return ProcessResult(0, 0, stdout, '');
  }

  @override
  Future<Process> start(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool includeParentEnvironment = true,
    bool runInShell = false,
    ProcessStartMode mode = ProcessStartMode.normal,
  }) {
    throw UnimplementedError();
  }
}

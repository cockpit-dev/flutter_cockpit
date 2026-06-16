import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file/memory.dart';
import 'package:cockpit/src/application/cockpit_analyze_files_service.dart';
import 'package:cockpit/src/infrastructure/cockpit_file_system.dart';
import 'package:cockpit/src/infrastructure/cockpit_process_manager.dart';
import 'package:cockpit/src/infrastructure/cockpit_sdk_environment.dart';
import 'package:test/test.dart';

void main() {
  test('returns concise analyzer diagnostics for focused paths', () async {
    final fileSystem = MemoryFileSystem();
    fileSystem.file('/workspace/pkg/pubspec.yaml')
      ..createSync(recursive: true)
      ..writeAsStringSync('name: pkg\n');
    fileSystem.file('/workspace/pkg/lib/main.dart')
      ..createSync(recursive: true)
      ..writeAsStringSync('void main() {}\n');
    final processManager = _RecordingAnalyzeFilesProcessManager();
    final service = CockpitAnalyzeFilesService(
      fileSystem: LocalCockpitFileSystem(fileSystem: fileSystem),
      processManager: processManager,
      sdkEnvironment: const CockpitSdkEnvironment(
        dartExecutable: 'dart-sdk',
        flutterExecutable: 'flutter-sdk',
      ),
    );

    final result = await service.analyze(
      const CockpitAnalyzeFilesRequest(
        workspaceRoot: '/workspace/pkg',
        paths: <String>['lib/main.dart'],
        maxDiagnostics: 1,
      ),
    );

    expect(result.command.executable, 'dart-sdk');
    expect(result.command.arguments, <String>['analyze', 'lib/main.dart']);
    expect(result.totalDiagnostics, 2);
    expect(result.diagnostics, hasLength(1));
    expect(result.diagnostics.single.path, 'lib/main.dart');
    expect(result.diagnostics.single.severity, 'warning');
    expect(result.diagnosticsTruncated, isTrue);
    expect(result.summary, contains('2 analyzer diagnostics'));
  });

  test('parses current flutter analyzer text diagnostics', () async {
    final fileSystem = MemoryFileSystem();
    fileSystem.file('/workspace/app/pubspec.yaml')
      ..createSync(recursive: true)
      ..writeAsStringSync('''
name: app
dependencies:
  flutter:
    sdk: flutter
''');
    fileSystem.file('/workspace/app/lib/main.dart')
      ..createSync(recursive: true)
      ..writeAsStringSync('void main() {}\n');
    final processManager = _TextAnalyzeFilesProcessManager(
      exitCode: 1,
      stdout: '''
Analyzing main.dart...

  error • Undefined name 'missing'. • lib/main.dart:3:11 • undefined_identifier
warning • The value of the local variable 'unused' isn't used. • lib/main.dart:4:9 • unused_local_variable
   info • Avoid print calls in production code. • lib/main.dart:5:3 • avoid_print

3 issues found. (ran in 1.2s)
''',
    );
    final service = CockpitAnalyzeFilesService(
      fileSystem: LocalCockpitFileSystem(fileSystem: fileSystem),
      processManager: processManager,
      sdkEnvironment: const CockpitSdkEnvironment(
        dartExecutable: 'dart-sdk',
        flutterExecutable: 'flutter-sdk',
      ),
    );

    final result = await service.analyze(
      const CockpitAnalyzeFilesRequest(
        workspaceRoot: '/workspace/app',
        paths: <String>['lib/main.dart'],
      ),
    );

    expect(result.command.executable, 'flutter-sdk');
    expect(result.command.arguments, <String>[
      'analyze',
      '--no-pub',
      'lib/main.dart',
    ]);
    expect(result.success, isFalse);
    expect(result.clean, isFalse);
    expect(result.totalDiagnostics, 3);
    expect(result.severityCounts, <String, int>{
      'error': 1,
      'warning': 1,
      'info': 1,
    });
    expect(result.diagnostics[0].code, 'undefined_identifier');
    expect(result.diagnostics[0].line, 3);
    expect(result.diagnostics[0].column, 11);
    expect(result.diagnostics[1].severity, 'warning');
    expect(result.diagnostics[2].severity, 'info');
  });

  test('parses dart analyzer stderr diagnostics with Windows paths', () async {
    final fileSystem = MemoryFileSystem(style: FileSystemStyle.windows);
    fileSystem.file(r'C:\workspace\pkg\pubspec.yaml')
      ..createSync(recursive: true)
      ..writeAsStringSync('name: pkg\n');
    fileSystem.file(r'C:\workspace\pkg\lib\main.dart')
      ..createSync(recursive: true)
      ..writeAsStringSync('void main() {}\n');
    final processManager = _TextAnalyzeFilesProcessManager(
      exitCode: 3,
      stderr: r'''
Analyzing main.dart...

  error - lib\main.dart:2:9 - Undefined name 'missing'. Try correcting the name to one that is defined, or defining the name. - undefined_identifier

1 issue found.
''',
    );
    final service = CockpitAnalyzeFilesService(
      fileSystem: LocalCockpitFileSystem(fileSystem: fileSystem),
      processManager: processManager,
      sdkEnvironment: const CockpitSdkEnvironment(
        dartExecutable: 'dart-sdk',
        flutterExecutable: 'flutter-sdk',
      ),
    );

    final result = await service.analyze(
      const CockpitAnalyzeFilesRequest(
        workspaceRoot: r'C:\workspace\pkg',
        paths: <String>[r'lib\main.dart'],
      ),
    );

    expect(result.command.executable, 'dart-sdk');
    expect(result.command.arguments, <String>['analyze', r'lib\main.dart']);
    expect(result.success, isFalse);
    expect(result.clean, isFalse);
    expect(result.totalDiagnostics, 1);
    expect(result.diagnostics.single.path, r'lib\main.dart');
    expect(result.diagnostics.single.severity, 'error');
    expect(result.diagnostics.single.code, 'undefined_identifier');
    expect(result.diagnostics.single.line, 2);
    expect(result.diagnostics.single.column, 9);
  });

  test('reports clean current flutter analyzer text output', () async {
    final fileSystem = MemoryFileSystem();
    fileSystem.file('/workspace/app/pubspec.yaml')
      ..createSync(recursive: true)
      ..writeAsStringSync('''
name: app
dependencies:
  flutter:
    sdk: flutter
''');
    fileSystem.file('/workspace/app/lib/main.dart')
      ..createSync(recursive: true)
      ..writeAsStringSync('void main() {}\n');
    final processManager = _TextAnalyzeFilesProcessManager(
      stdout: '''
Analyzing main.dart...
No issues found! (ran in 1.1s)
''',
    );
    final service = CockpitAnalyzeFilesService(
      fileSystem: LocalCockpitFileSystem(fileSystem: fileSystem),
      processManager: processManager,
      sdkEnvironment: const CockpitSdkEnvironment(
        dartExecutable: 'dart-sdk',
        flutterExecutable: 'flutter-sdk',
      ),
    );

    final result = await service.analyze(
      const CockpitAnalyzeFilesRequest(
        workspaceRoot: '/workspace/app',
        paths: <String>['lib/main.dart'],
      ),
    );

    expect(result.command.arguments, <String>[
      'analyze',
      '--no-pub',
      'lib/main.dart',
    ]);
    expect(result.success, isTrue);
    expect(result.clean, isTrue);
    expect(result.totalDiagnostics, 0);
    expect(result.summary, 'No analyzer diagnostics.');
  });

  test('rejects missing analysis paths', () async {
    final fileSystem = MemoryFileSystem();
    fileSystem.file('/workspace/pkg/pubspec.yaml')
      ..createSync(recursive: true)
      ..writeAsStringSync('name: pkg\n');

    final service = CockpitAnalyzeFilesService(
      fileSystem: LocalCockpitFileSystem(fileSystem: fileSystem),
      processManager: _RecordingAnalyzeFilesProcessManager(),
    );

    expect(
      () => service.analyze(
        const CockpitAnalyzeFilesRequest(
          workspaceRoot: '/workspace/pkg',
          paths: <String>['lib/missing.dart'],
        ),
      ),
      throwsA(isA<Exception>()),
    );
  });
}

final class _RecordingAnalyzeFilesProcessManager
    implements CockpitProcessManager {
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
    return ProcessResult(
      1,
      2,
      utf8.encode(
        jsonEncode(<String, Object?>{
          'version': 1,
          'diagnostics': <Map<String, Object?>>[
            <String, Object?>{
              'code': 'unused_import',
              'severity': 'WARNING',
              'type': 'STATIC_WARNING',
              'location': <String, Object?>{
                'file': '/workspace/pkg/lib/main.dart',
                'range': <String, Object?>{
                  'start': <String, Object?>{'line': 1, 'column': 8},
                  'end': <String, Object?>{'line': 1, 'column': 18},
                },
              },
              'problemMessage': 'Unused import.',
            },
            <String, Object?>{
              'code': 'dead_code',
              'severity': 'INFO',
              'type': 'HINT',
              'location': <String, Object?>{
                'file': '/workspace/pkg/lib/main.dart',
                'range': <String, Object?>{
                  'start': <String, Object?>{'line': 3, 'column': 3},
                  'end': <String, Object?>{'line': 3, 'column': 9},
                },
              },
              'problemMessage': 'Dead code.',
            },
          ],
        }),
      ),
      utf8.encode(''),
    );
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
  }) async {
    return _CompletedFakeProcess(
      stdout: jsonEncode(<String, Object?>{
        'version': 1,
        'diagnostics': <Map<String, Object?>>[
          <String, Object?>{
            'code': 'unused_import',
            'severity': 'WARNING',
            'type': 'STATIC_WARNING',
            'location': <String, Object?>{
              'file': '/workspace/pkg/lib/main.dart',
              'range': <String, Object?>{
                'start': <String, Object?>{'line': 1, 'column': 8},
                'end': <String, Object?>{'line': 1, 'column': 18},
              },
            },
            'problemMessage': 'Unused import.',
          },
          <String, Object?>{
            'code': 'dead_code',
            'severity': 'INFO',
            'type': 'HINT',
            'location': <String, Object?>{
              'file': '/workspace/pkg/lib/main.dart',
              'range': <String, Object?>{
                'start': <String, Object?>{'line': 3, 'column': 3},
                'end': <String, Object?>{'line': 3, 'column': 9},
              },
            },
            'problemMessage': 'Dead code.',
          },
        ],
      }),
    );
  }
}

final class _TextAnalyzeFilesProcessManager implements CockpitProcessManager {
  _TextAnalyzeFilesProcessManager({
    this.stdout = '',
    this.stderr = '',
    this.exitCode = 0,
  });

  final String stdout;
  final String stderr;
  final int exitCode;

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
    return ProcessResult(1, exitCode, utf8.encode(stdout), utf8.encode(stderr));
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
  }) async {
    return _CompletedFakeProcess(
      stdout: stdout,
      stderr: stderr,
      exitCode: exitCode,
    );
  }
}

final class _CompletedFakeProcess implements Process {
  _CompletedFakeProcess({
    required String stdout,
    String stderr = '',
    int exitCode = 2,
  }) : _exitCode = exitCode,
       _stdout = Stream<List<int>>.value(utf8.encode(stdout)),
       _stderr = Stream<List<int>>.value(utf8.encode(stderr));

  final int _exitCode;
  final Stream<List<int>> _stdout;
  final Stream<List<int>> _stderr;
  final StreamController<List<int>> _stdinController =
      StreamController<List<int>>();
  @override
  Future<int> get exitCode => Future<int>.value(_exitCode);

  @override
  int get pid => 1;

  @override
  IOSink get stdin => IOSink(_stdinController.sink);

  @override
  Stream<List<int>> get stderr => _stderr;

  @override
  Stream<List<int>> get stdout => _stdout;

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    _stdinController.close();
    return true;
  }
}

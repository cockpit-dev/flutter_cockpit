import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file/memory.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_analyze_files_service.dart';
import 'package:flutter_cockpit_devtools/src/infrastructure/cockpit_file_system.dart';
import 'package:flutter_cockpit_devtools/src/infrastructure/cockpit_process_manager.dart';
import 'package:flutter_cockpit_devtools/src/infrastructure/cockpit_sdk_environment.dart';
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
    expect(result.command.arguments, <String>[
      'analyze',
      '--format=json',
      'lib/main.dart',
    ]);
    expect(result.totalDiagnostics, 2);
    expect(result.diagnostics, hasLength(1));
    expect(result.diagnostics.single.path, 'lib/main.dart');
    expect(result.diagnostics.single.severity, 'warning');
    expect(result.diagnosticsTruncated, isTrue);
    expect(result.summary, contains('2 analyzer diagnostics'));
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

final class _CompletedFakeProcess implements Process {
  _CompletedFakeProcess({required String stdout, String stderr = ''})
    : _stdout = Stream<List<int>>.value(utf8.encode(stdout)),
      _stderr = Stream<List<int>>.value(utf8.encode(stderr));

  final Stream<List<int>> _stdout;
  final Stream<List<int>> _stderr;
  final StreamController<List<int>> _stdinController =
      StreamController<List<int>>();
  @override
  Future<int> get exitCode => Future<int>.value(2);

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

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file/memory.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_application_service_exception.dart';
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

  test('kills ripgrep when package URI search times out', () async {
    final fileSystem = MemoryFileSystem();
    _writePackageConfig(fileSystem);
    fileSystem.file('/deps/example_pkg/lib/src/theme_data.dart')
      ..createSync(recursive: true)
      ..writeAsStringSync('class ThemeData {}');
    final processManager = _HangingRipgrepProcessManager();

    final service = CockpitGrepPackageUrisService(
      fileSystem: LocalCockpitFileSystem(fileSystem: fileSystem),
      processManager: processManager,
    );

    await expectLater(
      service.grep(
        const CockpitGrepPackageUrisRequest(
          workspaceRoot: '/workspace',
          packageNames: <String>['example_pkg'],
          query: 'ThemeData',
          timeout: Duration(milliseconds: 20),
        ),
      ),
      throwsA(
        isA<CockpitApplicationServiceException>().having(
          (error) => error.code,
          'code',
          'grepPackageUrisTimedOut',
        ),
      ),
    );
    expect(
      processManager.processes.any(
        (process) => process.killSignals.contains(ProcessSignal.sigkill),
      ),
      isTrue,
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

  ProcessResult _resultFor(List<String> arguments) {
    if (arguments.length == 1 && arguments.single == '--version') {
      return ProcessResult(0, 0, 'ripgrep 14.0.0', '');
    }
    return ProcessResult(0, 0, stdout, '');
  }

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
    return _resultFor(arguments);
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
    final result = _resultFor(arguments);
    return _CompletedRgProcess(
      stdout: '${result.stdout}',
      exitCode: result.exitCode,
    );
  }
}

final class _HangingRipgrepProcessManager implements CockpitProcessManager {
  final List<_HangingRgProcess> processes = <_HangingRgProcess>[];

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
    if (arguments.length == 1 && arguments.single == '--version') {
      return Future<ProcessResult>.value(
        ProcessResult(0, 0, 'ripgrep 14.0.0', ''),
      );
    }
    return Completer<ProcessResult>().future;
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
    if (arguments.length == 1 && arguments.single == '--version') {
      return _CompletedRgProcess(stdout: 'ripgrep 14.0.0');
    }
    final process = _HangingRgProcess();
    processes.add(process);
    return process;
  }
}

final class _CompletedRgProcess implements Process {
  _CompletedRgProcess({required String stdout, int exitCode = 0})
    : _stdout = Stream<List<int>>.value(utf8.encode(stdout)),
      _stderr = const Stream<List<int>>.empty(),
      _exitCode = Future<int>.value(exitCode);

  final Stream<List<int>> _stdout;
  final Stream<List<int>> _stderr;
  final Future<int> _exitCode;

  @override
  Future<int> get exitCode => _exitCode;

  @override
  int get pid => 1;

  @override
  IOSink get stdin => throw UnsupportedError('stdin is not used in tests');

  @override
  Stream<List<int>> get stderr => _stderr;

  @override
  Stream<List<int>> get stdout => _stdout;

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) => true;
}

final class _HangingRgProcess implements Process {
  final StreamController<List<int>> _stdoutController =
      StreamController<List<int>>();
  final StreamController<List<int>> _stderrController =
      StreamController<List<int>>();
  final List<ProcessSignal> killSignals = <ProcessSignal>[];

  @override
  Future<int> get exitCode => Completer<int>().future;

  @override
  int get pid => 1;

  @override
  IOSink get stdin => throw UnsupportedError('stdin is not used in tests');

  @override
  Stream<List<int>> get stderr => _stderrController.stream;

  @override
  Stream<List<int>> get stdout => _stdoutController.stream;

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    killSignals.add(signal);
    if (!_stdoutController.isClosed) {
      unawaited(_stdoutController.close());
    }
    if (!_stderrController.isClosed) {
      unawaited(_stderrController.close());
    }
    return true;
  }
}

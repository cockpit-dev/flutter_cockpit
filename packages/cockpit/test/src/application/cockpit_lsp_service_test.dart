import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file/memory.dart';
import 'package:cockpit/src/application/cockpit_application_service_exception.dart';
import 'package:cockpit/src/application/cockpit_lsp_service.dart';
import 'package:cockpit/src/infrastructure/cockpit_file_system.dart';
import 'package:cockpit/src/infrastructure/cockpit_process_manager.dart';
import 'package:test/test.dart';

void main() {
  test(
    'hover resolves relative paths and converts to 1-based output',
    () async {
      final fileSystem = MemoryFileSystem();
      fileSystem.file('/workspace/pkg/lib/main.dart')
        ..createSync(recursive: true)
        ..writeAsStringSync('void main() {}\n');
      final executor = _FakeLspExecutor(
        response: <String, Object?>{
          'contents': <String, Object?>{
            'kind': 'markdown',
            'value': 'Type: `void Function()`',
          },
          'range': <String, Object?>{
            'start': <String, Object?>{'line': 0, 'character': 0},
            'end': <String, Object?>{'line': 0, 'character': 4},
          },
        },
      );
      final service = CockpitLspService(
        fileSystem: LocalCockpitFileSystem(fileSystem: fileSystem),
        executor: executor,
      );

      final result = await service.invoke(
        const CockpitLspRequest(
          workspaceRoot: '/workspace/pkg',
          command: CockpitLspCommand.hover,
          path: 'lib/main.dart',
          line: 1,
          column: 1,
        ),
      );

      expect(executor.method, 'textDocument/hover');
      expect(executor.documentPath, '/workspace/pkg/lib/main.dart');
      expect(executor.params['position'], <String, Object?>{
        'line': 0,
        'character': 0,
      });
      expect(executor.timeout, isNotNull);
      expect(executor.timeout!, lessThanOrEqualTo(const Duration(seconds: 20)));
      expect(executor.timeout!, greaterThan(const Duration(seconds: 19)));
      expect(result.toJson()['found'], isTrue);
      expect(
        (result.toJson()['range'] as Map<String, Object?>)['startLine'],
        1,
      );
    },
  );

  test('workspace symbols are bounded and normalized', () async {
    final executor = _FakeSequenceLspExecutor(
      responses: <Object?>[
        <Map<String, Object?>>[],
        <Map<String, Object?>>[
          <String, Object?>{
            'name': 'MyWidget',
            'kind': 5,
            'selectionRange': <String, Object?>{
              'start': <String, Object?>{'line': 0, 'character': 6},
              'end': <String, Object?>{'line': 0, 'character': 14},
            },
            'range': <String, Object?>{
              'start': <String, Object?>{'line': 0, 'character': 0},
              'end': <String, Object?>{'line': 0, 'character': 16},
            },
          },
        ],
      ],
    );
    final fileSystem = MemoryFileSystem();
    fileSystem.file('/workspace/pkg/lib/main.dart')
      ..createSync(recursive: true)
      ..writeAsStringSync('class MyWidget {}\n');
    final service = CockpitLspService(
      fileSystem: LocalCockpitFileSystem(fileSystem: fileSystem),
      executor: executor,
    );

    final result = await service.invoke(
      const CockpitLspRequest(
        workspaceRoot: '/workspace/pkg',
        command: CockpitLspCommand.workspaceSymbols,
        query: 'MyWidget',
      ),
    );

    final symbols = result.toJson()['symbols'] as List<Object?>;
    expect(symbols, hasLength(1));
    expect((symbols.single as Map<String, Object?>)['kind'], 'class');
    expect((symbols.single as Map<String, Object?>)['path'], 'lib/main.dart');
    expect(result.toJson()['source'], 'document_symbol_fallback');
  });

  test('hover retries while the file is still being analyzed', () async {
    final fileSystem = MemoryFileSystem();
    fileSystem.file('/workspace/pkg/lib/main.dart')
      ..createSync(recursive: true)
      ..writeAsStringSync('void main() {}\n');
    final executor = _FakeSequenceLspExecutor(
      responses: <Object?>[
        const CockpitApplicationServiceException(
          code: 'lspRequestFailed',
          message: 'LSP request failed.',
          details: <String, Object?>{
            'method': 'textDocument/hover',
            'error':
                'CockpitApplicationServiceException(lspServerError): File is not being analyzed {code: -32007, data: /workspace/pkg/lib/main.dart}',
          },
        ),
        <String, Object?>{
          'contents': <String, Object?>{
            'kind': 'markdown',
            'value': 'Type: `void Function()`',
          },
        },
      ],
    );
    final service = CockpitLspService(
      fileSystem: LocalCockpitFileSystem(fileSystem: fileSystem),
      executor: executor,
    );

    final result = await service.invoke(
      const CockpitLspRequest(
        workspaceRoot: '/workspace/pkg',
        command: CockpitLspCommand.hover,
        path: 'lib/main.dart',
        line: 1,
        column: 1,
        timeout: Duration(seconds: 1),
      ),
    );

    expect(result.toJson()['found'], isTrue);
    expect(executor.calls, 2);
  });

  test(
    'hover reports a bounded analysis timeout when the file never becomes ready',
    () async {
      final fileSystem = MemoryFileSystem();
      fileSystem.file('/workspace/pkg/lib/main.dart')
        ..createSync(recursive: true)
        ..writeAsStringSync('void main() {}\n');
      final executor = _FakeSequenceLspExecutor(
        responses: <Object?>[
          const CockpitApplicationServiceException(
            code: 'lspRequestFailed',
            message: 'LSP request failed.',
            details: <String, Object?>{
              'method': 'textDocument/hover',
              'error':
                  'CockpitApplicationServiceException(lspServerError): File is not being analyzed {code: -32007, data: /workspace/pkg/lib/main.dart}',
            },
          ),
          const CockpitApplicationServiceException(
            code: 'lspRequestFailed',
            message: 'LSP request failed.',
            details: <String, Object?>{
              'method': 'textDocument/hover',
              'error':
                  'CockpitApplicationServiceException(lspServerError): File is not being analyzed {code: -32007, data: /workspace/pkg/lib/main.dart}',
            },
          ),
        ],
      );
      final service = CockpitLspService(
        fileSystem: LocalCockpitFileSystem(fileSystem: fileSystem),
        executor: executor,
        analysisRetryDelay: (_) async {},
      );

      await expectLater(
        () => service.invoke(
          const CockpitLspRequest(
            workspaceRoot: '/workspace/pkg',
            command: CockpitLspCommand.hover,
            path: 'lib/main.dart',
            line: 1,
            column: 1,
            timeout: Duration(milliseconds: 200),
          ),
        ),
        throwsA(
          isA<CockpitApplicationServiceException>().having(
            (error) => error.code,
            'code',
            'lspAnalysisTimedOut',
          ),
        ),
      );
    },
  );

  test(
    'hover does not issue another request when retry delay exhausts the budget',
    () async {
      final fileSystem = MemoryFileSystem();
      fileSystem.file('/workspace/pkg/lib/main.dart')
        ..createSync(recursive: true)
        ..writeAsStringSync('void main() {}\n');
      final executor = _FakeSequenceLspExecutor(
        responses: <Object?>[
          const CockpitApplicationServiceException(
            code: 'lspRequestFailed',
            message: 'LSP request failed.',
            details: <String, Object?>{
              'method': 'textDocument/hover',
              'error':
                  'CockpitApplicationServiceException(lspServerError): File is not being analyzed {code: -32007, data: /workspace/pkg/lib/main.dart}',
            },
          ),
        ],
      );
      final service = CockpitLspService(
        fileSystem: LocalCockpitFileSystem(fileSystem: fileSystem),
        executor: executor,
        analysisRetryDelay: (_) async {},
      );

      await expectLater(
        () => service.invoke(
          const CockpitLspRequest(
            workspaceRoot: '/workspace/pkg',
            command: CockpitLspCommand.hover,
            path: 'lib/main.dart',
            line: 1,
            column: 1,
            timeout: Duration(milliseconds: 100),
          ),
        ),
        throwsA(
          isA<CockpitApplicationServiceException>().having(
            (error) => error.code,
            'code',
            'lspAnalysisTimedOut',
          ),
        ),
      );
      expect(executor.calls, 1);
    },
  );

  test(
    'local LSP executor escalates to SIGKILL when the language server ignores shutdown',
    () async {
      final fileSystem = MemoryFileSystem();
      fileSystem.file('/workspace/pkg/lib/main.dart')
        ..createSync(recursive: true)
        ..writeAsStringSync('void main() {}\n');
      final process = _HangingLspProcess();
      final service = CockpitLspService(
        fileSystem: LocalCockpitFileSystem(fileSystem: fileSystem),
        processManager: _SingleProcessManager(process),
      );

      await expectLater(
        () => service.invoke(
          const CockpitLspRequest(
            workspaceRoot: '/workspace/pkg',
            command: CockpitLspCommand.hover,
            path: 'lib/main.dart',
            line: 1,
            column: 1,
            timeout: Duration(milliseconds: 50),
          ),
        ),
        throwsA(
          isA<CockpitApplicationServiceException>().having(
            (error) => error.code,
            'code',
            'lspRequestTimedOut',
          ),
        ),
      );

      expect(process.killSignals, <ProcessSignal>[
        ProcessSignal.sigterm,
        ProcessSignal.sigkill,
      ]);
    },
  );
}

final class _FakeLspExecutor implements CockpitLspExecutor {
  _FakeLspExecutor({required this.response});

  final Object? response;
  String? method;
  String? documentPath;
  Map<String, Object?> params = const <String, Object?>{};
  Duration? timeout;

  @override
  Future<Object?> request({
    required String workspaceRoot,
    required String? documentPath,
    required String method,
    required Map<String, Object?> params,
    required Duration timeout,
  }) async {
    this.method = method;
    this.documentPath = documentPath;
    this.params = params;
    this.timeout = timeout;
    return response;
  }
}

final class _FakeSequenceLspExecutor implements CockpitLspExecutor {
  _FakeSequenceLspExecutor({required List<Object?> responses})
    : _responses = List<Object?>.from(responses);

  final List<Object?> _responses;
  int calls = 0;

  @override
  Future<Object?> request({
    required String workspaceRoot,
    required String? documentPath,
    required String method,
    required Map<String, Object?> params,
    required Duration timeout,
  }) async {
    calls++;
    if (_responses.isEmpty) {
      throw StateError('No more fake responses.');
    }
    final response = _responses.removeAt(0);
    if (response is Exception) {
      throw response;
    }
    return response;
  }
}

final class _SingleProcessManager implements CockpitProcessManager {
  const _SingleProcessManager(this.process);

  final Process process;

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
    throw UnimplementedError();
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
    return process;
  }
}

final class _HangingLspProcess implements Process {
  final StreamController<List<int>> _stdoutController =
      StreamController<List<int>>();
  final StreamController<List<int>> _stderrController =
      StreamController<List<int>>();
  final StreamController<List<int>> _stdinController =
      StreamController<List<int>>();
  final Completer<int> _exitCodeCompleter = Completer<int>();
  final List<ProcessSignal> killSignals = <ProcessSignal>[];

  late final IOSink _stdin = IOSink(_stdinController.sink);

  @override
  int get pid => 64001;

  @override
  IOSink get stdin => _stdin;

  @override
  Stream<List<int>> get stdout => _stdoutController.stream;

  @override
  Stream<List<int>> get stderr => _stderrController.stream;

  @override
  Future<int> get exitCode => _exitCodeCompleter.future;

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    killSignals.add(signal);
    if (signal == ProcessSignal.sigkill && !_exitCodeCompleter.isCompleted) {
      _exitCodeCompleter.complete(-9);
      unawaited(_stdoutController.close());
      unawaited(_stderrController.close());
      unawaited(_stdinController.close());
    }
    return true;
  }
}

import 'package:file/memory.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_application_service_exception.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_lsp_service.dart';
import 'package:flutter_cockpit_devtools/src/infrastructure/cockpit_file_system.dart';
import 'package:test/test.dart';

void main() {
  test('hover resolves relative paths and converts to 1-based output',
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
    expect((result.toJson()['range'] as Map<String, Object?>)['start_line'], 1);
  });

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
        isA<CockpitApplicationServiceException>()
            .having((error) => error.code, 'code', 'lspAnalysisTimedOut'),
      ),
    );
  });
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

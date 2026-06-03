import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:file/file.dart';
import 'package:path/path.dart' as p;

import '../infrastructure/cockpit_file_system.dart';
import '../infrastructure/cockpit_process_output_collector.dart';
import '../infrastructure/cockpit_process_manager.dart';
import '../infrastructure/cockpit_sdk_environment.dart';
import 'cockpit_application_service_exception.dart';
import 'cockpit_lsp_wire_format.dart';
import 'cockpit_workspace_tooling_support.dart';

enum CockpitLspCommand {
  hover,
  definition,
  signatureHelp,
  documentSymbols,
  workspaceSymbols,
}

final class CockpitLspRequest {
  const CockpitLspRequest({
    required this.workspaceRoot,
    required this.command,
    this.path,
    this.line,
    this.column,
    this.query,
    this.allowedRoots = const <String>[],
    this.maxResults = 20,
    this.maxChars = 1600,
    this.timeout = const Duration(seconds: 20),
  });

  final String workspaceRoot;
  final CockpitLspCommand command;
  final String? path;
  final int? line;
  final int? column;
  final String? query;
  final List<String> allowedRoots;
  final int maxResults;
  final int maxChars;
  final Duration timeout;
}

final class CockpitLspResult {
  const CockpitLspResult({
    required this.command,
    required this.workspaceRoot,
    required this.summary,
    required this.payload,
  });

  final CockpitLspCommand command;
  final String workspaceRoot;
  final String summary;
  final Map<String, Object?> payload;

  Map<String, Object?> toJson() => <String, Object?>{
    'command': _cockpitLspCommandName(command),
    'workspaceRoot': workspaceRoot,
    'summary': summary,
    ...payload,
  };
}

abstract interface class CockpitLspExecutor {
  Future<Object?> request({
    required String workspaceRoot,
    required String? documentPath,
    required String method,
    required Map<String, Object?> params,
    required Duration timeout,
  });
}

final class CockpitLspService {
  CockpitLspService({
    CockpitFileSystem? fileSystem,
    CockpitProcessManager? processManager,
    CockpitSdkEnvironment? sdkEnvironment,
    CockpitLspExecutor? executor,
    Future<void> Function(Duration delay)? analysisRetryDelay,
  }) : _fileSystem = fileSystem ?? const LocalCockpitFileSystem(),
       _analysisRetryDelay =
           analysisRetryDelay ?? ((delay) => Future<void>.delayed(delay)),
       _executor =
           executor ??
           _LocalCockpitLspExecutor(
             fileSystem: fileSystem ?? const LocalCockpitFileSystem(),
             processManager:
                 processManager ?? const LocalCockpitProcessManager(),
             sdkEnvironment: sdkEnvironment ?? CockpitSdkEnvironment.current(),
           );

  final CockpitFileSystem _fileSystem;
  final CockpitLspExecutor _executor;
  final Future<void> Function(Duration delay) _analysisRetryDelay;

  Future<CockpitLspResult> invoke(CockpitLspRequest request) async {
    final workspaceRoot = assertWorkspaceRootAllowed(
      request.workspaceRoot,
      request.allowedRoots,
    );
    return switch (request.command) {
      CockpitLspCommand.hover => _hover(workspaceRoot, request),
      CockpitLspCommand.definition => _definition(workspaceRoot, request),
      CockpitLspCommand.signatureHelp => _signatureHelp(workspaceRoot, request),
      CockpitLspCommand.documentSymbols => _documentSymbols(
        workspaceRoot,
        request,
      ),
      CockpitLspCommand.workspaceSymbols => _workspaceSymbols(
        workspaceRoot,
        request,
      ),
    };
  }

  Future<CockpitLspResult> _hover(
    String workspaceRoot,
    CockpitLspRequest request,
  ) async {
    final documentPath = _resolveDocumentPath(workspaceRoot, request.path);
    final position = _position(request);
    final response = await _requestWithAnalysisRetry(
      workspaceRoot: workspaceRoot,
      documentPath: documentPath,
      method: 'textDocument/hover',
      params: <String, Object?>{
        'textDocument': <String, Object?>{
          'uri': Uri.file(documentPath).toString(),
        },
        'position': position,
      },
      timeout: request.timeout,
    );
    final json = response is Map<Object?, Object?>
        ? Map<Object?, Object?>.from(response)
        : const <Object?, Object?>{};
    final contents = _truncateText(
      _hoverContents(json['contents']),
      request.maxChars,
    );
    final range = _rangeToJson(json['range']);
    return CockpitLspResult(
      command: request.command,
      workspaceRoot: workspaceRoot,
      summary: contents == null
          ? 'No hover information.'
          : 'Hover information found.',
      payload: <String, Object?>{
        'path': p.relative(documentPath, from: workspaceRoot),
        'line': request.line!,
        'column': request.column!,
        'found': contents != null,
        'contents': ?contents,
        'range': ?range,
      },
    );
  }

  Future<CockpitLspResult> _definition(
    String workspaceRoot,
    CockpitLspRequest request,
  ) async {
    final documentPath = _resolveDocumentPath(workspaceRoot, request.path);
    final response = await _requestWithAnalysisRetry(
      workspaceRoot: workspaceRoot,
      documentPath: documentPath,
      method: 'textDocument/definition',
      params: <String, Object?>{
        'textDocument': <String, Object?>{
          'uri': Uri.file(documentPath).toString(),
        },
        'position': _position(request),
      },
      timeout: request.timeout,
    );
    final definitions = _definitionLocations(
      response,
      workspaceRoot: workspaceRoot,
      maxResults: request.maxResults,
    );
    return CockpitLspResult(
      command: request.command,
      workspaceRoot: workspaceRoot,
      summary: definitions.isEmpty
          ? 'No definitions found.'
          : '${definitions.length} definition locations found.',
      payload: <String, Object?>{
        'path': p.relative(documentPath, from: workspaceRoot),
        'line': request.line!,
        'column': request.column!,
        'definitionCount': definitions.length,
        'definitions': definitions,
      },
    );
  }

  Future<CockpitLspResult> _signatureHelp(
    String workspaceRoot,
    CockpitLspRequest request,
  ) async {
    final documentPath = _resolveDocumentPath(workspaceRoot, request.path);
    final response = await _requestWithAnalysisRetry(
      workspaceRoot: workspaceRoot,
      documentPath: documentPath,
      method: 'textDocument/signatureHelp',
      params: <String, Object?>{
        'textDocument': <String, Object?>{
          'uri': Uri.file(documentPath).toString(),
        },
        'position': _position(request),
      },
      timeout: request.timeout,
    );
    final json = response is Map<Object?, Object?>
        ? Map<Object?, Object?>.from(response)
        : const <Object?, Object?>{};
    final signatures = ((json['signatures'] as List?) ?? const [])
        .whereType<Map<Object?, Object?>>()
        .take(request.maxResults)
        .map(
          (signature) => <String, Object?>{
            'label': '${signature['label'] ?? ''}',
            'documentation': _truncateText(
              _markupText(signature['documentation']),
              request.maxChars,
            ),
            'parameters': ((signature['parameters'] as List?) ?? const [])
                .whereType<Map<Object?, Object?>>()
                .map(
                  (parameter) => <String, Object?>{
                    'label': '${parameter['label'] ?? ''}',
                    'documentation': _truncateText(
                      _markupText(parameter['documentation']),
                      request.maxChars,
                    ),
                  },
                )
                .toList(growable: false),
          },
        )
        .toList(growable: false);
    return CockpitLspResult(
      command: request.command,
      workspaceRoot: workspaceRoot,
      summary: signatures.isEmpty
          ? 'No signature help available.'
          : '${signatures.length} signatures available.',
      payload: <String, Object?>{
        'path': p.relative(documentPath, from: workspaceRoot),
        'line': request.line!,
        'column': request.column!,
        'activeSignature': json['activeSignature'] as int?,
        'activeParameter': json['activeParameter'] as int?,
        'signatures': signatures,
      },
    );
  }

  Future<CockpitLspResult> _documentSymbols(
    String workspaceRoot,
    CockpitLspRequest request,
  ) async {
    final documentPath = _resolveDocumentPath(workspaceRoot, request.path);
    final response = await _requestWithAnalysisRetry(
      workspaceRoot: workspaceRoot,
      documentPath: documentPath,
      method: 'textDocument/documentSymbol',
      params: <String, Object?>{
        'textDocument': <String, Object?>{
          'uri': Uri.file(documentPath).toString(),
        },
      },
      timeout: request.timeout,
    );
    final symbols = _documentSymbolResults(
      response,
      workspaceRoot: workspaceRoot,
      defaultPath: documentPath,
      maxResults: request.maxResults,
      maxChars: request.maxChars,
    );
    return CockpitLspResult(
      command: request.command,
      workspaceRoot: workspaceRoot,
      summary: symbols.isEmpty
          ? 'No document symbols found.'
          : '${symbols.length} document symbols found.',
      payload: <String, Object?>{
        'path': p.relative(documentPath, from: workspaceRoot),
        'symbolCount': symbols.length,
        'symbols': symbols,
      },
    );
  }

  Future<Object?> _requestWithAnalysisRetry({
    required String workspaceRoot,
    required String documentPath,
    required String method,
    required Map<String, Object?> params,
    required Duration timeout,
  }) async {
    final stopwatch = Stopwatch()..start();
    CockpitApplicationServiceException? lastRetryableError;
    for (var attempt = 0; ; attempt++) {
      final remaining = timeout - stopwatch.elapsed;
      if (remaining <= Duration.zero) {
        _throwAnalysisTimedOut(
          workspaceRoot: workspaceRoot,
          documentPath: documentPath,
          method: method,
          timeout: timeout,
          lastRetryableError: lastRetryableError,
        );
      }
      try {
        return await _executor.request(
          workspaceRoot: workspaceRoot,
          documentPath: documentPath,
          method: method,
          params: params,
          timeout: remaining,
        );
      } on CockpitApplicationServiceException catch (error) {
        if (!_isRetryableAnalysisPendingError(error)) {
          rethrow;
        }
        lastRetryableError = error;
      }

      final retryRemaining = timeout - stopwatch.elapsed;
      if (retryRemaining <= Duration.zero) {
        _throwAnalysisTimedOut(
          workspaceRoot: workspaceRoot,
          documentPath: documentPath,
          method: method,
          timeout: timeout,
          lastRetryableError: lastRetryableError,
        );
      }
      final delay = Duration(milliseconds: math.min(1000, 150 * (attempt + 1)));
      if (delay >= retryRemaining) {
        await _analysisRetryDelay(retryRemaining);
        _throwAnalysisTimedOut(
          workspaceRoot: workspaceRoot,
          documentPath: documentPath,
          method: method,
          timeout: timeout,
          lastRetryableError: lastRetryableError,
        );
      }
      final boundedDelay = delay < retryRemaining ? delay : retryRemaining;
      if (boundedDelay > Duration.zero) {
        await _analysisRetryDelay(boundedDelay);
      }
    }
  }

  Never _throwAnalysisTimedOut({
    required String workspaceRoot,
    required String documentPath,
    required String method,
    required Duration timeout,
    required CockpitApplicationServiceException? lastRetryableError,
  }) {
    throw CockpitApplicationServiceException(
      code: 'lspAnalysisTimedOut',
      message: 'LSP document analysis did not become ready before timeout.',
      details: <String, Object?>{
        'method': method,
        'path': p.relative(documentPath, from: workspaceRoot),
        'timeoutMs': timeout.inMilliseconds,
        if (lastRetryableError != null)
          'lastError': lastRetryableError.toString(),
      },
    );
  }

  Future<CockpitLspResult> _workspaceSymbols(
    String workspaceRoot,
    CockpitLspRequest request,
  ) async {
    final query = request.query?.trim();
    if (query == null || query.isEmpty) {
      throw const CockpitApplicationServiceException(
        code: 'lspQueryRequired',
        message: 'query is required for workspace_symbols.',
      );
    }
    final response = await _executor.request(
      workspaceRoot: workspaceRoot,
      documentPath: null,
      method: 'workspace/symbol',
      params: <String, Object?>{'query': query},
      timeout: request.timeout,
    );
    final directSymbols = _workspaceSymbolResults(
      response,
      workspaceRoot: workspaceRoot,
      maxResults: request.maxResults,
      maxChars: request.maxChars,
    );
    final symbols = directSymbols.isNotEmpty
        ? directSymbols
        : await _workspaceSymbolFallback(
            workspaceRoot: workspaceRoot,
            query: query,
            maxResults: request.maxResults,
            maxChars: request.maxChars,
            timeout: request.timeout,
          );
    return CockpitLspResult(
      command: request.command,
      workspaceRoot: workspaceRoot,
      summary: symbols.isEmpty
          ? 'No workspace symbols found.'
          : '${symbols.length} workspace symbols found.',
      payload: <String, Object?>{
        'query': query,
        'source': directSymbols.isNotEmpty
            ? 'workspaceSymbol'
            : 'document_symbol_fallback',
        'symbolCount': symbols.length,
        'symbols': symbols,
      },
    );
  }

  String _resolveDocumentPath(String workspaceRoot, String? rawPath) {
    if (rawPath == null || rawPath.isEmpty) {
      throw const CockpitApplicationServiceException(
        code: 'lspPathRequired',
        message: 'path is required for this lsp command.',
      );
    }
    final candidate = p.normalize(
      p.isAbsolute(rawPath) ? rawPath : p.join(workspaceRoot, rawPath),
    );
    assertWorkspaceRootAllowed(candidate, <String>[workspaceRoot]);
    final file = _fileSystem.file(candidate);
    if (!file.existsSync()) {
      throw CockpitApplicationServiceException(
        code: 'lspPathNotFound',
        message: 'path does not exist.',
        details: <String, Object?>{'path': rawPath, 'resolvedPath': candidate},
      );
    }
    return candidate;
  }

  Map<String, Object?> _position(CockpitLspRequest request) {
    final line = request.line;
    final column = request.column;
    if (line == null || column == null || line < 1 || column < 1) {
      throw const CockpitApplicationServiceException(
        code: 'lspPositionRequired',
        message: 'line and column must both be 1-based integers.',
      );
    }
    return <String, Object?>{'line': line - 1, 'character': column - 1};
  }

  Future<List<Map<String, Object?>>> _workspaceSymbolFallback({
    required String workspaceRoot,
    required String query,
    required int maxResults,
    required int maxChars,
    required Duration timeout,
  }) async {
    final matches = <Map<String, Object?>>[];
    for (final path in _candidateWorkspaceDartFiles(
      workspaceRoot: workspaceRoot,
      query: query,
    )) {
      final response = await _executor.request(
        workspaceRoot: workspaceRoot,
        documentPath: path,
        method: 'textDocument/documentSymbol',
        params: <String, Object?>{
          'textDocument': <String, Object?>{'uri': Uri.file(path).toString()},
        },
        timeout: timeout,
      );
      final symbols = _documentSymbolResults(
        response,
        workspaceRoot: workspaceRoot,
        defaultPath: path,
        maxResults: maxResults,
        maxChars: maxChars,
      );
      for (final symbol in symbols) {
        final name = '${symbol['name'] ?? ''}'.toLowerCase();
        final container = '${symbol['container_name'] ?? ''}'.toLowerCase();
        if (!name.contains(query.toLowerCase()) &&
            !container.contains(query.toLowerCase())) {
          continue;
        }
        matches.add(symbol);
        if (matches.length >= maxResults) {
          return matches;
        }
      }
    }
    return matches;
  }

  List<String> _candidateWorkspaceDartFiles({
    required String workspaceRoot,
    required String query,
  }) {
    final root = _fileSystem.directory(workspaceRoot);
    if (!root.existsSync()) {
      return const <String>[];
    }
    final queryText = query.toLowerCase();
    final entries =
        root
            .listSync(recursive: true, followLinks: false)
            .whereType<File>()
            .map((file) => file.path)
            .where((path) => p.extension(path) == '.dart')
            .where((path) => !_excludedWorkspacePath(path))
            .toList(growable: false)
          ..sort((left, right) {
            final leftScore = _workspacePathPriority(left);
            final rightScore = _workspacePathPriority(right);
            if (leftScore != rightScore) {
              return leftScore.compareTo(rightScore);
            }
            return left.compareTo(right);
          });
    final matched = <String>[];
    for (final path in entries) {
      final text = _fileSystem.file(path).readAsStringSync().toLowerCase();
      if (!text.contains(queryText)) {
        continue;
      }
      matched.add(path);
      if (matched.length >= 30) {
        return matched;
      }
    }
    return entries.take(20).toList(growable: false);
  }

  bool _excludedWorkspacePath(String path) {
    final parts = p.split(path);
    return parts.contains('.dart_tool') ||
        parts.contains('build') ||
        parts.contains('.symlinks');
  }

  int _workspacePathPriority(String path) {
    final normalized = p.normalize(path);
    if (normalized.contains('${p.separator}lib${p.separator}')) {
      return 0;
    }
    if (normalized.contains('${p.separator}bin${p.separator}')) {
      return 1;
    }
    if (normalized.contains('${p.separator}test${p.separator}')) {
      return 2;
    }
    return 3;
  }
}

bool _isRetryableAnalysisPendingError(
  CockpitApplicationServiceException error,
) {
  final explicitCode = error.details['code'];
  if (explicitCode == -32007) {
    return true;
  }
  final combined = <String>[
    error.code,
    error.message,
    '${error.details['error'] ?? ''}',
    '${error.details['data'] ?? ''}',
  ].join('\n').toLowerCase();
  return combined.contains('file is not being analyzed') ||
      combined.contains('code: -32007');
}

final class _LocalCockpitLspExecutor implements CockpitLspExecutor {
  const _LocalCockpitLspExecutor({
    required this.fileSystem,
    required this.processManager,
    required this.sdkEnvironment,
  });

  final CockpitFileSystem fileSystem;
  final CockpitProcessManager processManager;
  final CockpitSdkEnvironment sdkEnvironment;

  @override
  Future<Object?> request({
    required String workspaceRoot,
    required String? documentPath,
    required String method,
    required Map<String, Object?> params,
    required Duration timeout,
  }) async {
    final process = await processManager.start(
      sdkEnvironment.dartExecutable,
      const <String>['language-server', '--protocol', 'lsp'],
      workingDirectory: workspaceRoot,
    );
    final stderrCollector = CockpitProcessOutputCollector(process.stderr);
    final channel = cockpitLspChannel(process.stdout, process.stdin);
    final client = _OneShotCockpitLspClient(
      input: channel.stream,
      output: channel.sink,
    );
    try {
      final result = await (() async {
        await client.initialize(workspaceRoot: workspaceRoot);
        if (documentPath != null) {
          final text = fileSystem.file(documentPath).readAsStringSync();
          await client.openDocument(path: documentPath, text: text);
        }
        final response = method == 'workspace/symbol'
            ? await client.requestWorkspaceSymbols(params: params)
            : await client.request(method: method, params: params);
        await client.shutdown();
        return response;
      })().timeout(timeout);
      return result;
    } on TimeoutException {
      final stderr = await stderrCollector.collectText();
      throw CockpitApplicationServiceException(
        code: 'lspRequestTimedOut',
        message: 'LSP request timed out.',
        details: <String, Object?>{
          'method': method,
          'timeoutMs': timeout.inMilliseconds,
          if (stderr.trim().isNotEmpty) 'stderr': _truncateText(stderr, 1200),
        },
      );
    } on Object catch (error) {
      final stderr = await stderrCollector.collectText();
      throw CockpitApplicationServiceException(
        code: 'lspRequestFailed',
        message: 'LSP request failed.',
        details: <String, Object?>{
          'method': method,
          'error': error.toString(),
          if (stderr.trim().isNotEmpty) 'stderr': _truncateText(stderr, 1200),
        },
      );
    } finally {
      await _closeLspClientWithinTimeout(client);
      await _terminateLspProcess(process);
      await _closeLspClientWithinTimeout(client);
      await stderrCollector.cancel();
    }
  }

  Future<void> _closeLspClientWithinTimeout(
    _OneShotCockpitLspClient client,
  ) async {
    try {
      await client.dispose().timeout(const Duration(milliseconds: 200));
    } on Object {
      // LSP stream shutdown is best-effort; process termination below is the
      // authority for short-command cleanup.
    }
  }

  Future<void> _terminateLspProcess(Process process) async {
    if (process.pid == 0) {
      return;
    }
    try {
      process.kill(ProcessSignal.sigterm);
    } on Object {
      // The process may already be gone.
    }
    final exitedAfterTerm = await _waitForLspExit(
      process,
      timeout: const Duration(milliseconds: 500),
    );
    if (exitedAfterTerm) {
      return;
    }
    try {
      process.kill(ProcessSignal.sigkill);
    } on Object {
      // The process may already be gone.
    }
    await _waitForLspExit(process, timeout: const Duration(seconds: 2));
  }

  Future<bool> _waitForLspExit(
    Process process, {
    required Duration timeout,
  }) async {
    try {
      await process.exitCode.timeout(timeout);
      return true;
    } on Object {
      return false;
    }
  }
}

final class _OneShotCockpitLspClient {
  _OneShotCockpitLspClient({
    required Stream<String> input,
    required StreamSink<String> output,
  }) : _messages = StreamIterator<String>(input),
       _output = output;

  final StreamIterator<String> _messages;
  final StreamSink<String> _output;
  int _nextId = 1;
  bool _disposed = false;

  Future<void> initialize({required String workspaceRoot}) async {
    await request(
      method: 'initialize',
      params: <String, Object?>{
        'processId': pid,
        'rootUri': Uri.directory(workspaceRoot).toString(),
        'capabilities': <String, Object?>{
          'workspace': <String, Object?>{'workspaceFolders': true},
        },
        'workspaceFolders': <Map<String, Object?>>[
          <String, Object?>{
            'uri': Uri.directory(workspaceRoot).toString(),
            'name': p.basename(workspaceRoot),
          },
        ],
      },
    );
    notify('initialized', const <String, Object?>{});
  }

  Future<void> openDocument({
    required String path,
    required String text,
  }) async {
    notify('textDocument/didOpen', <String, Object?>{
      'textDocument': <String, Object?>{
        'uri': Uri.file(path).toString(),
        'languageId': 'dart',
        'version': 1,
        'text': text,
      },
    });
  }

  Future<Object?> request({
    required String method,
    required Map<String, Object?> params,
  }) async {
    final id = _nextId++;
    _output.add(
      jsonEncode(<String, Object?>{
        'jsonrpc': '2.0',
        'id': id,
        'method': method,
        'params': params,
      }),
    );
    while (await _messages.moveNext()) {
      final message = jsonDecode(_messages.current) as Map<Object?, Object?>;
      if (message['id'] != id) {
        continue;
      }
      if (message['error'] case final Map<Object?, Object?> error) {
        throw CockpitApplicationServiceException(
          code: 'lspServerError',
          message: '${error['message'] ?? 'LSP server error.'}',
          details: <String, Object?>{
            'code': error['code'],
            if (error['data'] != null) 'data': error['data'],
          },
        );
      }
      return message['result'];
    }
    throw const CockpitApplicationServiceException(
      code: 'lspServerClosed',
      message: 'LSP server closed before returning a response.',
    );
  }

  Future<Object?> requestWorkspaceSymbols({
    required Map<String, Object?> params,
  }) async {
    Object? result;
    await Future<void>.delayed(const Duration(milliseconds: 400));
    for (var attempt = 0; attempt < 15; attempt++) {
      result = await request(method: 'workspace/symbol', params: params);
      if (_workspaceSymbolCount(result) > 0) {
        return result;
      }
      await Future<void>.delayed(Duration(milliseconds: 250 * (attempt + 1)));
    }
    return result;
  }

  void notify(String method, Map<String, Object?> params) {
    _output.add(
      jsonEncode(<String, Object?>{
        'jsonrpc': '2.0',
        'method': method,
        'params': params,
      }),
    );
  }

  Future<void> shutdown() async {
    try {
      await request(method: 'shutdown', params: const <String, Object?>{});
    } on Object {
      return;
    } finally {
      notify('exit', const <String, Object?>{});
    }
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await _messages.cancel();
    await _output.close();
  }
}

String _cockpitLspCommandName(CockpitLspCommand command) {
  return switch (command) {
    CockpitLspCommand.hover => 'hover',
    CockpitLspCommand.definition => 'definition',
    CockpitLspCommand.signatureHelp => 'signature_help',
    CockpitLspCommand.documentSymbols => 'document_symbols',
    CockpitLspCommand.workspaceSymbols => 'workspace_symbols',
  };
}

int _workspaceSymbolCount(Object? raw) {
  if (raw is! List) {
    return 0;
  }
  return raw.length;
}

String? _hoverContents(Object? raw) {
  if (raw == null) {
    return null;
  }
  if (raw is String) {
    return raw.trim().isEmpty ? null : raw.trim();
  }
  if (raw is Map<Object?, Object?>) {
    if (raw['value'] case final String value) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    if (raw['language'] case final String language) {
      final value = '${raw['value'] ?? ''}'.trim();
      if (value.isEmpty) {
        return null;
      }
      return '```$language\n$value\n```';
    }
  }
  if (raw is List<Object?>) {
    final parts = raw
        .map(_hoverContents)
        .whereType<String>()
        .where((item) => item.trim().isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) {
      return null;
    }
    return parts.join('\n\n');
  }
  return '$raw'.trim().isEmpty ? null : '$raw'.trim();
}

String? _markupText(Object? raw) {
  if (raw == null) {
    return null;
  }
  if (raw is String) {
    final trimmed = raw.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
  if (raw is Map<Object?, Object?>) {
    final value = '${raw['value'] ?? ''}'.trim();
    return value.isEmpty ? null : value;
  }
  return '$raw'.trim().isEmpty ? null : '$raw'.trim();
}

Map<String, Object?>? _rangeToJson(Object? raw) {
  if (raw is! Map<Object?, Object?>) {
    return null;
  }
  final start = Map<Object?, Object?>.from(
    raw['start'] as Map<Object?, Object?>? ?? const {},
  );
  final end = Map<Object?, Object?>.from(
    raw['end'] as Map<Object?, Object?>? ?? const {},
  );
  return <String, Object?>{
    'startLine': (start['line'] as int? ?? 0) + 1,
    'startColumn': (start['character'] as int? ?? 0) + 1,
    'endLine': (end['line'] as int? ?? 0) + 1,
    'endColumn': (end['character'] as int? ?? 0) + 1,
  };
}

List<Map<String, Object?>> _definitionLocations(
  Object? raw, {
  required String workspaceRoot,
  required int maxResults,
}) {
  final items = switch (raw) {
    List<Object?> value => value,
    Map<Object?, Object?> value => <Object?>[value],
    _ => const <Object?>[],
  };
  return items
      .whereType<Map<Object?, Object?>>()
      .take(maxResults)
      .map((item) => _definitionLocation(item, workspaceRoot: workspaceRoot))
      .whereType<Map<String, Object?>>()
      .toList(growable: false);
}

Map<String, Object?>? _definitionLocation(
  Map<Object?, Object?> json, {
  required String workspaceRoot,
}) {
  final uriValue = json['uri'] ?? json['targetUri'];
  if (uriValue is! String) {
    return null;
  }
  final rangeRaw =
      json['range'] ?? json['targetSelectionRange'] ?? json['targetRange'];
  final range = _rangeToJson(rangeRaw);
  final path = p.relative(
    Uri.parse(uriValue).toFilePath(),
    from: workspaceRoot,
  );
  return <String, Object?>{'path': path, ...?range};
}

List<Map<String, Object?>> _documentSymbolResults(
  Object? raw, {
  required String workspaceRoot,
  required String defaultPath,
  required int maxResults,
  required int maxChars,
}) {
  final items = <Map<String, Object?>>[];

  void addDocumentSymbol(Map<Object?, Object?> json, {String? containerName}) {
    if (items.length >= maxResults) {
      return;
    }
    final range = _rangeToJson(json['selectionRange'] ?? json['range']);
    items.add(<String, Object?>{
      'name': '${json['name'] ?? ''}',
      'kind': _symbolKindName(json['kind'] as int?),
      'containerName': ?containerName,
      if (json['detail'] case final String detail when detail.trim().isNotEmpty)
        'detail': _truncateText(detail, maxChars),
      'path': p.relative(defaultPath, from: workspaceRoot),
      ...?range,
    });
    for (final child
        in ((json['children'] as List?) ?? const <Object?>[])
            .whereType<Map<Object?, Object?>>()) {
      addDocumentSymbol(
        child,
        containerName: _joinContainerName(
          containerName,
          '${json['name'] ?? ''}',
        ),
      );
    }
  }

  for (final item
      in (raw as List? ?? const <Object?>[])
          .whereType<Map<Object?, Object?>>()) {
    if (item.containsKey('location')) {
      if (items.length >= maxResults) {
        break;
      }
      final location = Map<Object?, Object?>.from(
        item['location'] as Map<Object?, Object?>? ?? const {},
      );
      final uri = location['uri'] as String?;
      final range = _rangeToJson(location['range']);
      items.add(<String, Object?>{
        'name': '${item['name'] ?? ''}',
        'kind': _symbolKindName(item['kind'] as int?),
        if (item['containerName'] case final String containerName
            when containerName.trim().isNotEmpty)
          'containerName': containerName,
        'path': uri == null
            ? p.relative(defaultPath, from: workspaceRoot)
            : p.relative(Uri.parse(uri).toFilePath(), from: workspaceRoot),
        ...?range,
      });
    } else {
      addDocumentSymbol(item);
    }
  }
  return items;
}

List<Map<String, Object?>> _workspaceSymbolResults(
  Object? raw, {
  required String workspaceRoot,
  required int maxResults,
  required int maxChars,
}) {
  return (raw as List? ?? const <Object?>[])
      .whereType<Map<Object?, Object?>>()
      .take(maxResults)
      .map((item) {
        final location = Map<Object?, Object?>.from(
          item['location'] as Map<Object?, Object?>? ?? const {},
        );
        final uri = location['uri'] as String?;
        final range = _rangeToJson(location['range']);
        return <String, Object?>{
          'name': '${item['name'] ?? ''}',
          'kind': _symbolKindName(item['kind'] as int?),
          if (item['containerName'] case final String containerName
              when containerName.trim().isNotEmpty)
            'containerName': containerName,
          if (item['deprecated'] case final bool deprecated)
            'deprecated': deprecated,
          if (uri != null)
            'path': p.relative(
              Uri.parse(uri).toFilePath(),
              from: workspaceRoot,
            ),
          ...?range,
          if (item['detail'] case final String detail
              when detail.trim().isNotEmpty)
            'detail': _truncateText(detail, maxChars),
        };
      })
      .toList(growable: false);
}

String _symbolKindName(int? kind) {
  return switch (kind) {
    1 => 'file',
    2 => 'module',
    3 => 'namespace',
    4 => 'package',
    5 => 'class',
    6 => 'method',
    7 => 'property',
    8 => 'field',
    9 => 'constructor',
    10 => 'enum',
    11 => 'interface',
    12 => 'function',
    13 => 'variable',
    14 => 'constant',
    15 => 'string',
    16 => 'number',
    17 => 'boolean',
    18 => 'array',
    19 => 'object',
    20 => 'key',
    21 => 'null',
    22 => 'enum_member',
    23 => 'struct',
    24 => 'event',
    25 => 'operator',
    26 => 'type_parameter',
    _ => 'unknown',
  };
}

String _joinContainerName(String? prefix, String name) {
  if (prefix == null || prefix.isEmpty) {
    return name;
  }
  return '$prefix > $name';
}

String? _truncateText(String? value, int maxChars) {
  if (value == null) {
    return null;
  }
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  if (trimmed.length <= maxChars) {
    return trimmed;
  }
  final safeMax = maxChars < 1 ? 1 : maxChars;
  return '${trimmed.substring(0, safeMax).trimRight()}...';
}

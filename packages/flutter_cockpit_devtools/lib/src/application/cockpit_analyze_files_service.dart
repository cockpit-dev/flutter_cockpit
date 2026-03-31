import 'dart:convert';

import 'package:path/path.dart' as p;

import '../infrastructure/cockpit_file_system.dart';
import '../infrastructure/cockpit_process_manager.dart';
import '../infrastructure/cockpit_sdk_environment.dart';
import 'cockpit_application_service_exception.dart';
import 'cockpit_workspace_command_result.dart';
import 'cockpit_workspace_tooling_support.dart';

final class CockpitAnalyzeFilesRequest {
  const CockpitAnalyzeFilesRequest({
    required this.workspaceRoot,
    required this.paths,
    this.allowedRoots = const <String>[],
    this.maxDiagnostics = 50,
    this.maxOutputChars = 1600,
    this.timeout = const Duration(minutes: 2),
  });

  final String workspaceRoot;
  final List<String> paths;
  final List<String> allowedRoots;
  final int maxDiagnostics;
  final int maxOutputChars;
  final Duration timeout;
}

final class CockpitAnalyzeFilesDiagnostic {
  const CockpitAnalyzeFilesDiagnostic({
    required this.path,
    required this.severity,
    required this.type,
    required this.code,
    required this.message,
    required this.line,
    required this.column,
    required this.endLine,
    required this.endColumn,
    this.correction,
    this.documentationUrl,
  });

  final String path;
  final String severity;
  final String type;
  final String code;
  final String message;
  final int line;
  final int column;
  final int endLine;
  final int endColumn;
  final String? correction;
  final String? documentationUrl;

  Map<String, Object?> toJson() => <String, Object?>{
        'path': path,
        'severity': severity,
        'type': type,
        'code': code,
        'message': message,
        'line': line,
        'column': column,
        'end_line': endLine,
        'end_column': endColumn,
        if (correction != null) 'correction': correction,
        if (documentationUrl != null) 'documentation_url': documentationUrl,
      };
}

final class CockpitAnalyzeFilesResult {
  const CockpitAnalyzeFilesResult({
    required this.workspaceRoot,
    required this.toolchain,
    required this.paths,
    required this.command,
    required this.exitCode,
    required this.success,
    required this.clean,
    required this.summary,
    required this.totalDiagnostics,
    required this.diagnostics,
    required this.diagnosticsTruncated,
    required this.severityCounts,
    this.stdoutPreview,
    this.stdoutTruncated = false,
    this.stderrPreview,
    this.stderrTruncated = false,
  });

  final String workspaceRoot;
  final CockpitWorkspaceToolchain toolchain;
  final List<String> paths;
  final CockpitWorkspaceCommand command;
  final int exitCode;
  final bool success;
  final bool clean;
  final String summary;
  final int totalDiagnostics;
  final List<CockpitAnalyzeFilesDiagnostic> diagnostics;
  final bool diagnosticsTruncated;
  final Map<String, int> severityCounts;
  final String? stdoutPreview;
  final bool stdoutTruncated;
  final String? stderrPreview;
  final bool stderrTruncated;

  Map<String, Object?> toJson() => <String, Object?>{
        'workspace_root': workspaceRoot,
        'toolchain': toolchain.name,
        'paths': paths,
        'command': command.toJson(),
        'exit_code': exitCode,
        'success': success,
        'clean': clean,
        'summary': summary,
        'total_diagnostics': totalDiagnostics,
        'diagnostics': diagnostics.map((item) => item.toJson()).toList(),
        'diagnostics_truncated': diagnosticsTruncated,
        'severity_counts': severityCounts,
        if (stdoutPreview != null) 'stdout_preview': stdoutPreview,
        'stdout_truncated': stdoutTruncated,
        if (stderrPreview != null) 'stderr_preview': stderrPreview,
        'stderr_truncated': stderrTruncated,
      };
}

final class CockpitAnalyzeFilesService {
  CockpitAnalyzeFilesService({
    CockpitFileSystem? fileSystem,
    CockpitProcessManager? processManager,
    CockpitSdkEnvironment? sdkEnvironment,
  })  : _fileSystem = fileSystem ?? const LocalCockpitFileSystem(),
        _processManager = processManager ?? const LocalCockpitProcessManager(),
        _sdkEnvironment = sdkEnvironment ?? const CockpitSdkEnvironment();

  final CockpitFileSystem _fileSystem;
  final CockpitProcessManager _processManager;
  final CockpitSdkEnvironment _sdkEnvironment;

  Future<CockpitAnalyzeFilesResult> analyze(
    CockpitAnalyzeFilesRequest request,
  ) async {
    if (request.paths.isEmpty) {
      throw const CockpitApplicationServiceException(
        code: 'analysisPathsRequired',
        message: 'paths must contain at least one file or directory.',
      );
    }

    final workspaceRoot = assertWorkspaceRootAllowed(
      request.workspaceRoot,
      request.allowedRoots,
    );
    final resolvedPaths = request.paths
        .map((path) => _resolveWorkspacePath(workspaceRoot, path))
        .toList(growable: false);
    final relativePaths = resolvedPaths
        .map((path) => p.relative(path, from: workspaceRoot))
        .toList(growable: false);
    final toolchain = detectWorkspaceToolchain(_fileSystem, workspaceRoot);
    final executable = toolchain == CockpitWorkspaceToolchain.flutter
        ? _sdkEnvironment.flutterExecutable
        : _sdkEnvironment.dartExecutable;
    final arguments = <String>['analyze', '--format=json', ...relativePaths];
    final commandResult = await runWorkspaceProcess(
      processManager: _processManager,
      executable: executable,
      arguments: arguments,
      workingDirectory: workspaceRoot,
      timeout: request.timeout,
    );
    final stdout = commandResult.stdout;
    final stderr = commandResult.stderr;
    final rawJson = _pickAnalyzerJson(stdout, stderr);
    final decoded = jsonDecode(rawJson) as Map<Object?, Object?>;
    final allDiagnostics = ((decoded['diagnostics'] as List?) ?? const [])
        .whereType<Map<Object?, Object?>>()
        .map(
          (item) => _diagnosticFromJson(
            item,
            workspaceRoot: workspaceRoot,
          ),
        )
        .toList(growable: false);
    final displayedDiagnostics =
        allDiagnostics.take(request.maxDiagnostics).toList(growable: false);
    final severityCounts = <String, int>{};
    for (final diagnostic in allDiagnostics) {
      severityCounts.update(
        diagnostic.severity,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }
    final stdoutExcerpt = _analyzerExcerpt(
      stdout,
      maxChars: request.maxOutputChars,
    );
    final stderrExcerpt = _analyzerExcerpt(
      stderr,
      maxChars: request.maxOutputChars,
    );
    return CockpitAnalyzeFilesResult(
      workspaceRoot: workspaceRoot,
      toolchain: toolchain,
      paths: relativePaths,
      command: commandResult.command,
      exitCode: commandResult.exitCode,
      success: commandResult.success,
      clean: allDiagnostics.isEmpty,
      summary: _analysisSummary(allDiagnostics, severityCounts),
      totalDiagnostics: allDiagnostics.length,
      diagnostics: displayedDiagnostics,
      diagnosticsTruncated: allDiagnostics.length > displayedDiagnostics.length,
      severityCounts: Map<String, int>.unmodifiable(severityCounts),
      stdoutPreview: stdoutExcerpt.preview,
      stdoutTruncated: stdoutExcerpt.truncated,
      stderrPreview: stderrExcerpt.preview,
      stderrTruncated: stderrExcerpt.truncated,
    );
  }

  String _resolveWorkspacePath(String workspaceRoot, String rawPath) {
    final candidate = p.normalize(
      p.isAbsolute(rawPath) ? rawPath : p.join(workspaceRoot, rawPath),
    );
    assertWorkspaceRootAllowed(candidate, <String>[workspaceRoot]);
    final file = _fileSystem.file(candidate);
    final directory = _fileSystem.directory(candidate);
    if (!file.existsSync() && !directory.existsSync()) {
      throw CockpitApplicationServiceException(
        code: 'analysisPathNotFound',
        message: 'Analysis path does not exist.',
        details: <String, Object?>{
          'path': rawPath,
          'resolved_path': candidate,
        },
      );
    }
    return candidate;
  }
}

String _pickAnalyzerJson(String stdout, String stderr) {
  final normalizedStdout = stdout.trim();
  if (normalizedStdout.startsWith('{')) {
    return normalizedStdout;
  }
  final normalizedStderr = stderr.trim();
  if (normalizedStderr.startsWith('{')) {
    return normalizedStderr;
  }
  throw CockpitApplicationServiceException(
    code: 'analyzerJsonMissing',
    message: 'Analyzer output did not contain JSON diagnostics.',
    details: <String, Object?>{
      'stdout_preview': normalizedStdout.length > 400
          ? '${normalizedStdout.substring(0, 400)}...'
          : normalizedStdout,
      'stderr_preview': normalizedStderr.length > 400
          ? '${normalizedStderr.substring(0, 400)}...'
          : normalizedStderr,
    },
  );
}

CockpitAnalyzeFilesDiagnostic _diagnosticFromJson(
  Map<Object?, Object?> json, {
  required String workspaceRoot,
}) {
  final location =
      Map<Object?, Object?>.from(json['location'] as Map<Object?, Object?>);
  final range =
      Map<Object?, Object?>.from(location['range'] as Map<Object?, Object?>);
  final start =
      Map<Object?, Object?>.from(range['start'] as Map<Object?, Object?>);
  final end = Map<Object?, Object?>.from(range['end'] as Map<Object?, Object?>);
  final absolutePath = p.normalize(location['file'] as String);
  final relativePath = p.relative(absolutePath, from: workspaceRoot);
  return CockpitAnalyzeFilesDiagnostic(
    path: relativePath,
    severity: _normalizeEnumValue('${json['severity'] ?? 'unknown'}'),
    type: _normalizeEnumValue('${json['type'] ?? 'unknown'}'),
    code: '${json['code'] ?? ''}',
    message: '${json['problemMessage'] ?? ''}',
    line: (start['line'] as int? ?? 0),
    column: (start['column'] as int? ?? 0),
    endLine: (end['line'] as int? ?? 0),
    endColumn: (end['column'] as int? ?? 0),
    correction: json['correctionMessage'] as String?,
    documentationUrl: json['documentation'] as String?,
  );
}

String _normalizeEnumValue(String value) {
  if (value.isEmpty) {
    return 'unknown';
  }
  final lower = value.toLowerCase();
  final underscored = lower.replaceAllMapped(
    RegExp(r'([a-z0-9])([A-Z])'),
    (match) => '${match.group(1)}_${match.group(2)}',
  );
  return underscored.replaceAll('-', '_');
}

String _analysisSummary(
  List<CockpitAnalyzeFilesDiagnostic> diagnostics,
  Map<String, int> severityCounts,
) {
  if (diagnostics.isEmpty) {
    return 'No analyzer diagnostics.';
  }
  final fragments = <String>[];
  for (final severity in <String>['error', 'warning', 'info']) {
    final count = severityCounts[severity];
    if (count != null && count > 0) {
      fragments.add('$count $severity');
    }
  }
  if (fragments.isEmpty) {
    return '${diagnostics.length} analyzer diagnostics.';
  }
  return '${diagnostics.length} analyzer diagnostics: ${fragments.join(', ')}.';
}

({String? preview, bool truncated}) _analyzerExcerpt(
  String raw, {
  required int maxChars,
}) {
  final normalized = raw.trim();
  if (normalized.isEmpty) {
    return (preview: null, truncated: false);
  }
  if (normalized.length <= maxChars) {
    return (preview: normalized, truncated: false);
  }
  final safeMax = maxChars < 1 ? 1 : maxChars;
  return (
    preview: '${normalized.substring(0, safeMax).trimRight()}...',
    truncated: true,
  );
}

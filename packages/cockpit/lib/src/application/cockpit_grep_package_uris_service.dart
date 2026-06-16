import 'dart:async';
import 'dart:convert';

import 'package:file/file.dart';
import 'package:path/path.dart' as p;

import '../infrastructure/cockpit_file_system.dart';
import '../infrastructure/cockpit_process_manager.dart';
import 'cockpit_application_service_exception.dart';
import 'cockpit_package_config_support.dart';
import 'cockpit_workspace_tooling_support.dart';

final class CockpitGrepPackageUrisRequest {
  const CockpitGrepPackageUrisRequest({
    required this.workspaceRoot,
    required this.packageNames,
    required this.query,
    this.allowedRoots = const <String>[],
    this.searchDir = 'lib',
    this.useRegex = false,
    this.caseSensitive = false,
    this.maxMatches = 60,
    this.maxMatchesPerFile = 5,
    this.maxLineLength = 240,
    this.timeout = const Duration(seconds: 20),
  });

  final String workspaceRoot;
  final List<String> packageNames;
  final String query;
  final List<String> allowedRoots;
  final String searchDir;
  final bool useRegex;
  final bool caseSensitive;
  final int maxMatches;
  final int maxMatchesPerFile;
  final int maxLineLength;
  final Duration timeout;
}

final class CockpitGrepPackageUrisMatch {
  const CockpitGrepPackageUrisMatch({
    required this.line,
    required this.column,
    required this.endColumn,
    required this.text,
  });

  final int line;
  final int column;
  final int endColumn;
  final String text;

  Map<String, Object?> toJson() => <String, Object?>{
    'line': line,
    'column': column,
    'endColumn': endColumn,
    'text': text,
  };
}

final class CockpitGrepPackageUrisFileResult {
  const CockpitGrepPackageUrisFileResult({
    required this.path,
    required this.relativePath,
    required this.packageRootUri,
    required this.matches,
    this.packageUri,
  });

  final String path;
  final String relativePath;
  final String packageRootUri;
  final String? packageUri;
  final List<CockpitGrepPackageUrisMatch> matches;

  Map<String, Object?> toJson() => <String, Object?>{
    'path': path,
    'relativePath': relativePath,
    'packageRootUri': packageRootUri,
    if (packageUri != null) 'packageUri': packageUri,
    'matchCount': matches.length,
    'matches': matches.map((match) => match.toJson()).toList(growable: false),
  };
}

final class CockpitGrepPackageUrisPackageResult {
  const CockpitGrepPackageUrisPackageResult({
    required this.packageName,
    required this.matchCount,
    required this.files,
    this.searchRoot,
    this.error,
    this.truncated = false,
  });

  final String packageName;
  final String? searchRoot;
  final int matchCount;
  final List<CockpitGrepPackageUrisFileResult> files;
  final String? error;
  final bool truncated;

  Map<String, Object?> toJson() => <String, Object?>{
    'packageName': packageName,
    if (searchRoot != null) 'searchRoot': searchRoot,
    'fileCount': files.length,
    'matchCount': matchCount,
    'truncated': truncated,
    'files': files.map((file) => file.toJson()).toList(growable: false),
    if (error != null) 'error': error,
  };
}

final class CockpitGrepPackageUrisResult {
  const CockpitGrepPackageUrisResult({
    required this.workspaceRoot,
    required this.query,
    required this.searchDir,
    required this.useRegex,
    required this.caseSensitive,
    required this.usedRipgrep,
    required this.matchedPackageCount,
    required this.matchedFileCount,
    required this.totalMatches,
    required this.truncated,
    required this.summary,
    required this.packages,
    this.warnings = const <String>[],
  });

  final String workspaceRoot;
  final String query;
  final String searchDir;
  final bool useRegex;
  final bool caseSensitive;
  final bool usedRipgrep;
  final int matchedPackageCount;
  final int matchedFileCount;
  final int totalMatches;
  final bool truncated;
  final String summary;
  final List<CockpitGrepPackageUrisPackageResult> packages;
  final List<String> warnings;

  Map<String, Object?> toJson() => <String, Object?>{
    'workspaceRoot': workspaceRoot,
    'query': query,
    'searchDir': searchDir,
    'useRegex': useRegex,
    'caseSensitive': caseSensitive,
    'usedRipgrep': usedRipgrep,
    'matchedPackageCount': matchedPackageCount,
    'matchedFileCount': matchedFileCount,
    'totalMatches': totalMatches,
    'truncated': truncated,
    'summary': summary,
    'packages': packages
        .map((package) => package.toJson())
        .toList(growable: false),
    if (warnings.isNotEmpty) 'warnings': warnings,
  };
}

final class CockpitGrepPackageUrisService {
  CockpitGrepPackageUrisService({
    CockpitFileSystem? fileSystem,
    CockpitProcessManager? processManager,
  }) : _fileSystem = fileSystem ?? const LocalCockpitFileSystem(),
       _processManager = processManager ?? const LocalCockpitProcessManager();

  final CockpitFileSystem _fileSystem;
  final CockpitProcessManager _processManager;

  Future<CockpitGrepPackageUrisResult> grep(
    CockpitGrepPackageUrisRequest request,
  ) async {
    if (request.packageNames.isEmpty) {
      throw const CockpitApplicationServiceException(
        code: 'packageNamesRequired',
        message: 'packageNames must contain at least one dependency package.',
      );
    }
    if (request.query.trim().isEmpty) {
      throw const CockpitApplicationServiceException(
        code: 'queryRequired',
        message: 'query must not be empty.',
      );
    }
    if (request.maxMatches <= 0 || request.maxMatchesPerFile <= 0) {
      throw const CockpitApplicationServiceException(
        code: 'grepMatchLimitsInvalid',
        message: 'maxMatches and maxMatchesPerFile must be positive.',
      );
    }
    if (request.maxLineLength <= 0) {
      throw const CockpitApplicationServiceException(
        code: 'grepLineLengthInvalid',
        message: 'maxLineLength must be positive.',
      );
    }

    final workspaceRoot = assertWorkspaceRootAllowed(
      request.workspaceRoot,
      request.allowedRoots,
    );
    final packageConfig = cockpitReadPackageConfig(
      fileSystem: _fileSystem,
      workspaceRoot: workspaceRoot,
    );
    final warnings = <String>[];
    final packageResults = <CockpitGrepPackageUrisPackageResult>[];
    var remainingMatches = request.maxMatches;
    var usedRipgrep = false;
    var truncated = false;

    for (final packageName in request.packageNames) {
      final package = packageConfig[packageName];
      if (package == null) {
        warnings.add('Package "$packageName" was not found in package_config.');
        packageResults.add(
          CockpitGrepPackageUrisPackageResult(
            packageName: packageName,
            matchCount: 0,
            files: const <CockpitGrepPackageUrisFileResult>[],
            error: 'Package was not found in package_config.',
          ),
        );
        continue;
      }
      if (remainingMatches <= 0) {
        truncated = true;
        break;
      }

      final searchRoot = _resolveSearchRoot(
        package: package,
        searchDir: request.searchDir,
      );
      final searchTargetExists = _searchTargetExists(searchRoot);
      if (!searchTargetExists) {
        warnings.add(
          'Package "$packageName" search target "${request.searchDir}" does not exist.',
        );
        packageResults.add(
          CockpitGrepPackageUrisPackageResult(
            packageName: packageName,
            searchRoot: searchRoot,
            matchCount: 0,
            files: const <CockpitGrepPackageUrisFileResult>[],
            error: 'Search target does not exist.',
          ),
        );
        continue;
      }

      final outcome = await _searchPackage(
        workspaceRoot: workspaceRoot,
        package: package,
        searchRoot: searchRoot,
        request: request,
        maxMatches: remainingMatches,
      );
      usedRipgrep = usedRipgrep || outcome.usedRipgrep;
      truncated = truncated || outcome.truncated;
      remainingMatches -= outcome.matchCount;
      packageResults.add(
        CockpitGrepPackageUrisPackageResult(
          packageName: packageName,
          searchRoot: searchRoot,
          matchCount: outcome.matchCount,
          files: outcome.files,
          truncated: outcome.truncated,
        ),
      );
    }

    final matchedPackageCount = packageResults
        .where((package) => package.matchCount > 0)
        .length;
    final matchedFileCount = packageResults.fold<int>(0, (count, package) {
      return count + package.files.length;
    });
    final totalMatches = packageResults.fold<int>(0, (count, package) {
      return count + package.matchCount;
    });
    return CockpitGrepPackageUrisResult(
      workspaceRoot: workspaceRoot,
      query: request.query,
      searchDir: request.searchDir,
      useRegex: request.useRegex,
      caseSensitive: request.caseSensitive,
      usedRipgrep: usedRipgrep,
      matchedPackageCount: matchedPackageCount,
      matchedFileCount: matchedFileCount,
      totalMatches: totalMatches,
      truncated: truncated,
      summary: _summaryFor(
        totalMatches: totalMatches,
        matchedFileCount: matchedFileCount,
        matchedPackageCount: matchedPackageCount,
        requestedPackageCount: request.packageNames.length,
        truncated: truncated,
      ),
      packages: List<CockpitGrepPackageUrisPackageResult>.unmodifiable(
        packageResults,
      ),
      warnings: List<String>.unmodifiable(warnings),
    );
  }

  String _resolveSearchRoot({
    required CockpitResolvedPackageConfigEntry package,
    required String searchDir,
  }) {
    if (searchDir.isEmpty) {
      return package.rootPath;
    }
    return p.normalize(p.join(package.rootPath, searchDir));
  }

  bool _searchTargetExists(String searchRoot) {
    return _fileSystem.file(searchRoot).existsSync() ||
        _fileSystem.directory(searchRoot).existsSync();
  }

  Future<_CockpitPackageSearchOutcome> _searchPackage({
    required String workspaceRoot,
    required CockpitResolvedPackageConfigEntry package,
    required String searchRoot,
    required CockpitGrepPackageUrisRequest request,
    required int maxMatches,
  }) async {
    final ripgrepOutcome = await _searchWithRipgrep(
      workspaceRoot: workspaceRoot,
      package: package,
      searchRoot: searchRoot,
      request: request,
      maxMatches: maxMatches,
    );
    if (ripgrepOutcome != null) {
      return ripgrepOutcome;
    }
    return _searchWithFileSystem(
      package: package,
      searchRoot: searchRoot,
      request: request,
      maxMatches: maxMatches,
    );
  }

  Future<_CockpitPackageSearchOutcome?> _searchWithRipgrep({
    required String workspaceRoot,
    required CockpitResolvedPackageConfigEntry package,
    required String searchRoot,
    required CockpitGrepPackageUrisRequest request,
    required int maxMatches,
  }) async {
    final versionTimeout = request.timeout < const Duration(seconds: 2)
        ? request.timeout
        : const Duration(seconds: 2);
    try {
      final version = await cockpitRunManagedProcessWithTimeout(
        _processManager,
        'rg',
        const <String>['--version'],
        workingDirectory: workspaceRoot,
        timeout: versionTimeout,
      );
      if (version.exitCode != 0) {
        return null;
      }
    } on Object {
      return null;
    }

    try {
      final result = await cockpitRunManagedProcessWithTimeout(
        _processManager,
        'rg',
        <String>[
          '--no-config',
          '--json',
          if (!request.caseSensitive) '--ignore-case',
          if (!request.useRegex) '--fixed-strings',
          '-m',
          '${request.maxMatchesPerFile}',
          request.query,
          searchRoot,
        ],
        workingDirectory: workspaceRoot,
        timeout: request.timeout,
      );
      if (result.exitCode != 0 && result.exitCode != 1) {
        return null;
      }
      final stdout = cockpitProcessOutputText(result.stdout);
      return _parseRipgrepOutput(
        stdout: stdout,
        package: package,
        request: request,
        maxMatches: maxMatches,
      );
    } on TimeoutException {
      throw CockpitApplicationServiceException(
        code: 'grepPackageUrisTimedOut',
        message: 'Dependency package search timed out.',
        details: <String, Object?>{
          'timeoutMs': request.timeout.inMilliseconds,
          'query': request.query,
          'packageName': package.packageName,
        },
      );
    } on Object {
      return null;
    }
  }

  _CockpitPackageSearchOutcome _parseRipgrepOutput({
    required String stdout,
    required CockpitResolvedPackageConfigEntry package,
    required CockpitGrepPackageUrisRequest request,
    required int maxMatches,
  }) {
    final filesByPath = <String, _MutableFileMatches>{};
    var totalMatches = 0;
    var truncated = false;

    for (final line in const LineSplitter().convert(stdout)) {
      if (line.isEmpty) {
        continue;
      }
      final event = jsonDecode(line) as Map<Object?, Object?>;
      if (event['type'] != 'match') {
        continue;
      }
      final data = Map<Object?, Object?>.from(
        event['data'] as Map<Object?, Object?>? ?? const <Object?, Object?>{},
      );
      final pathData = Map<Object?, Object?>.from(
        data['path'] as Map<Object?, Object?>? ?? const <Object?, Object?>{},
      );
      final path = pathData['text'] as String?;
      if (path == null || path.isEmpty) {
        continue;
      }
      final normalizedPath = p.normalize(path);
      final relativePath = cockpitNormalizePackageRelativePath(
        p.relative(normalizedPath, from: package.rootPath),
      );
      final fileMatches = filesByPath.putIfAbsent(
        normalizedPath,
        () => _MutableFileMatches(
          path: normalizedPath,
          relativePath: relativePath,
          packageRootUri: package.packageRootUriForRelativePath(relativePath),
          packageUri: package.packageUriForRelativePath(relativePath),
        ),
      );
      final rawLine = _ripgrepLineText(data['lines'] as Map<Object?, Object?>?);
      final submatches = ((data['submatches'] as List?) ?? const <Object?>[])
          .whereType<Map<Object?, Object?>>();
      for (final submatch in submatches) {
        if (totalMatches >= maxMatches) {
          truncated = true;
          break;
        }
        if (fileMatches.matches.length >= request.maxMatchesPerFile) {
          truncated = true;
          break;
        }
        final start = (submatch['start'] as num?)?.toInt();
        final end = (submatch['end'] as num?)?.toInt();
        if (start == null || end == null) {
          continue;
        }
        fileMatches.matches.add(
          CockpitGrepPackageUrisMatch(
            line: (data['line_number'] as num?)?.toInt() ?? 1,
            column: start + 1,
            endColumn: end,
            text: _trimLineText(
              rawLine,
              start: start,
              end: end,
              maxLineLength: request.maxLineLength,
            ),
          ),
        );
        totalMatches++;
      }
      if (truncated && totalMatches >= maxMatches) {
        break;
      }
    }

    return _CockpitPackageSearchOutcome(
      files: filesByPath.values
          .map(
            (file) => CockpitGrepPackageUrisFileResult(
              path: file.path,
              relativePath: file.relativePath,
              packageRootUri: file.packageRootUri,
              packageUri: file.packageUri,
              matches: List<CockpitGrepPackageUrisMatch>.unmodifiable(
                file.matches,
              ),
            ),
          )
          .toList(growable: false),
      matchCount: totalMatches,
      truncated: truncated,
      usedRipgrep: true,
    );
  }

  Future<_CockpitPackageSearchOutcome> _searchWithFileSystem({
    required CockpitResolvedPackageConfigEntry package,
    required String searchRoot,
    required CockpitGrepPackageUrisRequest request,
    required int maxMatches,
  }) async {
    final pattern = _buildPattern(request);
    final files = _collectSearchFiles(searchRoot);
    final results = <CockpitGrepPackageUrisFileResult>[];
    var totalMatches = 0;
    var truncated = false;

    for (final file in files) {
      if (totalMatches >= maxMatches) {
        truncated = true;
        break;
      }
      final bytes = file.readAsBytesSync();
      if (!_looksLikeText(bytes)) {
        continue;
      }
      final rawText = utf8.decode(bytes, allowMalformed: true);
      final lines = const LineSplitter().convert(rawText);
      final matches = <CockpitGrepPackageUrisMatch>[];
      for (var index = 0; index < lines.length; index++) {
        final lineText = lines[index];
        for (final match in pattern.allMatches(lineText)) {
          if (matches.length >= request.maxMatchesPerFile) {
            truncated = true;
            break;
          }
          if (totalMatches >= maxMatches) {
            truncated = true;
            break;
          }
          matches.add(
            CockpitGrepPackageUrisMatch(
              line: index + 1,
              column: match.start + 1,
              endColumn: match.end,
              text: _trimLineText(
                lineText,
                start: match.start,
                end: match.end,
                maxLineLength: request.maxLineLength,
              ),
            ),
          );
          totalMatches++;
        }
        if (truncated &&
            (matches.length >= request.maxMatchesPerFile ||
                totalMatches >= maxMatches)) {
          break;
        }
      }
      if (matches.isEmpty) {
        continue;
      }
      final relativePath = cockpitNormalizePackageRelativePath(
        p.relative(file.path, from: package.rootPath),
      );
      results.add(
        CockpitGrepPackageUrisFileResult(
          path: file.path,
          relativePath: relativePath,
          packageRootUri: package.packageRootUriForRelativePath(relativePath),
          packageUri: package.packageUriForRelativePath(relativePath),
          matches: List<CockpitGrepPackageUrisMatch>.unmodifiable(matches),
        ),
      );
    }

    return _CockpitPackageSearchOutcome(
      files: List<CockpitGrepPackageUrisFileResult>.unmodifiable(results),
      matchCount: totalMatches,
      truncated: truncated,
      usedRipgrep: false,
    );
  }

  RegExp _buildPattern(CockpitGrepPackageUrisRequest request) {
    try {
      return request.useRegex
          ? RegExp(request.query, caseSensitive: request.caseSensitive)
          : RegExp(
              RegExp.escape(request.query),
              caseSensitive: request.caseSensitive,
            );
    } on FormatException catch (error) {
      throw CockpitApplicationServiceException(
        code: 'grepPatternInvalid',
        message: 'query is not a valid regular expression.',
        details: <String, Object?>{
          'query': request.query,
          'error': error.message,
        },
      );
    }
  }

  List<File> _collectSearchFiles(String searchRoot) {
    final rootFile = _fileSystem.file(searchRoot);
    if (rootFile.existsSync()) {
      return <File>[rootFile];
    }
    final files = _fileSystem
        .directory(searchRoot)
        .listSync(recursive: true, followLinks: false)
        .whereType<File>()
        .toList();
    files.sort((left, right) => left.path.compareTo(right.path));
    return files;
  }
}

final class _CockpitPackageSearchOutcome {
  const _CockpitPackageSearchOutcome({
    required this.files,
    required this.matchCount,
    required this.truncated,
    required this.usedRipgrep,
  });

  final List<CockpitGrepPackageUrisFileResult> files;
  final int matchCount;
  final bool truncated;
  final bool usedRipgrep;
}

final class _MutableFileMatches {
  _MutableFileMatches({
    required this.path,
    required this.relativePath,
    required this.packageRootUri,
    required this.packageUri,
  });

  final String path;
  final String relativePath;
  final String packageRootUri;
  final String? packageUri;
  final List<CockpitGrepPackageUrisMatch> matches =
      <CockpitGrepPackageUrisMatch>[];
}

String _summaryFor({
  required int totalMatches,
  required int matchedFileCount,
  required int matchedPackageCount,
  required int requestedPackageCount,
  required bool truncated,
}) {
  if (totalMatches == 0) {
    return 'No matches found across $requestedPackageCount package'
        '${requestedPackageCount == 1 ? '' : 's'}.';
  }
  final summary =
      'Found $totalMatches match'
      '${totalMatches == 1 ? '' : 'es'} across $matchedFileCount file'
      '${matchedFileCount == 1 ? '' : 's'} in $matchedPackageCount package'
      '${matchedPackageCount == 1 ? '' : 's'}.';
  return truncated ? '$summary Results were truncated.' : summary;
}

String _ripgrepLineText(Map<Object?, Object?>? data) {
  if (data == null) {
    return '';
  }
  final text = data['text'] as String?;
  if (text == null) {
    return '';
  }
  return text.replaceFirst(RegExp(r'[\r\n]+$'), '');
}

String _trimLineText(
  String lineText, {
  required int start,
  required int end,
  required int maxLineLength,
}) {
  final normalized = lineText.replaceAll('\t', ' ');
  if (normalized.length <= maxLineLength) {
    return normalized;
  }
  if (end - start >= maxLineLength - 6) {
    final sliceEnd = (start + maxLineLength - 3).clamp(0, normalized.length);
    return '${normalized.substring(start, sliceEnd)}...';
  }
  final matchCenter = ((start + end) / 2).round();
  var sliceStart = matchCenter - (maxLineLength ~/ 2);
  if (sliceStart < 0) {
    sliceStart = 0;
  }
  var sliceEnd = sliceStart + maxLineLength;
  if (sliceEnd > normalized.length) {
    sliceEnd = normalized.length;
    sliceStart = (sliceEnd - maxLineLength).clamp(0, normalized.length);
  }
  final prefix = sliceStart > 0 ? '...' : '';
  final suffix = sliceEnd < normalized.length ? '...' : '';
  return '$prefix${normalized.substring(sliceStart, sliceEnd)}$suffix';
}

bool _looksLikeText(List<int> bytes) {
  if (bytes.isEmpty) {
    return true;
  }
  var suspicious = 0;
  for (final byte in bytes.take(256)) {
    if (byte == 9 || byte == 10 || byte == 13) {
      continue;
    }
    if (byte < 32) {
      suspicious++;
    }
  }
  return suspicious <= 2;
}

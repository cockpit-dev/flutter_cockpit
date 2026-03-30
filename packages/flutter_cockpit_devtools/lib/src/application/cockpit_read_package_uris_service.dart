import 'dart:convert';

import 'package:file/file.dart';
import 'package:path/path.dart' as p;

import 'cockpit_application_service_exception.dart';
import '../infrastructure/cockpit_file_system.dart';
import 'cockpit_workspace_tooling_support.dart';

enum CockpitPackageUriEntryKind { file, directory }

enum CockpitPackageUriContentKind { text, directory, binary, image }

final class CockpitPackageUriDirectoryEntry {
  const CockpitPackageUriDirectoryEntry({
    required this.path,
    required this.name,
    required this.isDirectory,
  });

  final String path;
  final String name;
  final bool isDirectory;

  Map<String, Object?> toJson() => <String, Object?>{
        'path': path,
        'name': name,
        'is_directory': isDirectory,
      };
}

final class CockpitReadPackageUrisRequest {
  const CockpitReadPackageUrisRequest({
    required this.workspaceRoot,
    required this.uri,
    this.allowedRoots = const <String>[],
    this.maxPreviewChars = 1200,
    this.maxEntries = 40,
    this.includeFullText = false,
  });

  final String workspaceRoot;
  final String uri;
  final List<String> allowedRoots;
  final int maxPreviewChars;
  final int maxEntries;
  final bool includeFullText;
}

final class CockpitReadPackageUrisResult {
  const CockpitReadPackageUrisResult({
    required this.kind,
    required this.contentKind,
    required this.resolvedPath,
    this.preview,
    this.text,
    this.mediaType,
    this.totalBytes,
    this.entryCount = 0,
    this.truncated = false,
    this.entries = const <CockpitPackageUriDirectoryEntry>[],
  });

  final CockpitPackageUriEntryKind kind;
  final CockpitPackageUriContentKind contentKind;
  final String resolvedPath;
  final String? preview;
  final String? text;
  final String? mediaType;
  final int? totalBytes;
  final int entryCount;
  final bool truncated;
  final List<CockpitPackageUriDirectoryEntry> entries;

  Map<String, Object?> toJson() => <String, Object?>{
        'kind': kind.name,
        'content_kind': contentKind.name,
        'resolved_path': resolvedPath,
        'preview': preview,
        'text': text,
        'media_type': mediaType,
        'total_bytes': totalBytes,
        'entry_count': entryCount,
        'truncated': truncated,
        'entries':
            entries.map((entry) => entry.toJson()).toList(growable: false),
      };
}

final class CockpitReadPackageUrisService {
  CockpitReadPackageUrisService({
    CockpitFileSystem? fileSystem,
  }) : _fileSystem = fileSystem ?? const LocalCockpitFileSystem();

  final CockpitFileSystem _fileSystem;

  Future<CockpitReadPackageUrisResult> read(
    CockpitReadPackageUrisRequest request,
  ) async {
    final workspaceRoot = assertWorkspaceRootAllowed(
      request.workspaceRoot,
      request.allowedRoots,
    );
    final packageConfig = _readPackageConfig(workspaceRoot);
    final uri = request.uri;
    final packageRootMode = uri.startsWith('package-root:');
    if (!packageRootMode && !uri.startsWith('package:')) {
      throw CockpitApplicationServiceException(
        code: 'unsupportedPackageUri',
        message: 'Only package: and package-root: URIs are supported.',
        details: <String, Object?>{'uri': uri},
      );
    }

    final withoutScheme = uri.substring(
        packageRootMode ? 'package-root:'.length : 'package:'.length);
    final separator = withoutScheme.indexOf('/');
    final packageName =
        separator == -1 ? withoutScheme : withoutScheme.substring(0, separator);
    final relativePath =
        separator == -1 ? '' : withoutScheme.substring(separator + 1);
    final package = packageConfig[packageName];
    if (package == null) {
      throw CockpitApplicationServiceException(
        code: 'packageNotFound',
        message: 'Package was not found in package_config.',
        details: <String, Object?>{'packageName': packageName},
      );
    }

    final basePath = packageRootMode ? package.rootPath : package.packagePath;
    final resolvedPath = p.normalize(
      relativePath.isEmpty ? basePath : p.join(basePath, relativePath),
    );
    final file = _fileSystem.file(resolvedPath);
    if (file.existsSync()) {
      final bytes = await file.readAsBytes();
      final contentKind = _contentKindForPath(resolvedPath, bytes);
      final preview = _buildPreview(
        path: resolvedPath,
        bytes: bytes,
        maxPreviewChars: request.maxPreviewChars,
      );
      final fullText = request.includeFullText &&
              contentKind == CockpitPackageUriContentKind.text &&
              preview.truncated == false
          ? preview.preview
          : null;
      return CockpitReadPackageUrisResult(
        kind: CockpitPackageUriEntryKind.file,
        contentKind: contentKind,
        resolvedPath: resolvedPath,
        preview: preview.preview,
        text: fullText,
        mediaType: _mediaTypeForPath(resolvedPath, contentKind),
        totalBytes: bytes.length,
        truncated: preview.truncated,
      );
    }

    final directory = _fileSystem.directory(resolvedPath);
    if (directory.existsSync()) {
      final entries = directory
          .listSync()
          .map(
            (entry) => CockpitPackageUriDirectoryEntry(
              path: entry.path,
              name: p.basename(entry.path),
              isDirectory: entry is Directory,
            ),
          )
          .take(request.maxEntries)
          .toList(growable: false);
      return CockpitReadPackageUrisResult(
        kind: CockpitPackageUriEntryKind.directory,
        contentKind: CockpitPackageUriContentKind.directory,
        resolvedPath: resolvedPath,
        preview: _directoryPreview(entries),
        entryCount: entries.length,
        entries: entries,
      );
    }

    throw CockpitApplicationServiceException(
      code: 'packagePathNotFound',
      message: 'Resolved package path does not exist.',
      details: <String, Object?>{
        'uri': uri,
        'resolvedPath': resolvedPath,
      },
    );
  }

  Map<String, _CockpitPackageConfigEntry> _readPackageConfig(
      String workspaceRoot) {
    final configFile = _fileSystem.file(
      p.join(workspaceRoot, '.dart_tool', 'package_config.json'),
    );
    final decoded =
        jsonDecode(configFile.readAsStringSync()) as Map<Object?, Object?>;
    final packages = ((decoded['packages'] as List?) ?? const <Object?>[])
        .cast<Map<Object?, Object?>>();
    return <String, _CockpitPackageConfigEntry>{
      for (final package in packages)
        package['name'] as String: _CockpitPackageConfigEntry.fromJson(
          package,
          configDirectoryPath: configFile.parent.path,
        ),
    };
  }
}

final class _CockpitPreviewResult {
  const _CockpitPreviewResult({
    required this.preview,
    required this.truncated,
  });

  final String preview;
  final bool truncated;
}

final class _CockpitPackageConfigEntry {
  const _CockpitPackageConfigEntry({
    required this.rootPath,
    required this.packagePath,
  });

  final String rootPath;
  final String packagePath;

  factory _CockpitPackageConfigEntry.fromJson(
    Map<Object?, Object?> json, {
    required String configDirectoryPath,
  }) {
    final rootPath = _pathFromPackageConfigUri(
      json['rootUri'] as String,
      configDirectoryPath: configDirectoryPath,
    );
    final packageUri = json['packageUri'] as String? ?? 'lib/';
    return _CockpitPackageConfigEntry(
      rootPath: rootPath,
      packagePath: p.normalize(p.join(rootPath, packageUri)),
    );
  }

  static String _pathFromPackageConfigUri(
    String uri, {
    required String configDirectoryPath,
  }) {
    final parsed = Uri.parse(uri);
    if (parsed.scheme.isEmpty) {
      return Uri.directory(configDirectoryPath).resolveUri(parsed).toFilePath();
    }
    return parsed.toFilePath();
  }
}

CockpitPackageUriContentKind _contentKindForPath(String path, List<int> bytes) {
  final extension = p.extension(path).toLowerCase();
  if (extension == '.png' ||
      extension == '.jpg' ||
      extension == '.jpeg' ||
      extension == '.gif' ||
      extension == '.webp') {
    return CockpitPackageUriContentKind.image;
  }
  if (_looksLikeText(bytes)) {
    return CockpitPackageUriContentKind.text;
  }
  return CockpitPackageUriContentKind.binary;
}

String? _mediaTypeForPath(
  String path,
  CockpitPackageUriContentKind contentKind,
) {
  if (contentKind == CockpitPackageUriContentKind.image) {
    return switch (p.extension(path).toLowerCase()) {
      '.png' => 'image/png',
      '.jpg' || '.jpeg' => 'image/jpeg',
      '.gif' => 'image/gif',
      '.webp' => 'image/webp',
      _ => 'image/*',
    };
  }
  if (contentKind == CockpitPackageUriContentKind.binary) {
    return 'application/octet-stream';
  }
  if (contentKind == CockpitPackageUriContentKind.text) {
    return 'text/plain';
  }
  return null;
}

_CockpitPreviewResult _buildPreview({
  required String path,
  required List<int> bytes,
  required int maxPreviewChars,
}) {
  final contentKind = _contentKindForPath(path, bytes);
  if (contentKind != CockpitPackageUriContentKind.text) {
    return _CockpitPreviewResult(
      preview:
          'Binary content omitted. media_type=${_mediaTypeForPath(path, contentKind)} bytes=${bytes.length}',
      truncated: false,
    );
  }
  final decoded = utf8.decode(bytes, allowMalformed: true);
  final safeMaxChars = maxPreviewChars <= 0 ? 1200 : maxPreviewChars;
  if (decoded.length <= safeMaxChars) {
    return _CockpitPreviewResult(preview: decoded, truncated: false);
  }
  return _CockpitPreviewResult(
    preview: decoded.substring(0, safeMaxChars),
    truncated: true,
  );
}

String _directoryPreview(List<CockpitPackageUriDirectoryEntry> entries) {
  if (entries.isEmpty) {
    return '(empty directory)';
  }
  return entries
      .map((entry) => '${entry.isDirectory ? 'dir' : 'file'} ${entry.name}')
      .join('\n');
}

bool _looksLikeText(List<int> bytes) {
  if (bytes.isEmpty) {
    return true;
  }
  var suspicious = 0;
  final sample = bytes.take(256);
  for (final byte in sample) {
    if (byte == 9 || byte == 10 || byte == 13) {
      continue;
    }
    if (byte < 32) {
      suspicious++;
    }
  }
  return suspicious <= 2;
}

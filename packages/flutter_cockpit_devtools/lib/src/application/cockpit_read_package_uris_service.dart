import 'dart:convert';

import 'package:file/file.dart';
import 'package:path/path.dart' as p;

import 'cockpit_application_service_exception.dart';
import '../infrastructure/cockpit_file_system.dart';
import 'cockpit_workspace_tooling_support.dart';

enum CockpitPackageUriEntryKind { file, directory }

final class CockpitPackageUriDirectoryEntry {
  const CockpitPackageUriDirectoryEntry({
    required this.path,
    required this.name,
    required this.isDirectory,
  });

  final String path;
  final String name;
  final bool isDirectory;
}

final class CockpitReadPackageUrisRequest {
  const CockpitReadPackageUrisRequest({
    required this.workspaceRoot,
    required this.uri,
    this.allowedRoots = const <String>[],
  });

  final String workspaceRoot;
  final String uri;
  final List<String> allowedRoots;
}

final class CockpitReadPackageUrisResult {
  const CockpitReadPackageUrisResult({
    required this.kind,
    required this.resolvedPath,
    this.text,
    this.entries = const <CockpitPackageUriDirectoryEntry>[],
  });

  final CockpitPackageUriEntryKind kind;
  final String resolvedPath;
  final String? text;
  final List<CockpitPackageUriDirectoryEntry> entries;
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
      return CockpitReadPackageUrisResult(
        kind: CockpitPackageUriEntryKind.file,
        resolvedPath: resolvedPath,
        text: await file.readAsString(),
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
          .toList(growable: false);
      return CockpitReadPackageUrisResult(
        kind: CockpitPackageUriEntryKind.directory,
        resolvedPath: resolvedPath,
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
        package['name'] as String: _CockpitPackageConfigEntry.fromJson(package),
    };
  }
}

final class _CockpitPackageConfigEntry {
  const _CockpitPackageConfigEntry({
    required this.rootPath,
    required this.packagePath,
  });

  final String rootPath;
  final String packagePath;

  factory _CockpitPackageConfigEntry.fromJson(Map<Object?, Object?> json) {
    final rootPath = _pathFromFileUri(json['rootUri'] as String);
    final packageUri = json['packageUri'] as String? ?? 'lib/';
    return _CockpitPackageConfigEntry(
      rootPath: rootPath,
      packagePath: p.normalize(p.join(rootPath, packageUri)),
    );
  }

  static String _pathFromFileUri(String uri) {
    return Uri.parse(uri).toFilePath();
  }
}

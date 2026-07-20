import 'dart:convert';
import 'dart:io';

import 'package:cockpit_protocol/cockpit_protocol.dart';
import 'package:path/path.dart' as p;

import '../foundation/cockpit_locked_json_store.dart';
import 'cockpit_registry_models.dart';

final class CockpitWorkspaceMarkerStore {
  const CockpitWorkspaceMarkerStore(this._atomicFile);

  static const relativePath = '.dart_tool/cockpit/workspace.json';
  static const maximumBytes = 64 * 1024;

  final CockpitAtomicJsonFile _atomicFile;

  String pathFor(String canonicalWorkspacePath) =>
      p.joinAll(<String>[canonicalWorkspacePath, ...relativePath.split('/')]);

  Future<CockpitWorkspaceMarker?> read(String canonicalWorkspacePath) async {
    final path = await _validatedPath(
      canonicalWorkspacePath,
      createParents: false,
    );
    if (path == null) return null;
    final type = await FileSystemEntity.type(path, followLinks: false);
    if (type == FileSystemEntityType.notFound) {
      return null;
    }
    if (type != FileSystemEntityType.file) {
      throw const CockpitRegistryException(
        code: 'workspaceMarkerInvalid',
        message: 'Workspace marker path is not a regular file.',
      );
    }
    final file = File(path);
    if (await file.length() > maximumBytes) {
      throw const CockpitRegistryException(
        code: 'workspaceMarkerInvalid',
        message: 'Workspace marker exceeds the size limit.',
      );
    }
    try {
      return CockpitWorkspaceMarker.fromJson(
        jsonDecode(await file.readAsString()),
      );
    } on Object catch (error) {
      final diagnostic = _bounded(error);
      throw CockpitRegistryException(
        code: 'workspaceMarkerInvalid',
        message: 'Workspace marker is invalid: $diagnostic',
      );
    }
  }

  Future<void> write(
    String canonicalWorkspacePath,
    CockpitWorkspaceMarker marker,
  ) async {
    final path = await _validatedPath(
      canonicalWorkspacePath,
      createParents: true,
    );
    await _atomicFile.write(path!, marker.toJson());
  }

  Future<String?> _validatedPath(
    String canonicalWorkspacePath, {
    required bool createParents,
  }) async {
    final canonicalRoot = p.normalize(
      await Directory(canonicalWorkspacePath).resolveSymbolicLinks(),
    );
    var current = canonicalRoot;
    for (final segment in const <String>['.dart_tool', 'cockpit']) {
      current = p.join(current, segment);
      final type = await FileSystemEntity.type(current, followLinks: false);
      if (type == FileSystemEntityType.notFound) {
        if (!createParents) return null;
        await Directory(current).create();
      } else if (type != FileSystemEntityType.directory) {
        throw const CockpitRegistryException(
          code: 'workspaceMarkerUnsafePath',
          message: 'Workspace marker parent must not contain links or files.',
        );
      }
      final resolved = p.normalize(
        await Directory(current).resolveSymbolicLinks(),
      );
      if (!_isWithin(canonicalRoot, resolved)) {
        throw const CockpitRegistryException(
          code: 'workspaceMarkerUnsafePath',
          message: 'Workspace marker parent escapes the canonical workspace.',
        );
      }
      current = resolved;
    }
    final markerPath = p.join(current, 'workspace.json');
    if (await FileSystemEntity.type(markerPath, followLinks: false) ==
        FileSystemEntityType.link) {
      throw const CockpitRegistryException(
        code: 'workspaceMarkerUnsafePath',
        message: 'Workspace marker must not be a symbolic link.',
      );
    }
    return markerPath;
  }

  bool _isWithin(String root, String candidate) {
    final normalizedRoot = Platform.isWindows ? root.toLowerCase() : root;
    final normalizedCandidate = Platform.isWindows
        ? candidate.toLowerCase()
        : candidate;
    return normalizedRoot != normalizedCandidate &&
        p.isWithin(normalizedRoot, normalizedCandidate);
  }
}

String _bounded(Object value) {
  final text = value
      .toString()
      .replaceAll('\n', ' ')
      .replaceAll('\r', ' ')
      .replaceAll('\t', ' ')
      .trim();
  return text.length <= 192 ? text : '${text.substring(0, 192)}...';
}

import 'dart:io';

import 'package:path/path.dart' as p;

final RegExp _windowsDrivePathPattern = RegExp(r'^[a-zA-Z]:[\\/]');

p.Context cockpitSessionPathContext(String seedPath) {
  final normalized = seedPath.trim();
  if (_looksLikeWindowsPath(normalized)) {
    return p.Context(style: p.Style.windows);
  }
  return p.Context(style: p.Style.posix);
}

bool _looksLikeWindowsPath(String path) {
  if (path.isEmpty) {
    return false;
  }
  return path.contains(r'\') ||
      path.startsWith(r'\\') ||
      _windowsDrivePathPattern.hasMatch(path);
}

String? cockpitReadWorkspacePubspecName(String projectDir) {
  final pathContext = cockpitSessionPathContext(projectDir);
  final pubspec = File(pathContext.join(projectDir, 'pubspec.yaml'));
  if (!pubspec.existsSync()) {
    return null;
  }
  for (final rawLine in pubspec.readAsLinesSync()) {
    final line = rawLine.trim();
    if (!line.startsWith('name:')) {
      continue;
    }
    final value = line.substring('name:'.length).trim();
    if (value.isEmpty) {
      return null;
    }
    return value;
  }
  return null;
}

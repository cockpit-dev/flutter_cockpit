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

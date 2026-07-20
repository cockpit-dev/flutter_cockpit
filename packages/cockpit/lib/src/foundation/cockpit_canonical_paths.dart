import 'dart:io';

import 'package:path/path.dart' as p;

enum CockpitPathStyle { posix, windows }

final class CockpitPathException implements Exception {
  const CockpitPathException(this.code, this.path, this.message);

  final String code;
  final String path;
  final String message;

  @override
  String toString() => 'CockpitPathException($code, $path): $message';
}

final class CockpitLexicalPaths {
  const CockpitLexicalPaths(this.style);

  final CockpitPathStyle style;

  p.Context get _context =>
      style == CockpitPathStyle.windows ? p.windows : p.posix;

  String normalizeAbsolute(String path) {
    if (!_context.isAbsolute(path)) {
      throw CockpitPathException(
        'pathNotAbsolute',
        path,
        'Path must be absolute.',
      );
    }
    return _context.normalize(path);
  }

  bool equals(String left, String right) {
    final normalizedLeft = _comparable(normalizeAbsolute(left));
    final normalizedRight = _comparable(normalizeAbsolute(right));
    return normalizedLeft == normalizedRight;
  }

  bool contains(String root, String candidate, {bool allowEqual = true}) {
    final normalizedRoot = _comparable(normalizeAbsolute(root));
    final normalizedCandidate = _comparable(normalizeAbsolute(candidate));
    if (normalizedRoot == normalizedCandidate) {
      return allowEqual;
    }
    return _context.isWithin(normalizedRoot, normalizedCandidate);
  }

  bool overlaps(String left, String right) =>
      contains(left, right) || contains(right, left);

  String _comparable(String value) =>
      style == CockpitPathStyle.windows ? value.toLowerCase() : value;
}

final class CockpitCanonicalDirectory {
  const CockpitCanonicalDirectory({
    required this.requestedPath,
    required this.path,
  });

  final String requestedPath;
  final String path;
}

final class CockpitCanonicalDirectoryResolver {
  const CockpitCanonicalDirectoryResolver();

  Future<CockpitCanonicalDirectory> resolve(String path) async {
    if (!p.isAbsolute(path)) {
      throw CockpitPathException(
        'pathNotAbsolute',
        path,
        'Directory path must be absolute.',
      );
    }
    final normalized = p.normalize(path);
    final type = await FileSystemEntity.type(normalized, followLinks: true);
    if (type == FileSystemEntityType.notFound) {
      throw CockpitPathException(
        'pathNotFound',
        normalized,
        'Directory does not exist.',
      );
    }
    if (type != FileSystemEntityType.directory) {
      throw CockpitPathException(
        'pathNotDirectory',
        normalized,
        'Path is not a directory.',
      );
    }
    try {
      final canonical = await Directory(normalized).resolveSymbolicLinks();
      return CockpitCanonicalDirectory(
        requestedPath: normalized,
        path: p.normalize(canonical),
      );
    } on FileSystemException catch (error) {
      throw CockpitPathException(
        'pathResolutionFailed',
        normalized,
        error.message,
      );
    }
  }
}

import 'package:path/path.dart' as p;

final class CockpitBundleArtifactPaths {
  CockpitBundleArtifactPaths({
    this.primaryScreenshotPath,
    List<String> attachmentPaths = const <String>[],
    this.primaryRecordingPath,
    List<String> videoAttachmentPaths = const <String>[],
    List<String> keyframePaths = const <String>[],
  })  : attachmentPaths = List.unmodifiable(attachmentPaths),
        videoAttachmentPaths = List.unmodifiable(videoAttachmentPaths),
        keyframePaths = List.unmodifiable(keyframePaths);

  final String? primaryScreenshotPath;
  final List<String> attachmentPaths;
  final String? primaryRecordingPath;
  final List<String> videoAttachmentPaths;
  final List<String> keyframePaths;

  factory CockpitBundleArtifactPaths.fromDelivery({
    required String bundleDir,
    required Map<String, Object?> delivery,
  }) {
    return CockpitBundleArtifactPaths(
      primaryScreenshotPath: _resolvePath(
        bundleDir: bundleDir,
        relativePath: delivery['primaryScreenshotRef'] as String?,
      ),
      attachmentPaths: _resolvePaths(
        bundleDir: bundleDir,
        relativePaths: delivery['attachmentRefs'],
      ),
      primaryRecordingPath: _resolvePath(
        bundleDir: bundleDir,
        relativePath: delivery['primaryRecordingRef'] as String?,
      ),
      videoAttachmentPaths: _resolvePaths(
        bundleDir: bundleDir,
        relativePaths: delivery['videoAttachmentRefs'],
      ),
      keyframePaths: _resolveKeyframePaths(
        bundleDir: bundleDir,
        delivery: delivery,
      ),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        if (primaryScreenshotPath != null)
          'primaryScreenshotPath': primaryScreenshotPath,
        'attachmentPaths': attachmentPaths,
        if (primaryRecordingPath != null)
          'primaryRecordingPath': primaryRecordingPath,
        'videoAttachmentPaths': videoAttachmentPaths,
        'keyframePaths': keyframePaths,
      };

  static String? _resolvePath({
    required String bundleDir,
    required String? relativePath,
  }) {
    if (relativePath == null || relativePath.isEmpty) {
      return null;
    }
    return resolveBundleArtifactPath(bundleDir, relativePath);
  }

  static List<String> _resolvePaths({
    required String bundleDir,
    required Object? relativePaths,
  }) {
    final values = (relativePaths as List<Object?>? ?? const <Object?>[])
        .whereType<String>()
        .where((path) => path.isNotEmpty)
        .map((path) => resolveBundleArtifactPath(bundleDir, path))
        .whereType<String>()
        .toList(growable: false);
    return values;
  }

  static List<String> _resolveKeyframePaths({
    required String bundleDir,
    required Map<String, Object?> delivery,
  }) {
    final keyframes =
        (delivery['keyframes'] as List<Object?>? ?? const <Object?>[])
            .whereType<Map<Object?, Object?>>()
            .map((item) => Map<String, Object?>.from(item))
            .map((item) => item['ref'])
            .whereType<String>()
            .where((path) => path.isNotEmpty)
            .map(
              (path) => resolveBundleArtifactPath(
                bundleDir,
                path,
                allowedRoots: const <String>{'keyframes'},
              ),
            )
            .whereType<String>()
            .toList(growable: false);
    return keyframes;
  }

  static String? resolveBundleArtifactPath(
    String bundleDir,
    String relativePath, {
    Set<String> allowedRoots = _allowedArtifactRoots,
  }) {
    final normalized = p.normalize(relativePath);
    final allowedRoot = normalized.split(p.separator).firstOrNull;
    if (normalized.isEmpty ||
        p.isAbsolute(normalized) ||
        normalized == '.' ||
        normalized == '..' ||
        normalized.startsWith('..${p.separator}') ||
        !allowedRoots.contains(allowedRoot)) {
      return null;
    }

    final bundleRoot = p.canonicalize(bundleDir);
    final resolvedPath = p.canonicalize(p.join(bundleRoot, normalized));
    if (!p.isWithin(bundleRoot, resolvedPath)) {
      return null;
    }
    return resolvedPath;
  }

  static Set<String> allowedRootsForArtifactRole(String role) {
    return switch (role) {
      'screenshot' || 'step_screenshot' => const <String>{'screenshots'},
      'recording' => const <String>{'recordings'},
      'keyframe' => const <String>{'keyframes'},
      'diagnostics' => const <String>{'diagnostics'},
      _ => _allowedArtifactRoots,
    };
  }

  static const Set<String> _allowedArtifactRoots = <String>{
    'screenshots',
    'recordings',
    'keyframes',
    'diagnostics',
  };
}

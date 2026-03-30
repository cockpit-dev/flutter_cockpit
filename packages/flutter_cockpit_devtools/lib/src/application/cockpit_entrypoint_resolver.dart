import 'dart:io';

import 'package:path/path.dart' as p;

import 'cockpit_application_service_exception.dart';

typedef CockpitEntrypointExists = bool Function(String absolutePath);

final class CockpitEntrypointResolver {
  CockpitEntrypointResolver({CockpitEntrypointExists? exists})
      : _exists = exists ?? ((absolutePath) => File(absolutePath).existsSync());

  final CockpitEntrypointExists _exists;

  String resolve({
    required String projectDir,
    String? target,
  }) {
    final normalizedProjectDir = p.normalize(projectDir);
    final requestedTarget = _normalizeTarget(target);
    if (requestedTarget != null) {
      _ensureExists(
        projectDir: normalizedProjectDir,
        target: requestedTarget,
      );
      return requestedTarget;
    }

    for (final candidate in const <String>[
      'cockpit/main.dart',
      'lib/main.dart'
    ]) {
      if (_exists(p.join(normalizedProjectDir, candidate))) {
        return candidate;
      }
    }

    throw const CockpitApplicationServiceException(
      code: 'missingTargetEntrypoint',
      message:
          'No Flutter entrypoint found. Pass --target or add cockpit/main.dart or lib/main.dart.',
    );
  }

  void _ensureExists({
    required String projectDir,
    required String target,
  }) {
    if (_exists(p.join(projectDir, target))) {
      return;
    }
    throw CockpitApplicationServiceException(
      code: 'missingTargetEntrypoint',
      message: 'Target entrypoint does not exist: $target',
      details: <String, Object?>{
        'project_dir': projectDir,
        'target': target,
      },
    );
  }

  String? _normalizeTarget(String? target) {
    if (target == null) {
      return null;
    }
    final trimmed = target.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return p.normalize(trimmed);
  }
}

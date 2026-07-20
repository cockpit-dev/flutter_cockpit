import 'dart:convert';
import 'dart:io';

import 'package:cockpit_protocol/cockpit_protocol.dart';
import 'package:path/path.dart' as p;

import 'cockpit_application_service_exception.dart';
import 'cockpit_bundle_artifact_paths.dart';

final class CockpitBundleDiagnosticsArtifactRefs {
  const CockpitBundleDiagnosticsArtifactRefs._();

  static String? resolvePath(String bundleDir, String relativePath) {
    return CockpitBundleArtifactPaths.resolveBundleArtifactPath(
      bundleDir,
      relativePath,
      allowedRoots: const <String>{'diagnostics'},
    );
  }

  static List<CockpitArtifactRef> readBundleRefs(String bundleDir) {
    return List<CockpitArtifactRef>.unmodifiable(<CockpitArtifactRef>[
      ..._readStepRefs(bundleDir),
      ..._readObservationRefs(bundleDir),
    ]);
  }

  static List<CockpitArtifactRef> _readStepRefs(String bundleDir) {
    final stepsFile = File(p.join(bundleDir, 'steps.json'));
    if (!stepsFile.existsSync()) {
      return const <CockpitArtifactRef>[];
    }
    final decoded = jsonDecode(stepsFile.readAsStringSync());
    if (decoded is! List<Object?>) {
      throw CockpitApplicationServiceException(
        code: 'invalidBundleJson',
        message: 'steps.json must decode to a list.',
        details: <String, Object?>{'path': stepsFile.path},
      );
    }

    final refs = <CockpitArtifactRef>[];
    for (final item in decoded.cast<Object?>()) {
      if (item is! Map<Object?, Object?>) {
        continue;
      }
      final step = CockpitStepRecord.fromJson(Map<String, Object?>.from(item));
      final diagnosticsArtifactRef = step.snapshot?.diagnosticsArtifactRef;
      if (diagnosticsArtifactRef != null) {
        refs.add(diagnosticsArtifactRef);
      }
      refs.addAll(
        step.artifactRefs.where((artifact) => artifact.role == 'diagnostics'),
      );
    }
    return List<CockpitArtifactRef>.unmodifiable(refs);
  }

  static List<CockpitArtifactRef> _readObservationRefs(String bundleDir) {
    final observationsFile = File(p.join(bundleDir, 'observations.json'));
    if (!observationsFile.existsSync()) {
      return const <CockpitArtifactRef>[];
    }
    final decoded = jsonDecode(observationsFile.readAsStringSync());
    if (decoded is! List<Object?>) {
      throw CockpitApplicationServiceException(
        code: 'invalidBundleJson',
        message: 'observations.json must decode to a list.',
        details: <String, Object?>{'path': observationsFile.path},
      );
    }

    final refs = <CockpitArtifactRef>[];
    for (final item in decoded.cast<Object?>()) {
      if (item is! Map<Object?, Object?>) {
        continue;
      }
      final observation = CockpitObservation.fromJson(
        Map<String, Object?>.from(item),
      );
      final diagnosticsArtifactRef = observation.diagnosticsArtifactRef;
      if (diagnosticsArtifactRef != null) {
        refs.add(diagnosticsArtifactRef);
      }
    }
    return List<CockpitArtifactRef>.unmodifiable(refs);
  }
}

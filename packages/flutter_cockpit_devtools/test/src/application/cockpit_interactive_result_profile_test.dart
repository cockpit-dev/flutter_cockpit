import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_application_service_exception.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_interactive_result_profile.dart';
import 'package:test/test.dart';

void main() {
  group('CockpitInteractiveResultProfile', () {
    test('uses compact defaults', () {
      const profile = CockpitInteractiveResultProfile.compact();

      expect(profile.name, CockpitInteractiveResultProfileName.compact);
      expect(profile.ui, CockpitInteractiveUiLevel.none);
      expect(profile.diagnostics, CockpitInteractiveDiagnosticsLevel.none);
      expect(profile.artifacts, CockpitInteractiveArtifactLevel.none);
      expect(profile.includeDelta, isFalse);
      expect(profile.includeRuntimeSteps, isFalse);
      expect(profile.emitSnapshotRef, isFalse);
      expect(
        profile.resolveSnapshotOptions().profile,
        CockpitSnapshotProfile.live,
      );
    });

    test('uses inspect defaults', () {
      const profile = CockpitInteractiveResultProfile.inspect();

      expect(profile.name, CockpitInteractiveResultProfileName.inspect);
      expect(profile.ui, CockpitInteractiveUiLevel.summary);
      expect(
        profile.diagnostics,
        CockpitInteractiveDiagnosticsLevel.failuresOnly,
      );
      expect(profile.artifacts, CockpitInteractiveArtifactLevel.metadata);
      expect(profile.includeDelta, isTrue);
      expect(profile.includeRuntimeSteps, isTrue);
      expect(profile.emitSnapshotRef, isTrue);

      final snapshotOptions = profile.resolveSnapshotOptions();
      expect(snapshotOptions.profile, CockpitSnapshotProfile.investigate);
      expect(snapshotOptions.includeNetworkActivity, isTrue);
      expect(snapshotOptions.networkQuery.onlyFailures, isTrue);
      expect(snapshotOptions.includeRuntimeActivity, isTrue);
      expect(snapshotOptions.runtimeQuery.onlyErrors, isTrue);
    });

    test('allows layer overrides on a preset', () {
      final profile = CockpitInteractiveResultProfile.fromJson(
        const <String, Object?>{
          'profile': 'standard',
          'ui': 'snapshot',
          'diagnostics': 'full',
          'artifacts': 'metadata',
          'include_delta': true,
          'include_runtime_steps': true,
          'emit_snapshot_ref': false,
          'snapshot_profile': 'forensic',
        },
      );

      expect(profile.name, CockpitInteractiveResultProfileName.standard);
      expect(profile.ui, CockpitInteractiveUiLevel.snapshot);
      expect(profile.diagnostics, CockpitInteractiveDiagnosticsLevel.full);
      expect(profile.artifacts, CockpitInteractiveArtifactLevel.metadata);
      expect(profile.includeDelta, isTrue);
      expect(profile.includeRuntimeSteps, isTrue);
      expect(profile.emitSnapshotRef, isFalse);
      expect(
        profile.resolveSnapshotOptions().profile,
        CockpitSnapshotProfile.forensic,
      );
    });

    test('preserves an explicitly richer snapshot options override', () {
      const profile = CockpitInteractiveResultProfile.compact();
      final options = profile.resolveSnapshotOptions(
        const CockpitSnapshotOptions.forensic(),
      );

      expect(options.profile, CockpitSnapshotProfile.forensic);
      expect(options.includeRuntimeActivity, isTrue);
      expect(options.includeNetworkActivity, isTrue);
    });

    test('rejects an unknown preset', () {
      expect(
        () => CockpitInteractiveResultProfile.fromJson(
          const <String, Object?>{'profile': 'mystery'},
        ),
        throwsA(
          isA<CockpitApplicationServiceException>().having(
            (error) => error.code,
            'code',
            'invalidInteractiveResultProfile',
          ),
        ),
      );
    });

    test('rejects an unknown layer value', () {
      expect(
        () => CockpitInteractiveResultProfile.fromJson(
          const <String, Object?>{'ui': 'verbose'},
        ),
        throwsA(
          isA<CockpitApplicationServiceException>().having(
            (error) => error.code,
            'code',
            'invalidInteractiveResultProfile',
          ),
        ),
      );
    });
  });
}

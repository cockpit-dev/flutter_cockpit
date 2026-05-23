import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('execution policy round-trips through json values', () {
    expect(
      CockpitExecutionPolicy.fromJson(
        CockpitExecutionPolicy.preferFlutter.name,
      ),
      CockpitExecutionPolicy.preferFlutter,
    );
    expect(
      CockpitExecutionPolicy.fromJson(CockpitExecutionPolicy.noFallback.name),
      CockpitExecutionPolicy.noFallback,
    );
  });

  test('evidence policy preserves before and after capture defaults', () {
    const policy = CockpitEvidencePolicy(
      captureBeforeAction: true,
      captureAfterAction: true,
      captureOnFailure: true,
      attachArtifactMetadataOnly: true,
      escalateToDiagnosticsOnAmbiguity: true,
    );

    expect(CockpitEvidencePolicy.fromJson(policy.toJson()), policy);
    expect(policy.toJson()['captureOnFailure'], isTrue);
    expect(policy.toJson()['attachArtifactMetadataOnly'], isTrue);
  });
}

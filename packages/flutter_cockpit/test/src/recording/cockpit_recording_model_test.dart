import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CockpitRecordingPurpose round-trips through json', () {
    expect(
      CockpitRecordingPurpose.fromJson(CockpitRecordingPurpose.acceptance.name),
      CockpitRecordingPurpose.acceptance,
    );
    expect(
      CockpitRecordingPurpose.fromJson('diagnostic'),
      CockpitRecordingPurpose.repro,
    );
    expect(
      CockpitRecordingPurpose.fromJson('debug'),
      CockpitRecordingPurpose.repro,
    );
    expect(
      CockpitRecordingPurpose.fromJson('investigation'),
      CockpitRecordingPurpose.repro,
    );
  });

  test('CockpitRecordingState round-trips through json', () {
    expect(
      CockpitRecordingState.fromJson(CockpitRecordingState.recording.name),
      CockpitRecordingState.recording,
    );
  });

  test(
    'CockpitRecordingRequest preserves purpose, attachment, and tail stabilization metadata',
    () {
      final request = CockpitRecordingRequest(
        purpose: CockpitRecordingPurpose.acceptance,
        name: 'home_acceptance',
        attachToStep: true,
        tailStabilizationDelay: const Duration(milliseconds: 1450),
      );

      expect(CockpitRecordingRequest.fromJson(request.toJson()), request);
      expect(request.toJson()['tailStabilizationMs'], 1450);
    },
  );

  test('CockpitRecordingRequest defaults name from purpose when omitted', () {
    final request = CockpitRecordingRequest.fromJson(
      <String, Object?>{'purpose': 'acceptance'},
    );

    expect(request.purpose, CockpitRecordingPurpose.acceptance);
    expect(request.name, 'acceptance');
  });

  test('CockpitRecordingResult preserves state, artifact, and duration', () {
    final result = CockpitRecordingResult(
      state: CockpitRecordingState.completed,
      purpose: CockpitRecordingPurpose.acceptance,
      recordingKind: CockpitRecordingKind.nativeScreen,
      artifact: const CockpitArtifactRef(
        role: 'recording',
        relativePath: 'recordings/home_acceptance.mp4',
      ),
      durationMs: 4200,
      bytes: const [1, 2, 3, 4],
    );

    expect(CockpitRecordingResult.fromJson(result.toJson()), result);
  });

  test('CockpitRunManifest preserves recording delivery metadata', () {
    final manifest = CockpitRunManifest(
      sessionId: 'session-recording',
      taskId: 'task-home',
      platform: 'android',
      status: CockpitTaskStatus.completed,
      startedAt: DateTime.utc(2026, 3, 20, 13),
      finishedAt: DateTime.utc(2026, 3, 20, 13, 2),
      recordingCount: 1,
      nativeRecordingCount: 1,
      deliveryVideoReady: true,
    );

    expect(CockpitRunManifest.fromJson(manifest.toJson()), manifest);
  });

  test('CockpitContextBundle preserves delivery video metadata', () {
    final bundle = CockpitContextBundle(
      manifest: CockpitRunManifest(
        sessionId: 'session-recording',
        taskId: 'task-home',
        platform: 'ios',
        status: CockpitTaskStatus.completed,
        startedAt: DateTime.utc(2026, 3, 20, 13),
        finishedAt: DateTime.utc(2026, 3, 20, 13, 1),
        recordingCount: 1,
        nativeRecordingCount: 1,
        deliveryVideoReady: true,
      ),
      environment: const CockpitEnvironment(
        platform: 'ios',
        flutterVersion: '3.38.9',
        dartVersion: '3.10.8',
      ),
      acceptanceMarkdown: '# Acceptance\n\nRecorded.',
      handoff: const {'status': 'completed'},
      delivery: const <String, Object?>{
        'primaryRecordingRef': 'recordings/home_acceptance.mp4',
        'videoAttachmentRefs': ['recordings/home_acceptance.mp4'],
        'deliveryVideoReady': true,
      },
    );

    expect(CockpitContextBundle.fromJson(bundle.toJson()), bundle);
  });
}

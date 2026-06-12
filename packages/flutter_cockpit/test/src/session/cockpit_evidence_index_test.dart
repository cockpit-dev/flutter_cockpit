import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('selects acceptance screenshots as primary and de-duplicates refs', () {
    final index = CockpitEvidenceIndex.fromSteps(<CockpitStepRecord>[
      CockpitStepRecord(
        index: 0,
        actionType: 'capture',
        actionArgs: const <String, Object?>{},
        observedAt: DateTime.utc(2026, 3, 30, 10, 0, 0),
        artifactRefs: const <CockpitArtifactRef>[
          CockpitArtifactRef(
            role: 'recording',
            relativePath: 'recordings/run.mp4',
          ),
        ],
        requestedCaptureProfile: CockpitCaptureProfile.diagnostic,
        captureRefs: const <CockpitArtifactRef>[
          CockpitArtifactRef(
            role: 'screenshot',
            relativePath: 'screenshots/baseline.png',
          ),
        ],
      ),
      CockpitStepRecord(
        index: 1,
        actionType: 'capture',
        actionArgs: const <String, Object?>{'recordingPurpose': 'acceptance'},
        observedAt: DateTime.utc(2026, 3, 30, 10, 0, 1),
        artifactRefs: const <CockpitArtifactRef>[
          CockpitArtifactRef(
            role: 'recording',
            relativePath: 'recordings/run.mp4',
          ),
        ],
        requestedCaptureProfile: CockpitCaptureProfile.acceptance,
        captureRefs: const <CockpitArtifactRef>[
          CockpitArtifactRef(
            role: 'screenshot',
            relativePath: 'screenshots/acceptance.png',
          ),
        ],
      ),
    ]);

    expect(index.primaryScreenshotRef, 'screenshots/acceptance.png');
    expect(index.primaryRecordingRef, 'recordings/run.mp4');
    expect(index.screenshotRefs, <String>[
      'screenshots/baseline.png',
      'screenshots/acceptance.png',
    ]);
    expect(index.recordingRefs, <String>['recordings/run.mp4']);
    expect(index.deliveryArtifactsReady, isTrue);
    expect(index.deliveryVideoReady, isTrue);
  });

  test('counts step_screenshot artifacts as screenshot evidence', () {
    final index = CockpitEvidenceIndex.fromSteps(<CockpitStepRecord>[
      CockpitStepRecord(
        index: 0,
        actionType: 'tap',
        actionArgs: const <String, Object?>{},
        observedAt: DateTime.utc(2026, 3, 30, 10, 0, 0),
        requestedCaptureProfile: CockpitCaptureProfile.diagnostic,
        captureRefs: const <CockpitArtifactRef>[
          CockpitArtifactRef(
            role: 'step_screenshot',
            relativePath: 'screenshots/step_000.png',
          ),
        ],
      ),
      CockpitStepRecord(
        index: 1,
        actionType: 'capture',
        actionArgs: const <String, Object?>{},
        observedAt: DateTime.utc(2026, 3, 30, 10, 0, 1),
        requestedCaptureProfile: CockpitCaptureProfile.acceptance,
        resolvedCaptureKind: CockpitCaptureKind.flutterView,
        captureRefs: const <CockpitArtifactRef>[
          CockpitArtifactRef(
            role: 'screenshot',
            relativePath: 'screenshots/acceptance.png',
          ),
        ],
      ),
    ]);

    expect(index.screenshotRefs, <String>[
      'screenshots/step_000.png',
      'screenshots/acceptance.png',
    ]);
    expect(index.screenshotCount, 2);
    expect(index.flutterScreenshotCount, 1);
    expect(index.primaryScreenshotRef, 'screenshots/acceptance.png');
    expect(index.deliveryArtifactsReady, isTrue);
  });

  test('derives nativeRecordingCount from recording kind metadata', () {
    final index = CockpitEvidenceIndex.fromSteps(<CockpitStepRecord>[
      CockpitStepRecord(
        index: 0,
        actionType: 'recording_stopped',
        actionArgs: const <String, Object?>{
          'recordingPurpose': 'acceptance',
          'recordingKind': 'nativeScreen',
        },
        observedAt: DateTime.utc(2026, 3, 30, 10, 0, 0),
        artifactRefs: const <CockpitArtifactRef>[
          CockpitArtifactRef(
            role: 'recording',
            relativePath: 'recordings/native.mp4',
          ),
        ],
      ),
      CockpitStepRecord(
        index: 1,
        actionType: 'recording_stopped',
        actionArgs: const <String, Object?>{
          'recordingPurpose': 'diagnostic',
          'recordingKind': 'flutterTimeline',
        },
        observedAt: DateTime.utc(2026, 3, 30, 10, 0, 1),
        artifactRefs: const <CockpitArtifactRef>[
          CockpitArtifactRef(
            role: 'recording',
            relativePath: 'recordings/timeline.webm',
          ),
        ],
      ),
      CockpitStepRecord(
        index: 2,
        actionType: 'recording_stopped',
        actionArgs: const <String, Object?>{'recordingPurpose': 'acceptance'},
        observedAt: DateTime.utc(2026, 3, 30, 10, 0, 2),
        artifactRefs: const <CockpitArtifactRef>[
          CockpitArtifactRef(
            role: 'recording',
            relativePath: 'recordings/legacy.mp4',
          ),
        ],
      ),
    ]);

    expect(index.recordingCount, 3);
    expect(index.nativeRecordingCount, 2);
  });
}

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
          CockpitArtifactRef(role: 'recording', relativePath: 'recordings/run.mp4'),
        ],
        requestedCaptureProfile: CockpitCaptureProfile.diagnostic,
        captureRefs: const <CockpitArtifactRef>[
          CockpitArtifactRef(role: 'screenshot', relativePath: 'screenshots/baseline.png'),
        ],
      ),
      CockpitStepRecord(
        index: 1,
        actionType: 'capture',
        actionArgs: const <String, Object?>{
          'recordingPurpose': 'acceptance',
        },
        observedAt: DateTime.utc(2026, 3, 30, 10, 0, 1),
        artifactRefs: const <CockpitArtifactRef>[
          CockpitArtifactRef(role: 'recording', relativePath: 'recordings/run.mp4'),
        ],
        requestedCaptureProfile: CockpitCaptureProfile.acceptance,
        captureRefs: const <CockpitArtifactRef>[
          CockpitArtifactRef(role: 'screenshot', relativePath: 'screenshots/acceptance.png'),
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
}

import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('session close counts recording artifacts and delivery readiness', () {
    final timestamps = <DateTime>[
      DateTime.utc(2026, 3, 20, 13, 0, 0),
      DateTime.utc(2026, 3, 20, 13, 0, 1),
      DateTime.utc(2026, 3, 20, 13, 0, 2),
      DateTime.utc(2026, 3, 20, 13, 0, 3),
      DateTime.utc(2026, 3, 20, 13, 0, 4),
    ].iterator;

    DateTime nextTimestamp() {
      final didMove = timestamps.moveNext();
      if (!didMove) {
        throw StateError('No more timestamps available.');
      }
      return timestamps.current;
    }

    final controller = CockpitSessionController(
      sessionId: 'session-recording',
      taskId: 'task-home',
      platform: 'android',
      now: nextTimestamp,
    );

    controller.recordStep(
      actionType: 'recording_start_requested',
      actionArgs: const <String, Object?>{
        'recordingName': 'home_acceptance',
        'recordingPurpose': 'acceptance',
        'recordingState': 'starting',
      },
    );
    controller.recordStep(
      actionType: 'recording_started',
      actionArgs: const <String, Object?>{
        'recordingName': 'home_acceptance',
        'recordingPurpose': 'acceptance',
        'recordingState': 'recording',
      },
    );
    controller.recordStep(
      actionType: 'recording_stopped',
      actionArgs: const <String, Object?>{
        'recordingName': 'home_acceptance',
        'recordingPurpose': 'acceptance',
        'recordingState': 'completed',
        'recordingDurationMs': 2400,
      },
      artifactRefs: const [
        CockpitArtifactRef(
          role: 'recording',
          relativePath: 'recordings/home_acceptance.mp4',
        ),
      ],
    );

    final bundle = controller.finish(
      environment: const CockpitEnvironment(
        platform: 'android',
        flutterVersion: '3.38.9',
        dartVersion: '3.10.8',
      ),
      capabilitiesUsed: const ['nativeRecording'],
    );

    expect(bundle.manifest.recordingCount, 1);
    expect(bundle.manifest.nativeRecordingCount, 1);
    expect(bundle.manifest.deliveryVideoReady, isTrue);
    expect(
      bundle.delivery['primaryRecordingRef'],
      'recordings/home_acceptance.mp4',
    );
    expect(bundle.delivery['deliveryVideoReady'], isTrue);
    expect(bundle.delivery['videoAttachmentRefs'], const [
      'recordings/home_acceptance.mp4',
    ]);
    expect(bundle.acceptanceMarkdown, contains('home_acceptance.mp4'));
  });

  test('recording failure does not mark delivery video ready', () {
    final timestamps = <DateTime>[
      DateTime.utc(2026, 3, 20, 13, 0, 0),
      DateTime.utc(2026, 3, 20, 13, 0, 1),
      DateTime.utc(2026, 3, 20, 13, 0, 2),
    ].iterator;

    DateTime nextTimestamp() {
      final didMove = timestamps.moveNext();
      if (!didMove) {
        throw StateError('No more timestamps available.');
      }
      return timestamps.current;
    }

    final controller = CockpitSessionController(
      sessionId: 'session-recording-failure',
      taskId: 'task-home',
      platform: 'ios',
      now: nextTimestamp,
    );

    controller.recordStep(
      actionType: 'recording_failed',
      actionArgs: const <String, Object?>{
        'recordingName': 'home_acceptance',
        'recordingPurpose': 'acceptance',
        'recordingState': 'failed',
        'failureReason': 'permissionDenied',
      },
    );

    final bundle = controller.finish(
      environment: const CockpitEnvironment(
        platform: 'ios',
        flutterVersion: '3.38.9',
        dartVersion: '3.10.8',
      ),
      capabilitiesUsed: const ['nativeRecording'],
    );

    expect(bundle.manifest.recordingCount, 0);
    expect(bundle.manifest.deliveryVideoReady, isFalse);
    expect(bundle.manifest.deliveryVideoFailureCodes, const <String>[
      'recordingFailed',
    ]);
    expect(bundle.delivery['primaryRecordingRef'], isNull);
    expect(bundle.delivery['videoAttachmentRefs'], isEmpty);
    expect(
      (((bundle.delivery['readiness'] as Map<Object?, Object?>)['video']
                  as Map<Object?, Object?>)['failureCodes']
              as List<Object?>)
          .cast<String>(),
      const <String>['recordingFailed'],
    );
    expect(bundle.acceptanceMarkdown, contains('Recording unavailable'));
  });
}

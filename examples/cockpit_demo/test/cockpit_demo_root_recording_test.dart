import 'dart:io';

import 'package:flutter_cockpit/flutter_cockpit_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:cockpit_demo/src/data/cockpit_demo_database.dart';

import 'support/cockpit_demo_test_support.dart';

void main() {
  testWidgets(
    'records a root-level Todo acceptance video and writes it into the task bundle',
    (tester) async {
      final outputDirectory = Directory.systemTemp.createTempSync(
        'cockpit_demo_recording_test',
      );
      addTearDown(() => deleteDirectory(outputDirectory));

      final tempRecording = File(p.join(outputDirectory.path, 'recording.mp4'));
      tempRecording.parent.createSync(recursive: true);
      tempRecording.writeAsBytesSync(validMp4Bytes);

      final controller = buildTestController(
        sessionId: 'root-recording-session',
        taskId: 'root-recording-task',
        platform: 'android',
      );
      final database = CockpitDemoDatabase.inMemory();
      addCockpitDemoDatabaseTearDown(tester, database);

      await pumpTodoApp(
        tester,
        controller: controller,
        database: database,
        configuration: FlutterCockpitConfiguration(
          initialRouteName: '/inbox',
          nativeRecording: FakeCockpitNativeRecording(
            sourceFilePath: tempRecording.path,
          ),
        ),
      );

      final rootState = tester.state<FlutterCockpitRootState>(
        find.byType(FlutterCockpitRoot),
      );

      controller.recordStep(
        actionType: 'recording_start_requested',
        actionArgs: const <String, Object?>{
          'recordingName': 'todo_acceptance',
          'recordingPurpose': 'acceptance',
          'recordingState': 'starting',
        },
      );
      final session = await rootState.startRecording(
        const CockpitRecordingRequest(
          purpose: CockpitRecordingPurpose.acceptance,
          name: 'todo_acceptance',
          attachToStep: true,
        ),
      );
      controller.recordStep(
        actionType: 'recording_started',
        actionArgs: <String, Object?>{
          'recordingName': session.request.name,
          'recordingPurpose': session.request.purpose.name,
          'recordingState': session.state.name,
        },
      );

      await createTaskThroughUi(
        tester,
        title: 'Record Todo acceptance',
        notes: 'Persist the finished recording into the bundle',
        priorityLabel: 'URGENT',
        dueLabel: 'Tomorrow',
      );

      final result = await rootState.stopRecording();
      controller.recordStep(
        actionType: 'recording_stopped',
        actionArgs: <String, Object?>{
          'recordingName': session.request.name,
          'recordingPurpose': session.request.purpose.name,
          'recordingState': result.state.name,
          'recordingDurationMs': result.durationMs,
        },
        artifactRefs: result.artifact == null
            ? const <CockpitArtifactRef>[]
            : <CockpitArtifactRef>[result.artifact!],
      );

      final bundle = controller.finish(
        environment: const CockpitEnvironment(
          platform: 'android',
          flutterVersion: '3.38.9',
          dartVersion: '3.10.8',
        ),
        capabilitiesUsed: const <String>['nativeRecording'],
      );

      final writtenBundle = await buildTestBundleWriter().writeBundle(
        bundle: bundle,
        outputRoot: outputDirectory.path,
        artifactSourcePaths: <String, String>{
          result.artifact!.relativePath: result.sourceFilePath!,
        },
      );

      expect(find.text('Record Todo acceptance'), findsWidgets);
      expect(bundle.manifest.recordingCount, 1);
      expect(bundle.manifest.deliveryVideoReady, isTrue);
      expect(
        File(
          p.join(writtenBundle.path, 'recordings', 'todo_acceptance.mp4'),
        ).readAsBytesSync(),
        validMp4Bytes,
      );
      expect(
        bundle.delivery['primaryRecordingRef'],
        'recordings/todo_acceptance.mp4',
      );
    },
  );
}

import 'dart:io';

import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:cockpit/src/application/cockpit_stop_remote_recording_service.dart';
import 'package:cockpit/src/session/cockpit_remote_session_handle.dart';
import 'package:test/test.dart';

void main() {
  group('CockpitStopRemoteRecordingService', () {
    test('stops recording and returns artifact metadata', () async {
      final sourceFile = await _recordingSourceFile('remote-recording-bytes');
      final service = CockpitStopRemoteRecordingService(
        stopRecording: (_) async => CockpitRecordingResult(
          state: CockpitRecordingState.completed,
          purpose: CockpitRecordingPurpose.acceptance,
          recordingKind: CockpitRecordingKind.nativeScreen,
          artifact: const CockpitArtifactRef(
            role: 'recording',
            relativePath: 'recordings/final.mp4',
          ),
          durationMs: 1200,
          bytes: <int>[1, 2, 3, 4],
          sourceFilePath: sourceFile.path,
        ),
      );

      final result = await service.stop(
        CockpitStopRemoteRecordingRequest(sessionHandle: _sessionHandle()),
      );

      expect(result.state, CockpitRecordingState.completed);
      expect(result.artifact?.relativePath, 'recordings/final.mp4');
      expect(result.artifact?.byteLength, 4);
      expect(result.artifact?.sourcePath, sourceFile.path);
    });

    test(
      'reports file size when remote recording is stored as a source path',
      () async {
        final sourceFile = await _recordingSourceFile('remote-recording-file');
        final service = CockpitStopRemoteRecordingService(
          stopRecording: (_) async => CockpitRecordingResult(
            state: CockpitRecordingState.completed,
            purpose: CockpitRecordingPurpose.acceptance,
            recordingKind: CockpitRecordingKind.nativeScreen,
            artifact: const CockpitArtifactRef(
              role: 'recording',
              relativePath: 'recordings/final.mp4',
            ),
            durationMs: 1200,
            sourceFilePath: sourceFile.path,
          ),
        );

        final result = await service.stop(
          CockpitStopRemoteRecordingRequest(sessionHandle: _sessionHandle()),
        );

        expect(result.artifact?.byteLength, sourceFile.lengthSync());
        expect(result.artifact?.sourcePath, sourceFile.path);
      },
    );

    test(
      'marks completed recording failed when artifact reference is missing',
      () async {
        final service = CockpitStopRemoteRecordingService(
          stopRecording: (_) async => CockpitRecordingResult(
            state: CockpitRecordingState.completed,
            purpose: CockpitRecordingPurpose.acceptance,
            recordingKind: CockpitRecordingKind.nativeScreen,
            durationMs: 1200,
          ),
        );

        final result = await service.stop(
          CockpitStopRemoteRecordingRequest(sessionHandle: _sessionHandle()),
        );

        expect(result.state, CockpitRecordingState.failed);
        expect(result.artifact, isNull);
        expect(result.failureReason, contains('without an artifact reference'));
      },
    );

    test(
      'marks completed recording failed when inline bytes are empty',
      () async {
        final service = CockpitStopRemoteRecordingService(
          stopRecording: (_) async => CockpitRecordingResult(
            state: CockpitRecordingState.completed,
            purpose: CockpitRecordingPurpose.acceptance,
            recordingKind: CockpitRecordingKind.nativeScreen,
            artifact: const CockpitArtifactRef(
              role: 'recording',
              relativePath: 'recordings/empty.mp4',
            ),
            durationMs: 1200,
            bytes: const <int>[],
          ),
        );

        final result = await service.stop(
          CockpitStopRemoteRecordingRequest(sessionHandle: _sessionHandle()),
        );

        expect(result.state, CockpitRecordingState.failed);
        expect(result.artifact?.byteLength, 0);
        expect(result.failureReason, contains('bytes are empty'));
      },
    );

    test(
      'marks completed recording failed when source file is missing',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'flutter_cockpit_missing_recording_test_',
        );
        addTearDown(() async {
          if (await tempDir.exists()) {
            await tempDir.delete(recursive: true);
          }
        });
        final missingPath =
            '${tempDir.path}${Platform.pathSeparator}missing.mp4';
        final service = CockpitStopRemoteRecordingService(
          stopRecording: (_) async => CockpitRecordingResult(
            state: CockpitRecordingState.completed,
            purpose: CockpitRecordingPurpose.acceptance,
            recordingKind: CockpitRecordingKind.nativeScreen,
            artifact: const CockpitArtifactRef(
              role: 'recording',
              relativePath: 'recordings/missing.mp4',
            ),
            durationMs: 1200,
            sourceFilePath: missingPath,
          ),
        );

        final result = await service.stop(
          CockpitStopRemoteRecordingRequest(sessionHandle: _sessionHandle()),
        );

        expect(result.state, CockpitRecordingState.failed);
        expect(result.artifact?.sourcePath, missingPath);
        expect(result.failureReason, contains('does not exist'));
      },
    );

    test('preserves structured failure reasons', () async {
      final service = CockpitStopRemoteRecordingService(
        stopRecording: (_) async => CockpitRecordingResult(
          state: CockpitRecordingState.failed,
          purpose: CockpitRecordingPurpose.acceptance,
          failureReason: 'unsupported_recording',
        ),
      );

      final result = await service.stop(
        CockpitStopRemoteRecordingRequest(sessionHandle: _sessionHandle()),
      );

      expect(result.state, CockpitRecordingState.failed);
      expect(result.failureReason, 'unsupported_recording');
    });
  });
}

Future<File> _recordingSourceFile(String name) async {
  final tempDir = await Directory.systemTemp.createTemp(
    'flutter_cockpit_stop_remote_recording_test_',
  );
  addTearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });
  return File('${tempDir.path}${Platform.pathSeparator}$name.mp4')
    ..writeAsStringSync(name);
}

CockpitRemoteSessionHandle _sessionHandle() {
  return CockpitRemoteSessionHandle(
    platform: 'macos',
    deviceId: 'macos',
    projectDir: '/workspace/examples/cockpit_demo',
    target: 'cockpit/main.dart',
    appId: 'dev.cockpit.demo',
    host: '127.0.0.1',
    hostPort: 47331,
    devicePort: 47331,
    baseUrl: 'http://127.0.0.1:47331',
    launchedAt: DateTime.utc(2026, 3, 30),
  );
}

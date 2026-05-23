import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_app_handle.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_execute_remote_command_batch_service.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_interactive_result_profile.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_run_batch_service.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_start_recording_service.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_stop_recording_service.dart';
import 'package:flutter_cockpit_devtools/src/session/cockpit_remote_session_handle.dart';
import 'package:test/test.dart';

void main() {
  group('CockpitRunBatchService', () {
    test(
      'wraps app-first batch recording with app-aware recording services',
      () async {
        var remoteStartCount = 0;
        var remoteStopCount = 0;
        CockpitStartRecordingRequest? capturedStart;
        CockpitStopRecordingRequest? capturedStop;
        final service = CockpitRunBatchService(
          executeService: CockpitExecuteRemoteCommandBatchService(
            startRecording: (_, _) async {
              remoteStartCount += 1;
              throw StateError('remote recording should not start');
            },
            stopRecording: (_) async {
              remoteStopCount += 1;
              throw StateError('remote recording should not stop');
            },
            executeCommand: (_, command) async => CockpitCommandExecution(
              result: CockpitCommandResult(
                success: true,
                commandId: command.commandId,
                commandType: command.commandType,
                durationMs: 24,
              ),
            ),
          ),
          startRecording: (request) async {
            capturedStart = request;
            return CockpitStartRecordingResult(
              recordingSession: CockpitRecordingSession(
                request: request.recording,
                state: CockpitRecordingState.recording,
              ),
            );
          },
          stopRecording: (request) async {
            capturedStop = request;
            return const CockpitStopRecordingResult(
              state: CockpitRecordingState.completed,
            );
          },
        );

        final result = await service.run(
          CockpitRunBatchRequest(
            app: _appHandle(),
            defaultResultProfile:
                const CockpitInteractiveResultProfile.minimal(),
            commands: <CockpitRunBatchCommand>[_batchCommand('tap-save')],
            recording: _recordingRequest(),
          ),
        );

        expect(remoteStartCount, 0);
        expect(remoteStopCount, 0);
        expect(capturedStart?.app?.appId, 'dev.cockpit.demo');
        expect(capturedStop?.app?.appId, 'dev.cockpit.demo');
        expect(result.summary.totalCount, 1);
        expect(
          result.recordingSession?.recordingSession.state,
          CockpitRecordingState.recording,
        );
        expect(result.recordingResult?.state, CockpitRecordingState.completed);
        expect(result.sessionHandle?.toJson(), _remoteSessionHandle().toJson());
        expect(
          result.results.single.sessionHandle?.toJson(),
          _remoteSessionHandle().toJson(),
        );
      },
    );

    test(
      'passes explicit iOS device id through batch recording wrappers',
      () async {
        CockpitStartRecordingRequest? capturedStart;
        CockpitStopRecordingRequest? capturedStop;
        final service = CockpitRunBatchService(
          executeService: CockpitExecuteRemoteCommandBatchService(
            executeCommand: (_, command) async => CockpitCommandExecution(
              result: CockpitCommandResult(
                success: true,
                commandId: command.commandId,
                commandType: command.commandType,
                durationMs: 24,
              ),
            ),
          ),
          startRecording: (request) async {
            capturedStart = request;
            return CockpitStartRecordingResult(
              recordingSession: CockpitRecordingSession(
                request: request.recording,
                state: CockpitRecordingState.recording,
              ),
            );
          },
          stopRecording: (request) async {
            capturedStop = request;
            return const CockpitStopRecordingResult(
              state: CockpitRecordingState.completed,
            );
          },
        );

        await service.run(
          CockpitRunBatchRequest(
            baseUri: Uri.parse('http://127.0.0.1:47331'),
            iosDeviceId: '6FD25DED-11E9-4AE9-B4B5-EDF4601981DC',
            defaultResultProfile:
                const CockpitInteractiveResultProfile.minimal(),
            commands: <CockpitRunBatchCommand>[_batchCommand('tap-save')],
            recording: _recordingRequest(),
          ),
        );

        expect(
          capturedStart?.iosDeviceId,
          '6FD25DED-11E9-4AE9-B4B5-EDF4601981DC',
        );
        expect(
          capturedStop?.iosDeviceId,
          '6FD25DED-11E9-4AE9-B4B5-EDF4601981DC',
        );
      },
    );

    test(
      'preserves app remote session handle for non-recorded batches',
      () async {
        Uri? capturedBaseUri;
        final service = CockpitRunBatchService(
          executeService: CockpitExecuteRemoteCommandBatchService(
            executeCommand: (baseUri, command) async {
              capturedBaseUri = baseUri;
              return CockpitCommandExecution(
                result: CockpitCommandResult(
                  success: true,
                  commandId: command.commandId,
                  commandType: command.commandType,
                  durationMs: 16,
                ),
              );
            },
          ),
        );

        final result = await service.run(
          CockpitRunBatchRequest(
            app: _appHandle(),
            defaultResultProfile:
                const CockpitInteractiveResultProfile.minimal(),
            commands: <CockpitRunBatchCommand>[_batchCommand('tap-save')],
          ),
        );

        expect(capturedBaseUri, _remoteSessionHandle().baseUri);
        expect(result.sessionHandle?.toJson(), _remoteSessionHandle().toJson());
        expect(
          result.results.single.sessionHandle?.toJson(),
          _remoteSessionHandle().toJson(),
        );
      },
    );

    test(
      'keeps resolved route-prefixed base uri in returned session handle',
      () async {
        Uri? capturedBaseUri;
        final service = CockpitRunBatchService(
          executeService: CockpitExecuteRemoteCommandBatchService(
            executeCommand: (baseUri, command) async {
              capturedBaseUri = baseUri;
              return CockpitCommandExecution(
                result: CockpitCommandResult(
                  success: true,
                  commandId: command.commandId,
                  commandType: command.commandType,
                  durationMs: 16,
                ),
              );
            },
          ),
        );

        final result = await service.run(
          CockpitRunBatchRequest(
            app: _appHandle(
              baseUrl: 'http://127.0.0.1:58421/cockpit',
              remoteSession: _remoteSessionHandle(
                baseUrl: 'http://127.0.0.1:47331',
              ),
            ),
            defaultResultProfile:
                const CockpitInteractiveResultProfile.minimal(),
            commands: <CockpitRunBatchCommand>[_batchCommand('tap-save')],
          ),
        );

        expect(capturedBaseUri, Uri.parse('http://127.0.0.1:58421/cockpit'));
        expect(result.sessionHandle?.baseUrl, 'http://127.0.0.1:58421/cockpit');
        expect(
          result.results.single.sessionHandle?.baseUrl,
          'http://127.0.0.1:58421/cockpit',
        );
      },
    );

    test('cleans up app-aware recording when a batch command throws', () async {
      var stopAttempts = 0;
      final service = CockpitRunBatchService(
        executeService: CockpitExecuteRemoteCommandBatchService(
          executeCommand: (_, _) async {
            throw StateError('command failed');
          },
        ),
        startRecording: (request) async => CockpitStartRecordingResult(
          recordingSession: CockpitRecordingSession(
            request: request.recording,
            state: CockpitRecordingState.recording,
          ),
        ),
        stopRecording: (_) async {
          stopAttempts += 1;
          return const CockpitStopRecordingResult(
            state: CockpitRecordingState.failed,
            failureReason: 'cleanup',
          );
        },
      );

      await expectLater(
        service.run(
          CockpitRunBatchRequest(
            app: _appHandle(),
            defaultResultProfile:
                const CockpitInteractiveResultProfile.minimal(),
            commands: <CockpitRunBatchCommand>[_batchCommand('tap-save')],
            recording: _recordingRequest(),
          ),
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'command failed',
          ),
        ),
      );

      expect(stopAttempts, 1);
    });

    test(
      'preserves stop failure and still retries best-effort cleanup',
      () async {
        var stopAttempts = 0;
        final service = CockpitRunBatchService(
          executeService: CockpitExecuteRemoteCommandBatchService(
            executeCommand: (_, command) async => CockpitCommandExecution(
              result: CockpitCommandResult(
                success: true,
                commandId: command.commandId,
                commandType: command.commandType,
                durationMs: 18,
              ),
            ),
          ),
          startRecording: (request) async => CockpitStartRecordingResult(
            recordingSession: CockpitRecordingSession(
              request: request.recording,
              state: CockpitRecordingState.recording,
            ),
          ),
          stopRecording: (_) async {
            stopAttempts += 1;
            throw StateError('stop failed');
          },
        );

        await expectLater(
          service.run(
            CockpitRunBatchRequest(
              app: _appHandle(),
              defaultResultProfile:
                  const CockpitInteractiveResultProfile.minimal(),
              commands: <CockpitRunBatchCommand>[_batchCommand('tap-save')],
              recording: _recordingRequest(),
            ),
          ),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              'stop failed',
            ),
          ),
        );

        expect(stopAttempts, 2);
      },
    );
  });
}

CockpitRunBatchCommand _batchCommand(String commandId) {
  return CockpitRunBatchCommand(
    command: CockpitCommand(
      commandId: commandId,
      commandType: CockpitCommandType.tap,
    ),
  );
}

CockpitRecordingRequest _recordingRequest() {
  return const CockpitRecordingRequest(
    purpose: CockpitRecordingPurpose.acceptance,
    name: 'batch-app-aware',
  );
}

CockpitAppHandle _appHandle({
  String baseUrl = 'http://127.0.0.1:47331',
  CockpitRemoteSessionHandle? remoteSession,
}) {
  return CockpitAppHandle(
    appId: 'dev.cockpit.demo',
    mode: CockpitAppMode.development,
    platform: 'macos',
    deviceId: 'macos',
    projectDir: '/workspace',
    target: 'lib/main.dart',
    baseUrl: baseUrl,
    launchedAt: DateTime.utc(2026, 5, 22),
    platformAppId: 'dev.cockpit.demo',
    remoteSession: remoteSession ?? _remoteSessionHandle(),
  );
}

CockpitRemoteSessionHandle _remoteSessionHandle({
  String baseUrl = 'http://127.0.0.1:47331',
}) {
  final uri = Uri.parse(baseUrl);
  return CockpitRemoteSessionHandle(
    appId: 'dev.cockpit.demo',
    platform: 'macos',
    deviceId: 'macos',
    projectDir: '/workspace',
    target: 'lib/main.dart',
    host: uri.host,
    hostPort: uri.port,
    devicePort: 47331,
    baseUrl: baseUrl,
    launchedAt: DateTime.utc(2026, 5, 22),
    platformAppId: 'dev.cockpit.demo',
  );
}

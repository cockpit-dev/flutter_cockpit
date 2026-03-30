import 'dart:convert';
import 'dart:io';

import 'package:file/memory.dart';
import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_latest_task_store.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_bundle_artifact_paths.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_list_launch_targets_service.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_read_runtime_errors_service.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_read_session_logs_service.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_read_task_bundle_summary_service.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_run_task_service.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_session_registry.dart';
import 'package:flutter_cockpit_devtools/src/development/cockpit_development_session_handle.dart';
import 'package:flutter_cockpit_devtools/src/development/cockpit_development_session_status.dart';
import 'package:flutter_cockpit_devtools/src/infrastructure/cockpit_file_system.dart';
import 'package:flutter_cockpit_devtools/src/infrastructure/cockpit_process_manager.dart';
import 'package:flutter_cockpit_devtools/src/infrastructure/cockpit_sdk_environment.dart';
import 'package:test/test.dart';

void main() {
  test('lists Flutter launch targets from machine output', () async {
    final service = CockpitListLaunchTargetsService(
      processManager: _MachineProcessManager(
        stdoutPayload: jsonEncode(<Map<String, Object?>>[
          <String, Object?>{
            'id': 'macos',
            'name': 'macOS',
            'platformType': 'darwin',
            'emulator': false,
            'ephemeral': false,
            'sdk': 'macos',
          },
        ]),
      ),
      sdkEnvironment: const CockpitSdkEnvironment(
        dartExecutable: 'dart-sdk',
        flutterExecutable: 'flutter-sdk',
      ),
    );

    final result = await service.list();

    expect(result.targets, hasLength(1));
    expect(result.targets.single.id, 'macos');
    expect(result.targets.single.platformType, 'darwin');
  });

  test('reads the tail of registered development session logs', () async {
    final fileSystem = MemoryFileSystem();
    fileSystem.file('/tmp/dev.log')
      ..createSync(recursive: true)
      ..writeAsStringSync('one\ntwo\nthree\n');
    final registry = CockpitSessionRegistry();
    registry.recordDevelopmentSession(
      handle: _developmentHandle(),
      status: _developmentStatus(lastError: 'boom'),
      supervisorLogPath: '/tmp/dev.log',
    );

    final result = await CockpitReadSessionLogsService(
      registry: registry,
      fileSystem: LocalCockpitFileSystem(fileSystem: fileSystem),
    ).read(
      const CockpitReadSessionLogsRequest(
        developmentSessionId: 'dev-session-1',
        maxLines: 2,
      ),
    );

    expect(result.logPath, '/tmp/dev.log');
    expect(result.lines, <String>['two', 'three']);
    expect(result.truncated, isTrue);
  });

  test('combines latest task and active session runtime errors', () {
    final registry = CockpitSessionRegistry();
    registry.recordDevelopmentSession(
      handle: _developmentHandle(),
      status: _developmentStatus(lastError: 'reload failed'),
      supervisorLogPath: '/tmp/dev.log',
    );
    final latestTaskStore = CockpitLatestTaskStore();
    latestTaskStore.recordRunTask(
      CockpitRunTaskResult(
        classification: CockpitRunTaskClassification.failedWithEvidence,
        recommendedNextStep: 'inspect_bundle',
        bundleSummary: _bundleSummaryWithRuntimeError(),
      ),
    );

    final result = CockpitReadRuntimeErrorsService(
      registry: registry,
      latestTaskStore: latestTaskStore,
    ).read(const CockpitReadRuntimeErrorsRequest());

    expect(result.hasErrors, isTrue);
    expect(
      result.errors.map((error) => error.source),
      containsAll(<String>['development_session', 'latest_task_bundle']),
    );
  });
}

final class _MachineProcessManager implements CockpitProcessManager {
  _MachineProcessManager({required this.stdoutPayload});

  final String stdoutPayload;

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool includeParentEnvironment = true,
    bool runInShell = false,
    Encoding? stdoutEncoding,
    Encoding? stderrEncoding,
  }) async {
    return ProcessResult(1, 0, stdoutPayload, '');
  }

  @override
  Future<Process> start(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool includeParentEnvironment = true,
    bool runInShell = false,
    ProcessStartMode mode = ProcessStartMode.normal,
  }) {
    throw UnimplementedError();
  }
}

CockpitDevelopmentSessionHandle _developmentHandle() =>
    CockpitDevelopmentSessionHandle(
      developmentSessionId: 'dev-session-1',
      platform: 'android',
      deviceId: 'emulator-5554',
      projectDir: '/workspace/app',
      target: 'lib/main.dart',
      appId: 'dev.example.app',
      appBaseUrl: 'http://127.0.0.1:57331',
      supervisorBaseUrl: 'http://127.0.0.1:59331',
      launchedAt: DateTime.utc(2026, 3, 30),
      reloadGeneration: 0,
    );

CockpitDevelopmentSessionStatus _developmentStatus({String? lastError}) =>
    CockpitDevelopmentSessionStatus(
      developmentSessionId: 'dev-session-1',
      state: CockpitDevelopmentSessionState.failed,
      appReachable: false,
      remoteSessionReachable: false,
      reloadGeneration: 0,
      lastError: lastError,
      lastStatusAt: DateTime.utc(2026, 3, 30),
    );

CockpitReadTaskBundleSummaryResult _bundleSummaryWithRuntimeError() =>
    CockpitReadTaskBundleSummaryResult(
      bundleDir: '/workspace/out/task',
      manifest: CockpitRunManifest(
        taskId: 'task-1',
        sessionId: 'session-1',
        platform: 'android',
        status: CockpitTaskStatus.failed,
        startedAt: DateTime.utc(2026, 3, 30),
        finishedAt: DateTime.utc(2026, 3, 30, 0, 1),
        commandCount: 0,
        screenshotCount: 0,
        deliveryArtifactsReady: false,
        recordingCount: 0,
        deliveryVideoReady: false,
      ),
      handoff: const <String, Object?>{},
      delivery: const <String, Object?>{},
      acceptanceMarkdown: '',
      artifactPaths: CockpitBundleArtifactPaths(),
      evidenceSummary: const <String, Object?>{},
      runtimeSummary: CockpitBundleRuntimeSummary(
        totalEntryCount: 1,
        errorCount: 1,
        warningCount: 0,
        truncated: false,
        errorEntries: <CockpitRuntimeEvent>[
          CockpitRuntimeEvent(
            eventId: 'runtime-1',
            kind: CockpitRuntimeEventKind.flutterError,
            severity: CockpitRuntimeEventSeverity.error,
            message: 'Unhandled exception',
            recordedAt: DateTime.utc(2026, 3, 30),
            routeName: '/checkout',
          ),
        ],
      ),
    );

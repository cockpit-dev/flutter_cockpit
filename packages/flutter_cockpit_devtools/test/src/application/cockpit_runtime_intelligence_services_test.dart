import 'dart:convert';
import 'dart:io';

import 'package:file/memory.dart';
import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_app_handle.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_app_reference_resolver.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_list_apps_service.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_latest_task_store.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_bundle_artifact_paths.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_list_launch_targets_service.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_read_logs_service.dart';
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
            'targetPlatform': 'darwin',
            'isSupported': true,
            'emulator': false,
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

  test('lists Flutter launch targets when process stdout is UTF-8 bytes',
      () async {
    final service = CockpitListLaunchTargetsService(
      processManager: _MachineProcessManager(
        stdoutPayload: jsonEncode(<Map<String, Object?>>[
          <String, Object?>{
            'id': 'macos',
            'name': 'macOS',
            'targetPlatform': 'darwin',
            'isSupported': true,
            'emulator': false,
            'sdk': 'macos',
          },
        ]),
        returnUtf8Bytes: true,
      ),
      sdkEnvironment: const CockpitSdkEnvironment(
        dartExecutable: 'dart-sdk',
        flutterExecutable: 'flutter-sdk',
      ),
    );

    final result = await service.list();

    expect(result.targets, hasLength(1));
    expect(result.targets.single.id, 'macos');
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

  test('lists active apps with normalized app ids and modes', () {
    final registry = CockpitSessionRegistry();
    registry.recordDevelopmentSession(
      handle: _developmentHandle(),
      status: _developmentStatus(),
      supervisorLogPath: '/tmp/dev.log',
    );

    final result = CockpitListAppsService(registry: registry).list();

    expect(result.apps, hasLength(1));
    expect(result.apps.single.appId, 'dev.example.app');
    expect(result.apps.single.mode.jsonValue, 'development');
  });

  test('reads app snapshot logs by app id', () async {
    final registry = CockpitSessionRegistry();
    registry.recordDevelopmentSession(
      handle: _developmentHandle(),
      status: _developmentStatus(lastError: 'boom'),
      supervisorLogPath: '/tmp/dev.log',
    );

    final result = await CockpitReadLogsService(
      registry: registry,
      readSnapshot: (baseUri, options) async {
        expect(baseUri.toString(), 'http://127.0.0.1:57331');
        expect(options.includeRuntimeActivity, isTrue);
        expect(options.maxRuntimeEntries, 2);
        return CockpitRemoteSnapshotResponse(
          snapshot: CockpitSnapshot(
            routeName: '/inbox',
            runtime: CockpitRuntimeSnapshot(
              totalEntryCount: 2,
              errorCount: 0,
              warningCount: 0,
              entries: <CockpitRuntimeEvent>[
                CockpitRuntimeEvent(
                  eventId: 'runtime-1',
                  kind: CockpitRuntimeEventKind.debugLog,
                  severity: CockpitRuntimeEventSeverity.info,
                  message: 'rendered inbox',
                  recordedAt: DateTime.utc(2026, 3, 30, 10, 0),
                  routeName: '/inbox',
                  source: 'debugPrint',
                ),
                CockpitRuntimeEvent(
                  eventId: 'runtime-2',
                  kind: CockpitRuntimeEventKind.debugLog,
                  severity: CockpitRuntimeEventSeverity.info,
                  message: 'refreshed counters',
                  recordedAt: DateTime.utc(2026, 3, 30, 10, 1),
                  routeName: '/inbox',
                  source: 'print',
                ),
              ],
              capturedEntryCount: 2,
            ),
          ),
        );
      },
    ).read(
      const CockpitReadLogsRequest(appId: 'dev.example.app', maxLines: 2),
    );

    expect(result.appId, 'dev.example.app');
    expect(result.source, 'app_snapshot');
    expect(result.available, isTrue);
    expect(result.routeName, '/inbox');
    expect(
      result.lines,
      <String>[
        'info debug_log debugPrint: rendered inbox',
        'info debug_log print: refreshed counters',
      ],
    );
  });

  test('returns structured missing log state when the log file is absent',
      () async {
    final registry = CockpitSessionRegistry();
    registry.recordDevelopmentSession(
      handle: _developmentHandle(),
      status: _developmentStatus(),
      supervisorLogPath: '/tmp/missing.log',
    );

    final result = await CockpitReadLogsService(
      registry: registry,
      fileSystem: LocalCockpitFileSystem(fileSystem: MemoryFileSystem()),
      readSnapshot: (_, __) => throw StateError('app unavailable'),
    ).read(
      const CockpitReadLogsRequest(appId: 'dev.example.app', maxLines: 2),
    );

    expect(result.available, isFalse);
    expect(result.missingReason, 'log_file_missing');
    expect(result.lines, isEmpty);
  });

  test('resolves a lean app handle back to the registry session record',
      () async {
    final registry = CockpitSessionRegistry();
    registry.recordDevelopmentSession(
      handle: _developmentHandle(),
      status: _developmentStatus(lastError: 'boom'),
      supervisorLogPath: '/tmp/dev.log',
    );

    final tempDir = await Directory.systemTemp.createTemp(
      'cockpit_app_handle_resolver',
    );
    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    final appFile = File('${tempDir.path}/app.json');
    await appFile.writeAsString(
      jsonEncode(
        CockpitAppHandle(
          appId: 'dev.example.app',
          mode: CockpitAppMode.development,
          platform: 'android',
          deviceId: 'emulator-5554',
          projectDir: '/workspace/app',
          target: 'lib/main.dart',
          baseUrl: 'http://127.0.0.1:57331',
          launchedAt: DateTime.utc(2026, 3, 30),
          supervisorLogPath: '/tmp/dev.log',
        ).toJson(),
      ),
    );

    final resolved = await CockpitAppReferenceResolver(
      registry: registry,
    ).resolve(appHandlePath: appFile.path);

    expect(resolved.app?.developmentSession, isNull);
    expect(
      resolved.developmentRecord?.handle.developmentSessionId,
      'dev-session-1',
    );
  });

  test('reconstructs development control fields from a compact app handle',
      () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'cockpit_compact_development_handle',
    );
    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    final appFile = File('${tempDir.path}/app.json');
    await appFile.writeAsString(
      jsonEncode(
        CockpitAppHandle.fromDevelopmentSession(
          _developmentHandle(),
          supervisorLogPath: '/tmp/dev.log',
        ).toJson(),
      ),
    );

    final resolved = await CockpitAppReferenceResolver().resolve(
      appHandlePath: appFile.path,
    );

    expect(
      resolved.app?.developmentSession?.developmentSessionId,
      'dev-session-1',
    );
    expect(
      resolved.app?.developmentSession?.supervisorBaseUri.toString(),
      'http://127.0.0.1:59331',
    );
  });

  test('accepts a launch-app result wrapper anywhere an app handle is expected',
      () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'cockpit_wrapped_app_handle',
    );
    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    final appFile = File('${tempDir.path}/app.json');
    await appFile.writeAsString(
      jsonEncode(
        <String, Object?>{
          'app': CockpitAppHandle.fromDevelopmentSession(
            _developmentHandle(),
            supervisorLogPath: '/tmp/dev.log',
          ).toJson(),
          'app_json_path': null,
          'supervisor_log_path': '/tmp/dev.log',
        },
      ),
    );

    final resolved = await CockpitAppReferenceResolver().resolve(
      appHandlePath: appFile.path,
    );

    expect(resolved.app?.appId, 'dev.example.app');
    expect(
      resolved.app?.developmentSession?.developmentSessionId,
      'dev-session-1',
    );
  });

  test('reads current app runtime errors from an app handle', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'cockpit_runtime_errors_app_handle',
    );
    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    final appFile = File('${tempDir.path}/app.json');
    await appFile.writeAsString(
      jsonEncode(
        CockpitAppHandle(
          appId: 'dev.example.app',
          mode: CockpitAppMode.development,
          platform: 'macos',
          deviceId: 'macos',
          projectDir: '/workspace/app',
          target: 'cockpit/main.dart',
          baseUrl: 'http://127.0.0.1:57331',
          launchedAt: DateTime.utc(2026, 3, 30),
        ).toJson(),
      ),
    );

    final result = await CockpitReadRuntimeErrorsService(
      registry: CockpitSessionRegistry(),
      latestTaskStore: CockpitLatestTaskStore(),
      readSnapshot: (baseUri, options) async {
        expect(baseUri.toString(), 'http://127.0.0.1:57331');
        expect(options.includeRuntimeActivity, isTrue);
        expect(options.runtimeQuery.onlyErrors, isTrue);
        expect(options.maxRuntimeEntries, 4);
        return CockpitRemoteSnapshotResponse(
          snapshot: CockpitSnapshot(
            routeName: '/inbox',
            diagnosticLevel: CockpitSnapshotProfile.investigate,
            runtime: CockpitRuntimeSnapshot(
              totalEntryCount: 1,
              errorCount: 1,
              warningCount: 0,
              entries: <CockpitRuntimeEvent>[
                CockpitRuntimeEvent(
                  eventId: 'runtime-1',
                  kind: CockpitRuntimeEventKind.flutterError,
                  severity: CockpitRuntimeEventSeverity.error,
                  message: 'setState called after dispose',
                  recordedAt: DateTime.utc(2026, 3, 30, 10, 0),
                  routeName: '/inbox',
                ),
              ],
              capturedEntryCount: 1,
              query: const CockpitRuntimeQuery(onlyErrors: true),
            ),
          ),
        );
      },
    ).read(
      CockpitReadRuntimeErrorsRequest(
        appHandlePath: appFile.path,
        maxErrors: 4,
      ),
    );

    expect(result.appId, 'dev.example.app');
    expect(result.routeName, '/inbox');
    expect(result.source, 'app_snapshot');
    expect(result.hasErrors, isTrue);
    expect(result.errors.single.message, 'setState called after dispose');
    expect(result.errors.single.kind, 'flutterError');
  });

  test('combines latest task and active session runtime errors', () async {
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

    final result = await CockpitReadRuntimeErrorsService(
      registry: registry,
      latestTaskStore: latestTaskStore,
    ).read(const CockpitReadRuntimeErrorsRequest());

    expect(result.hasErrors, isTrue);
    expect(result.source, 'aggregate');
    expect(
      result.errors.map((error) => error.source),
      containsAll(<String>['development_session', 'latest_task_bundle']),
    );
  });
}

final class _MachineProcessManager implements CockpitProcessManager {
  _MachineProcessManager({
    required this.stdoutPayload,
    this.returnUtf8Bytes = false,
  });

  final String stdoutPayload;
  final bool returnUtf8Bytes;

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
    return ProcessResult(
      1,
      0,
      returnUtf8Bytes ? utf8.encode(stdoutPayload) : stdoutPayload,
      '',
    );
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

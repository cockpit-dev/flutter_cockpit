import 'dart:convert';
import 'dart:io';

import 'package:cockpit_protocol/cockpit_protocol.dart';
import 'package:cockpit/src/application/cockpit_app_handle.dart';
import 'package:cockpit/src/application/cockpit_app_reference_resolver.dart';
import 'package:cockpit/src/application/cockpit_application_service_exception.dart';
import 'package:cockpit/src/application/cockpit_bundle_artifact_paths.dart';
import 'package:cockpit/src/application/cockpit_run_remote_control_script_service.dart';
import 'package:cockpit/src/mcp/cockpit_mcp_error.dart';
import 'package:cockpit/src/mcp/tools/cockpit_run_remote_control_script_tool.dart';
import 'package:cockpit/src/remote/cockpit_android_port_forwarder.dart';
import 'package:cockpit/src/session/cockpit_remote_session_handle.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test(
    'run tool maps a structured script into the run service and returns bundle metadata',
    () async {
      CockpitRunRemoteControlScriptRequest? capturedRequest;
      final bundleDir = Directory.systemTemp.createTempSync(
        'cockpit_run_remote_control_script_tool',
      );
      addTearDown(() async {
        if (bundleDir.existsSync()) {
          await bundleDir.delete(recursive: true);
        }
      });

      final tool = CockpitRunRemoteControlScriptTool(
        run: (request) async {
          capturedRequest = request;
          return CockpitRunRemoteControlScriptResult(
            sessionHandle: null,
            bundleDir: bundleDir,
            manifest: CockpitRunManifest(
              sessionId: 'run-tool-session',
              taskId: 'run-tool-task',
              platform: 'android',
              status: CockpitTaskStatus.completed,
              startedAt: DateTime.utc(2026, 3, 21, 0, 0),
              finishedAt: DateTime.utc(2026, 3, 21, 0, 5),
              commandCount: 2,
              screenshotCount: 1,
              recordingCount: 1,
              deliveryArtifactsReady: true,
              deliveryVideoReady: true,
            ),
            handoff: const <String, Object?>{'status': 'completed'},
            delivery: const <String, Object?>{
              'primaryScreenshotRef': 'screenshots/acceptance.png',
              'primaryRecordingRef': 'recordings/acceptance.mp4',
            },
            artifactPaths: CockpitBundleArtifactPaths(
              primaryScreenshotPath: p.join(
                bundleDir.path,
                'screenshots',
                'acceptance.png',
              ),
              primaryRecordingPath: p.join(
                bundleDir.path,
                'recordings',
                'acceptance.mp4',
              ),
            ),
          );
        },
      );

      final result = await tool.call(<String, Object?>{
        'baseUrl': 'http://127.0.0.1:58421',
        'outputRoot': '/tmp/out',
        'persistScriptPath': '/tmp/replay_script.json',
        'script': <String, Object?>{
          'sessionId': 'run-tool-session',
          'taskId': 'run-tool-task',
          'platform': 'android',
          'commands': <Map<String, Object?>>[
            CockpitCommand(
              commandId: 'tap-open',
              commandType: CockpitCommandType.tap,
              locator: const CockpitLocator(cockpitId: 'open_form_button'),
            ).toJson(),
          ],
          'failFast': true,
        },
      });

      expect(capturedRequest?.outputRoot, '/tmp/out');
      expect(capturedRequest?.baseUri?.toString(), 'http://127.0.0.1:58421');
      expect(capturedRequest?.androidDeviceId, isNull);
      expect(capturedRequest?.portForwardingHandled, isTrue);
      expect(capturedRequest?.script.sessionId, 'run-tool-session');
      expect(capturedRequest?.script.environment, isNull);

      final structuredContent =
          result['structuredContent'] as Map<String, Object?>;
      expect(structuredContent['bundleDir'], bundleDir.path);
      expect(
        (structuredContent['artifactPaths']
            as Map<String, Object?>)['primaryRecordingPath'],
        p.join(bundleDir.path, 'recordings', 'acceptance.mp4'),
      );
    },
  );

  test('run tool can override reusable script platform', () async {
    CockpitRunRemoteControlScriptRequest? capturedRequest;
    final bundleDir = Directory.systemTemp.createTempSync(
      'cockpit_run_remote_control_script_tool_platform_override',
    );
    addTearDown(() async {
      if (bundleDir.existsSync()) {
        await bundleDir.delete(recursive: true);
      }
    });

    final tool = CockpitRunRemoteControlScriptTool(
      run: (request) async {
        capturedRequest = request;
        return CockpitRunRemoteControlScriptResult(
          sessionHandle: null,
          bundleDir: bundleDir,
          manifest: CockpitRunManifest(
            sessionId: request.script.sessionId,
            taskId: request.script.taskId,
            platform: request.script.platform,
            status: CockpitTaskStatus.completed,
            startedAt: DateTime.utc(2026, 6, 18),
            finishedAt: DateTime.utc(2026, 6, 18, 0, 0, 1),
          ),
          handoff: const <String, Object?>{},
          delivery: const <String, Object?>{},
          artifactPaths: CockpitBundleArtifactPaths(),
        );
      },
    );

    await tool.call(<String, Object?>{
      'baseUrl': 'http://127.0.0.1:58421',
      'outputRoot': '/tmp/out',
      'platform': 'web',
      'script': <String, Object?>{
        'sessionId': 'run-tool-session',
        'taskId': 'run-tool-task',
        'platform': 'macos',
        'environment': const CockpitEnvironment(
          platform: 'macos',
          flutterVersion: '3.32.0',
          dartVersion: '3.8.0',
        ).toJson(),
        'commands': <Map<String, Object?>>[_noopCommandJson()],
      },
    });

    expect(capturedRequest?.script.platform, 'web');
    expect(capturedRequest?.script.environment?.platform, 'web');
  });

  test(
    'run tool rejects invalid platform overrides before execution',
    () async {
      var called = false;
      final tool = CockpitRunRemoteControlScriptTool(
        run: (_) async {
          called = true;
          throw StateError('run should not be reached');
        },
      );

      expect(
        () => tool.call(<String, Object?>{
          'baseUrl': 'http://127.0.0.1:58421',
          'outputRoot': '/tmp/out',
          'platform': 'freebsd',
          'script': <String, Object?>{
            'sessionId': 'run-tool-session',
            'taskId': 'run-tool-task',
            'platform': 'macos',
            'commands': <Map<String, Object?>>[_noopCommandJson()],
          },
        }),
        throwsA(
          isA<CockpitMcpError>().having(
            (error) => error.data['argument'],
            'argument',
            'platform',
          ),
        ),
      );
      expect(called, isFalse);
    },
  );

  test('run tool maps service errors into MCP errors', () async {
    final tool = CockpitRunRemoteControlScriptTool(
      run: (_) async => throw const CockpitApplicationServiceException(
        code: 'bundleWriteFailed',
        message: 'Bundle could not be written.',
      ),
    );

    expect(
      () => tool.call(<String, Object?>{
        'baseUrl': 'http://127.0.0.1:58421',
        'outputRoot': '/tmp/out',
        'script': <String, Object?>{
          'sessionId': 'run-tool-session',
          'taskId': 'run-tool-task',
          'platform': 'android',
          'environment': const CockpitEnvironment(
            platform: 'android',
            flutterVersion: '3.38.9',
            dartVersion: '3.10.8',
          ).toJson(),
          'commands': <Map<String, Object?>>[_noopCommandJson()],
          'failFast': true,
        },
      }),
      throwsA(
        isA<CockpitMcpError>().having(
          (error) => error.data['serviceCode'],
          'serviceCode',
          'bundleWriteFailed',
        ),
      ),
    );
  });

  test('run tool forwards process ids from app handles', () async {
    CockpitRunRemoteControlScriptRequest? capturedRequest;
    final tempDir = await Directory.systemTemp.createTemp(
      'cockpit_run_remote_control_script_tool_process_id',
    );
    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    final appHandleFile = File(p.join(tempDir.path, 'app.json'));
    await appHandleFile.writeAsString(
      jsonEncode(
        CockpitAppHandle(
          appId: 'windows-app',
          mode: CockpitAppMode.automation,
          platform: 'windows',
          deviceId: 'windows',
          projectDir: '/workspace/examples/cockpit_demo',
          target: 'cockpit/main.dart',
          baseUrl: 'http://127.0.0.1:57331',
          launchedAt: DateTime.utc(2026, 4, 17),
          platformAppId: 'cockpit_demo',
          processId: 4101,
        ).toJson(),
      ),
    );

    final tool = CockpitRunRemoteControlScriptTool(
      appReferenceResolver: CockpitAppReferenceResolver(
        portForwarder: CockpitAndroidPortForwarder(
          processRunner: (_, _) async =>
              ProcessResult(0, 0, 'emulator-5554 tcp:61331 tcp:47331\n', ''),
          hostPortAllocator: () async => 61331,
          hostPortAvailabilityChecker: (_) async => false,
        ),
      ),
      run: (request) async {
        capturedRequest = request;
        return CockpitRunRemoteControlScriptResult(
          sessionHandle: null,
          bundleDir: tempDir,
          manifest: CockpitRunManifest(
            sessionId: 'run-tool-session',
            taskId: 'run-tool-task',
            platform: 'windows',
            status: CockpitTaskStatus.completed,
            startedAt: DateTime.utc(2026, 4, 17, 0, 0),
            finishedAt: DateTime.utc(2026, 4, 17, 0, 5),
          ),
          handoff: const <String, Object?>{},
          delivery: const <String, Object?>{},
          artifactPaths: CockpitBundleArtifactPaths(),
        );
      },
    );

    await tool.call(<String, Object?>{
      'appJson': appHandleFile.path,
      'outputRoot': '/tmp/out',
      'script': <String, Object?>{
        'sessionId': 'run-tool-session',
        'taskId': 'run-tool-task',
        'platform': 'windows',
        'environment': const CockpitEnvironment(
          platform: 'windows',
          flutterVersion: '3.38.9',
          dartVersion: '3.10.8',
        ).toJson(),
        'commands': <Map<String, Object?>>[_noopCommandJson()],
      },
    });

    expect(capturedRequest?.platformAppId, 'cockpit_demo');
    expect(capturedRequest?.processId, 4101);
  });

  test(
    'run tool preserves app session metadata for host evidence adapters',
    () async {
      CockpitRunRemoteControlScriptRequest? capturedRequest;
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_run_remote_control_script_tool_session_metadata',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final appHandleFile = File(p.join(tempDir.path, 'app.json'));
      await appHandleFile.writeAsString(
        jsonEncode(
          CockpitAppHandle(
            appId: 'android-app',
            mode: CockpitAppMode.automation,
            platform: 'android',
            deviceId: 'emulator-5554',
            projectDir: '/workspace/app',
            target: 'cockpit/main.dart',
            baseUrl: 'http://127.0.0.1:57331',
            launchedAt: DateTime.utc(2026, 5, 22),
            platformAppId: 'dev.example.android',
            processId: 4301,
            remoteSession: CockpitRemoteSessionHandle(
              platform: 'android',
              deviceId: 'emulator-5554',
              projectDir: '/workspace/app',
              target: 'cockpit/main.dart',
              appId: 'android-app',
              platformAppId: 'dev.example.android',
              processId: 4301,
              host: '127.0.0.1',
              hostPort: 57331,
              devicePort: 47331,
              baseUrl: 'http://127.0.0.1:57331',
              launchedAt: DateTime.utc(2026, 5, 22),
            ),
          ).toJson(),
        ),
      );

      final tool = CockpitRunRemoteControlScriptTool(
        appReferenceResolver: CockpitAppReferenceResolver(
          portForwarder: CockpitAndroidPortForwarder(
            processRunner: (_, _) async =>
                ProcessResult(0, 0, 'emulator-5554 tcp:61331 tcp:47331\n', ''),
            hostPortAllocator: () async => 61331,
            hostPortAvailabilityChecker: (_) async => false,
          ),
        ),
        run: (request) async {
          capturedRequest = request;
          return CockpitRunRemoteControlScriptResult(
            sessionHandle: request.sessionHandle,
            bundleDir: tempDir,
            manifest: CockpitRunManifest(
              sessionId: 'run-tool-session',
              taskId: 'run-tool-task',
              platform: 'android',
              status: CockpitTaskStatus.completed,
              startedAt: DateTime.utc(2026, 5, 22, 0, 0),
              finishedAt: DateTime.utc(2026, 5, 22, 0, 5),
            ),
            handoff: const <String, Object?>{},
            delivery: const <String, Object?>{},
            artifactPaths: CockpitBundleArtifactPaths(),
          );
        },
      );

      await tool.call(<String, Object?>{
        'appJson': appHandleFile.path,
        'outputRoot': '/tmp/out',
        'script': <String, Object?>{
          'sessionId': 'run-tool-session',
          'taskId': 'run-tool-task',
          'platform': 'android',
          'environment': const CockpitEnvironment(
            platform: 'android',
            flutterVersion: '3.38.9',
            dartVersion: '3.10.8',
          ).toJson(),
          'commands': <Map<String, Object?>>[_noopCommandJson()],
        },
      });

      expect(capturedRequest?.baseUri?.toString(), 'http://127.0.0.1:61331');
      expect(capturedRequest?.sessionHandle?.devicePort, 47331);
      expect(capturedRequest?.sessionHandle?.baseUrl, 'http://127.0.0.1:61331');
      expect(
        capturedRequest?.sessionHandle?.effectivePlatformAppId,
        'dev.example.android',
      );
      expect(capturedRequest?.androidDeviceId, 'emulator-5554');
      expect(capturedRequest?.platformAppId, 'dev.example.android');
      expect(capturedRequest?.processId, 4301);
      expect(capturedRequest?.portForwardingHandled, isTrue);
    },
  );

  test('run tool treats failed bundle manifests as MCP errors', () async {
    final bundleDir = Directory.systemTemp.createTempSync(
      'cockpit_run_remote_control_script_tool_failed',
    );
    addTearDown(() async {
      if (bundleDir.existsSync()) {
        await bundleDir.delete(recursive: true);
      }
    });

    final tool = CockpitRunRemoteControlScriptTool(
      run: (_) async => CockpitRunRemoteControlScriptResult(
        sessionHandle: null,
        bundleDir: bundleDir,
        manifest: CockpitRunManifest(
          sessionId: 'run-tool-session',
          taskId: 'run-tool-task',
          platform: 'android',
          status: CockpitTaskStatus.failed,
          startedAt: DateTime.utc(2026, 3, 21, 0, 0),
          finishedAt: DateTime.utc(2026, 3, 21, 0, 5),
          failureSummary: 'Expected text was not visible.',
        ),
        handoff: const <String, Object?>{},
        delivery: const <String, Object?>{},
        artifactPaths: CockpitBundleArtifactPaths(),
      ),
    );

    expect(
      () => tool.call(<String, Object?>{
        'baseUrl': 'http://127.0.0.1:58421',
        'outputRoot': '/tmp/out',
        'script': <String, Object?>{
          'sessionId': 'run-tool-session',
          'taskId': 'run-tool-task',
          'platform': 'android',
          'environment': const CockpitEnvironment(
            platform: 'android',
            flutterVersion: '3.38.9',
            dartVersion: '3.10.8',
          ).toJson(),
          'commands': <Map<String, Object?>>[_noopCommandJson()],
          'failFast': true,
        },
      }),
      throwsA(
        isA<CockpitMcpError>()
            .having((error) => error.code, 'code', -32000)
            .having(
              (error) => error.data['failureSummary'],
              'failureSummary',
              'Expected text was not visible.',
            ),
      ),
    );
  });

  test('run tool accepts workflow steps in MCP script objects', () async {
    CockpitRunRemoteControlScriptRequest? capturedRequest;
    final bundleDir = Directory.systemTemp.createTempSync(
      'cockpit_run_remote_control_script_tool_workflow',
    );
    addTearDown(() async {
      if (bundleDir.existsSync()) {
        await bundleDir.delete(recursive: true);
      }
    });

    final tool = CockpitRunRemoteControlScriptTool(
      run: (request) async {
        capturedRequest = request;
        return CockpitRunRemoteControlScriptResult(
          sessionHandle: null,
          bundleDir: bundleDir,
          manifest: CockpitRunManifest(
            sessionId: 'run-tool-workflow-session',
            taskId: 'run-tool-workflow-task',
            platform: 'android',
            status: CockpitTaskStatus.completed,
            startedAt: DateTime.utc(2026, 6, 15),
            finishedAt: DateTime.utc(2026, 6, 15, 0, 1),
          ),
          handoff: const <String, Object?>{},
          delivery: const <String, Object?>{},
          artifactPaths: CockpitBundleArtifactPaths(),
        );
      },
    );

    await tool.call(<String, Object?>{
      'baseUrl': 'http://127.0.0.1:58421',
      'outputRoot': '/tmp/out',
      'script': <String, Object?>{
        'sessionId': 'run-tool-workflow-session',
        'taskId': 'run-tool-workflow-task',
        'platform': 'android',
        'steps': <Object?>[
          <String, Object?>{
            'stepId': 'wait-ready',
            'stepType': 'retry',
            'maxAttempts': 2,
            'delayMs': 0,
            'step': <String, Object?>{
              'stepType': 'command',
              'command': <String, Object?>{
                'commandId': 'assert-ready',
                'commandType': 'assertText',
                'parameters': <String, Object?>{'text': 'Ready'},
              },
            },
          },
        ],
      },
    });

    expect(capturedRequest?.script.commands, isEmpty);
    expect(capturedRequest?.script.workflowSteps, hasLength(1));
    expect(capturedRequest?.script.effectiveWorkflowSteps, hasLength(1));
  });
}

Map<String, Object?> _noopCommandJson() {
  return CockpitCommand(
    commandId: 'assert-noop',
    commandType: CockpitCommandType.assertText,
    parameters: const <String, Object?>{'text': 'Ready'},
  ).toJson();
}

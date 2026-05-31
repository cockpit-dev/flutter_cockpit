import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_execute_remote_command_batch_service.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_inspect_ui_service.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_interactive_result_data.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_read_app_service.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_run_batch_service.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_run_command_service.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_start_recording_service.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_stop_recording_service.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_wait_idle_service.dart';
import 'package:flutter_cockpit_devtools/src/mcp/cockpit_mcp_error.dart';
import 'package:flutter_cockpit_devtools/src/mcp/cockpit_mcp_tool.dart';
import 'package:flutter_cockpit_devtools/src/mcp/tools/cockpit_capture_screenshot_tool.dart';
import 'package:flutter_cockpit_devtools/src/mcp/tools/cockpit_inspect_ui_tool.dart';
import 'package:flutter_cockpit_devtools/src/mcp/tools/cockpit_read_app_tool.dart';
import 'package:flutter_cockpit_devtools/src/mcp/tools/cockpit_run_batch_tool.dart';
import 'package:flutter_cockpit_devtools/src/mcp/tools/cockpit_run_command_tool.dart';
import 'package:flutter_cockpit_devtools/src/mcp/tools/cockpit_start_recording_tool.dart';
import 'package:flutter_cockpit_devtools/src/mcp/tools/cockpit_stop_recording_tool.dart';
import 'package:flutter_cockpit_devtools/src/mcp/tools/cockpit_wait_idle_tool.dart';
import 'package:test/test.dart';

void main() {
  test(
    'MCP integer arguments reject fractional numbers instead of truncating',
    () {
      expect(
        () => cockpitReadOptionalInt(const <String, Object?>{
          'timeoutMs': 1.5,
        }, 'timeoutMs'),
        throwsA(
          isA<CockpitMcpError>()
              .having((error) => error.code, 'code', -32602)
              .having(
                (error) => error.data['argument'],
                'argument',
                'timeoutMs',
              ),
        ),
      );
    },
  );

  test('MCP positive integer arguments reject zero and negative values', () {
    expect(
      () => cockpitReadOptionalPositiveInt(const <String, Object?>{
        'timeoutMs': 0,
      }, 'timeoutMs'),
      throwsA(
        isA<CockpitMcpError>()
            .having((error) => error.code, 'code', -32602)
            .having((error) => error.data['argument'], 'argument', 'timeoutMs'),
      ),
    );

    expect(
      () => cockpitReadOptionalPositiveInt(const <String, Object?>{
        'maxLines': -1,
      }, 'maxLines'),
      throwsA(isA<CockpitMcpError>()),
    );
  });

  test('MCP HTTP status arguments reject values outside the HTTP range', () {
    expect(
      () => cockpitReadOptionalHttpStatusCode(const <String, Object?>{
        'statusCodeAtLeast': 99,
      }, 'statusCodeAtLeast'),
      throwsA(isA<CockpitMcpError>()),
    );

    expect(
      () => cockpitReadOptionalHttpStatusCode(const <String, Object?>{
        'statusCodeAtLeast': 600,
      }, 'statusCodeAtLeast'),
      throwsA(isA<CockpitMcpError>()),
    );
  });

  test('MCP port arguments reject values outside the TCP range', () {
    expect(
      () => cockpitReadRequiredPort(const <String, Object?>{
        'sessionPort': 0,
      }, 'sessionPort'),
      throwsA(isA<CockpitMcpError>()),
    );

    expect(
      () => cockpitReadRequiredPort(const <String, Object?>{
        'sessionPort': 65536,
      }, 'sessionPort'),
      throwsA(isA<CockpitMcpError>()),
    );
  });

  test('app-first MCP tools pass androidDeviceId through', () async {
    final seen = <String>[];

    await CockpitReadAppTool(
      read: (request) async {
        expect(request.androidDeviceId, 'emulator-5554');
        seen.add('read_app');
        return _readAppResult();
      },
    ).call(_baseArguments());

    await CockpitRunCommandTool(
      runCommand: (request) async {
        expect(request.androidDeviceId, 'emulator-5554');
        seen.add('run_command');
        return _commandResult();
      },
    ).call(<String, Object?>{
      ..._baseArguments(),
      'command': <String, Object?>{'commandId': 'tap-1', 'commandType': 'tap'},
    });

    await CockpitCaptureScreenshotTool(
      capture: (request) async {
        expect(request.androidDeviceId, 'emulator-5554');
        expect(request.name, 'acceptance');
        expect(request.reason, CockpitScreenshotReason.acceptance);
        seen.add('capture_screenshot');
        return _commandResult();
      },
    ).call(<String, Object?>{..._baseArguments(), 'name': 'acceptance'});

    await CockpitRunBatchTool(
      runBatch: (request) async {
        expect(request.androidDeviceId, 'emulator-5554');
        seen.add('run_batch');
        return const CockpitRunBatchResult(
          results: <CockpitRunCommandResult>[],
          summary: CockpitExecuteRemoteCommandBatchSummary(
            totalCount: 0,
            successCount: 0,
            failureCount: 0,
            stoppedEarly: false,
          ),
        );
      },
    ).call(<String, Object?>{
      ..._baseArguments(),
      'commands': <Object?>[
        <String, Object?>{
          'commandId': 'wait-1',
          'commandType': 'waitForUiIdle',
        },
      ],
    });

    await CockpitInspectUiTool(
      inspect: (request) async {
        expect(request.androidDeviceId, 'emulator-5554');
        seen.add('inspect_ui');
        return const CockpitInspectUiResult(
          routeName: '/home',
          diagnosticLevel: 'inspect',
          truncated: false,
        );
      },
    ).call(_baseArguments());

    await CockpitWaitIdleTool(
      wait: (request) async {
        expect(request.androidDeviceId, 'emulator-5554');
        seen.add('wait_idle');
        return const CockpitWaitIdleResult(
          idle: true,
          durationMs: 1,
          quietWindowMs: 96,
          timeoutMs: 1600,
          includeNetworkIdle: true,
        );
      },
    ).call(_baseArguments());

    await CockpitStartRecordingTool(
      start: (request) async {
        expect(request.androidDeviceId, 'emulator-5554');
        seen.add('start_recording');
        return CockpitStartRecordingResult(
          recordingSession: CockpitRecordingSession(
            request: request.recording,
            state: CockpitRecordingState.recording,
          ),
        );
      },
    ).call(_baseArguments());

    await CockpitStopRecordingTool(
      stop: (request) async {
        expect(request.androidDeviceId, 'emulator-5554');
        seen.add('stop_recording');
        return const CockpitStopRecordingResult(
          state: CockpitRecordingState.completed,
        );
      },
    ).call(_baseArguments());

    expect(seen, <String>[
      'read_app',
      'run_command',
      'capture_screenshot',
      'run_batch',
      'inspect_ui',
      'wait_idle',
      'start_recording',
      'stop_recording',
    ]);
  });

  test('recording MCP tools pass iosDeviceId through', () async {
    final seen = <String>[];

    await CockpitStartRecordingTool(
      start: (request) async {
        expect(request.iosDeviceId, '6FD25DED-11E9-4AE9-B4B5-EDF4601981DC');
        seen.add('start_recording');
        return CockpitStartRecordingResult(
          recordingSession: CockpitRecordingSession(
            request: request.recording,
            state: CockpitRecordingState.recording,
          ),
        );
      },
    ).call(<String, Object?>{
      ..._iosArguments(),
      'recording': <String, Object?>{
        'purpose': 'acceptance',
        'name': 'ios-flow',
      },
    });

    await CockpitRunBatchTool(
      runBatch: (request) async {
        expect(request.iosDeviceId, '6FD25DED-11E9-4AE9-B4B5-EDF4601981DC');
        seen.add('run_batch');
        return const CockpitRunBatchResult(
          results: <CockpitRunCommandResult>[],
          summary: CockpitExecuteRemoteCommandBatchSummary(
            totalCount: 0,
            successCount: 0,
            failureCount: 0,
            stoppedEarly: false,
          ),
        );
      },
    ).call(<String, Object?>{
      ..._iosArguments(),
      'commands': <Object?>[
        <String, Object?>{
          'commandId': 'wait-1',
          'commandType': 'waitForUiIdle',
        },
      ],
      'recording': <String, Object?>{
        'purpose': 'acceptance',
        'name': 'ios-batch',
      },
    });

    await CockpitStopRecordingTool(
      stop: (request) async {
        expect(request.iosDeviceId, '6FD25DED-11E9-4AE9-B4B5-EDF4601981DC');
        seen.add('stop_recording');
        return const CockpitStopRecordingResult(
          state: CockpitRecordingState.completed,
        );
      },
    ).call(_iosArguments());

    expect(seen, <String>['start_recording', 'run_batch', 'stop_recording']);
  });
}

Map<String, Object?> _baseArguments() => <String, Object?>{
  'appJson': '/tmp/app.json',
  'baseUrl': 'http://127.0.0.1:47331',
  'androidDeviceId': 'emulator-5554',
};

Map<String, Object?> _iosArguments() => <String, Object?>{
  'appJson': '/tmp/ios_app.json',
  'baseUrl': 'http://127.0.0.1:47331',
  'iosDeviceId': '6FD25DED-11E9-4AE9-B4B5-EDF4601981DC',
};

CockpitReadAppResult _readAppResult() => CockpitReadAppResult(
  sessionId: 'session-1',
  transportType: 'remoteHttp',
  capabilities: CockpitCapabilities(
    platform: 'android',
    transportType: 'remoteHttp',
    supportsInAppControl: true,
    supportsFlutterViewCapture: true,
    supportsNativeScreenCapture: true,
    supportsHostAutomation: false,
    supportedCommands: const <CockpitCommandType>[CockpitCommandType.tap],
    supportedLocatorStrategies: CockpitLocatorKind.values,
  ),
  recordingCapabilities: CockpitRecordingCapabilities(
    supportsNativeRecording: true,
    preferredAcceptanceRecordingKind: CockpitRecordingKind.nativeScreen,
  ),
);

CockpitRunCommandResult _commandResult() => CockpitRunCommandResult(
  command: const CockpitInteractiveCommandCore(
    commandId: 'tap-1',
    commandType: 'tap',
    success: true,
    durationMs: 1,
    usedCaptureFallback: false,
  ),
  artifacts: const <CockpitInteractiveArtifactDescriptor>[],
);

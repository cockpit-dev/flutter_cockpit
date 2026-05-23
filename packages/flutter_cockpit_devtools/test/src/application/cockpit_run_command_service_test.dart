import 'dart:io';

import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_app_handle.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_app_reference_resolver.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_execute_remote_command_service.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_interactive_result_profile.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_run_command_service.dart';
import 'package:flutter_cockpit_devtools/src/remote/cockpit_android_port_forwarder.dart';
import 'package:flutter_cockpit_devtools/src/session/cockpit_remote_session_handle.dart';
import 'package:test/test.dart';

void main() {
  test('app-first commands return the refreshed remote session handle',
      () async {
    Uri? capturedBaseUri;
    final service = CockpitRunCommandService(
      appReferenceResolver: CockpitAppReferenceResolver(
        portForwarder: CockpitAndroidPortForwarder(
          processRunner: (_, __) async => ProcessResult(
            0,
            0,
            'emulator-5554 tcp:61331 tcp:47331\n',
            '',
          ),
          hostPortAllocator: () async => 61331,
          hostPortAvailabilityChecker: (_) async => false,
        ),
      ),
      executeService: CockpitExecuteRemoteCommandService(
        executeCommand: (baseUri, command) async {
          capturedBaseUri = baseUri;
          return CockpitCommandExecution(
            result: CockpitCommandResult(
              success: true,
              commandId: command.commandId,
              commandType: command.commandType,
              durationMs: 24,
            ),
          );
        },
      ),
    );

    final result = await service.run(
      CockpitRunCommandRequest(
        app: _androidAppHandle(),
        command: CockpitCommand(
          commandId: 'tap-save',
          commandType: CockpitCommandType.tap,
        ),
        resultProfile: const CockpitInteractiveResultProfile.minimal(),
      ),
    );

    expect(capturedBaseUri.toString(), 'http://127.0.0.1:61331');
    expect(result.sessionHandle?.baseUrl, 'http://127.0.0.1:61331');
    expect(result.sessionHandle?.devicePort, 47331);
  });
}

CockpitAppHandle _androidAppHandle() {
  return CockpitAppHandle(
    appId: 'android-app',
    mode: CockpitAppMode.automation,
    platform: 'android',
    deviceId: 'emulator-5554',
    projectDir: '/workspace/app',
    target: 'cockpit/main.dart',
    baseUrl: 'http://127.0.0.1:57331',
    launchedAt: DateTime.utc(2026, 5, 10),
    remoteSession: CockpitRemoteSessionHandle(
      platform: 'android',
      deviceId: 'emulator-5554',
      projectDir: '/workspace/app',
      target: 'cockpit/main.dart',
      appId: 'android-app',
      host: '127.0.0.1',
      hostPort: 57331,
      devicePort: 47331,
      baseUrl: 'http://127.0.0.1:57331',
      launchedAt: DateTime.utc(2026, 5, 10),
    ),
  );
}

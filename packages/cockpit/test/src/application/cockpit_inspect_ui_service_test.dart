import 'dart:io';

import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:cockpit/src/application/cockpit_app_handle.dart';
import 'package:cockpit/src/application/cockpit_app_reference_resolver.dart';
import 'package:cockpit/src/application/cockpit_inspect_ui_service.dart';
import 'package:cockpit/src/application/cockpit_interactive_result_profile.dart';
import 'package:cockpit/src/application/cockpit_read_remote_snapshot_service.dart';
import 'package:cockpit/src/remote/cockpit_android_port_forwarder.dart';
import 'package:cockpit/src/session/cockpit_remote_session_handle.dart';
import 'package:test/test.dart';

void main() {
  test(
    'app-first inspection returns the refreshed remote session handle',
    () async {
      Uri? capturedBaseUri;
      final service = CockpitInspectUiService(
        appReferenceResolver: CockpitAppReferenceResolver(
          portForwarder: CockpitAndroidPortForwarder(
            processRunner: (_, _) async =>
                ProcessResult(0, 0, 'emulator-5554 tcp:61331 tcp:47331\n', ''),
            hostPortAllocator: () async => 61331,
            hostPortAvailabilityChecker: (_) async => false,
          ),
        ),
        snapshotService: CockpitReadRemoteSnapshotService(
          readSnapshot: (baseUri, options) async {
            capturedBaseUri = baseUri;
            return CockpitRemoteSnapshotResponse(
              snapshot: CockpitSnapshot(
                routeName: '/home',
                diagnosticLevel: options.profile,
              ),
            );
          },
        ),
      );

      final result = await service.inspect(
        CockpitInspectUiRequest(
          app: _androidAppHandle(),
          resultProfile: const CockpitInteractiveResultProfile.minimal(),
        ),
      );

      expect(capturedBaseUri.toString(), 'http://127.0.0.1:61331');
      expect(result.routeName, '/home');
      expect(result.snapshot, isNull);
    },
  );
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

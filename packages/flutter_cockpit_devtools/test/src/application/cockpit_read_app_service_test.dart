import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_app_handle.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_interactive_result_profile.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_read_app_service.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_read_remote_status_service.dart';
import 'package:test/test.dart';

void main() {
  test('read app includes selected plane and recommended next step', () async {
    final app = CockpitAppHandle(
      appId: 'dev.cockpit.demo',
      mode: CockpitAppMode.automation,
      platform: 'android',
      deviceId: 'emulator-5554',
      projectDir: '/workspace/examples/cockpit_demo',
      target: 'cockpit/main.dart',
      baseUrl: 'http://127.0.0.1:47331',
      launchedAt: DateTime.utc(2026, 4, 11),
    );
    final service = CockpitReadAppService(
      remoteStatusService: CockpitReadRemoteStatusService(
        readStatus: (_) async => CockpitRemoteSessionStatus(
          sessionId: 'session-1',
          platform: 'android',
          transportType: 'remoteHttp',
          currentRouteName: '/home',
          capabilities: CockpitCapabilities(
            platform: 'android',
            transportType: 'remoteHttp',
            supportsInAppControl: true,
            supportsFlutterViewCapture: true,
            supportsNativeScreenCapture: true,
            supportsHostAutomation: false,
            supportedCommands: const <CockpitCommandType>[
              CockpitCommandType.tap,
            ],
            supportedLocatorStrategies: CockpitLocatorKind.values,
          ),
          recordingCapabilities: CockpitRecordingCapabilities(
            supportsNativeRecording: true,
            preferredAcceptanceRecordingKind: CockpitRecordingKind.nativeScreen,
          ),
          snapshot: CockpitSnapshot(routeName: '/home'),
        ),
      ),
    );

    final result = await service.read(
      CockpitReadAppRequest(
        app: app,
        resultProfile: const CockpitInteractiveResultProfile.minimal(),
      ),
    );

    expect(result.selectedPlane, CockpitPlaneKind.flutterSemanticPlane);
    expect(result.fallbackTrail, <CockpitPlaneKind>[
      CockpitPlaneKind.nativeUiPlane,
      CockpitPlaneKind.deviceSystemPlane,
    ]);
    expect(result.recommendedNextStep, 'runNextCommand');
    expect(result.toJson()['selectedPlane'], 'flutterSemanticPlane');
  });
}

import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_app_handle.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_interactive_result_profile.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_read_app_service.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_read_target_service.dart';
import 'package:flutter_cockpit_devtools/src/targets/cockpit_target_handle.dart';
import 'package:test/test.dart';

void main() {
  test('read target reuses flutter app reads and returns target-first summary',
      () async {
    final target = CockpitTargetHandle.fromAppHandle(
      CockpitAppHandle(
        appId: 'dev.cockpit.demo',
        mode: CockpitAppMode.automation,
        platform: 'android',
        deviceId: 'emulator-5554',
        projectDir: '/workspace/examples/cockpit_demo',
        target: 'cockpit/main.dart',
        baseUrl: 'http://127.0.0.1:57331',
        launchedAt: DateTime.utc(2026, 4, 11),
      ),
    );
    final service = CockpitReadTargetService(
      readFlutterTarget: (_) async => CockpitReadAppResult(
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
          preferredAcceptanceRecordingKind:
              CockpitRecordingKind.nativeScreen,
        ),
        selectedPlane: CockpitPlaneKind.flutterSemanticPlane,
        fallbackTrail: const <CockpitPlaneKind>[
          CockpitPlaneKind.nativeUiPlane,
          CockpitPlaneKind.deviceSystemPlane,
        ],
        recommendedNextStep: 'runNextCommand',
        currentRouteName: '/home',
      ),
    );

    final result = await service.read(
      CockpitReadTargetRequest(
        target: target,
        resultProfile: const CockpitInteractiveResultProfile.minimal(),
      ),
    );

    expect(result.target.targetKind, CockpitTargetKind.flutterApp);
    expect(result.foregroundSurface, CockpitSurfaceKind.flutterSemantic);
    expect(result.selectedPlane, CockpitPlaneKind.flutterSemanticPlane);
    expect(result.recommendedNextStep, 'runNextCommand');
  });
}

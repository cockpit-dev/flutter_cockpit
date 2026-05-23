import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_app_handle.dart';
import 'package:flutter_cockpit_devtools/src/targets/cockpit_target_handle.dart';
import 'package:test/test.dart';

void main() {
  test(
    'app handle projects into flutter target handle without losing fields',
    () {
      final app = CockpitAppHandle(
        appId: 'demo',
        mode: CockpitAppMode.automation,
        platform: 'android',
        deviceId: 'emulator-5554',
        projectDir: '/repo/examples/cockpit_demo',
        target: 'cockpit/main.dart',
        baseUrl: 'http://127.0.0.1:47331',
        launchedAt: DateTime.utc(2026, 4, 11),
        platformAppId: 'dev.example.demo',
        processId: 4101,
      );

      final target = CockpitTargetHandle.fromAppHandle(app);

      expect(target.targetId, 'demo');
      expect(target.targetKind, CockpitTargetKind.flutterApp);
      expect(target.platform, 'android');
      expect(target.deviceId, 'emulator-5554');
      expect(target.connection.baseUri.toString(), app.baseUrl);
      expect(target.metadata['appMode'], 'automation');
      expect(target.metadata['platformAppId'], 'dev.example.demo');
      expect(target.metadata['processId'], 4101);
    },
  );

  test('target handle round-trips through json', () {
    final target = CockpitTargetHandle(
      targetId: 'target-1',
      targetKind: CockpitTargetKind.browserPage,
      platform: 'web',
      deviceId: 'chrome',
      projectDir: '/repo',
      target: '/app',
      connection: const CockpitTargetConnection(
        baseUrl: 'http://127.0.0.1:9222',
      ),
      launchedAt: DateTime.utc(2026, 4, 11),
      capabilityProfile: CockpitCapabilityProfile(
        targetKind: CockpitTargetKind.browserPage,
        surfaceKinds: <CockpitSurfaceKind>{CockpitSurfaceKind.browserDom},
        actionCapabilities: <CockpitActionCapability>{
          CockpitActionCapability.tap,
        },
        evidenceCapabilities: <CockpitEvidenceCapability>{
          CockpitEvidenceCapability.domSnapshot,
        },
      ),
      metadata: const <String, Object?>{
        'title': 'Demo',
        'appMode': 'automation',
      },
    );

    expect(CockpitTargetHandle.fromJson(target.toJson()), target);
  });
}

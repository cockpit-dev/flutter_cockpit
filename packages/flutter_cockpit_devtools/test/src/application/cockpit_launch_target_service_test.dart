import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_app_handle.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_launch_app_service.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_launch_target_service.dart';
import 'package:test/test.dart';

void main() {
  test('launch target wraps flutter app launch results in a target handle',
      () async {
    final service = CockpitLaunchTargetService(
      launchFlutterApp: (_) async => CockpitLaunchAppResult(
        app: CockpitAppHandle(
          appId: 'dev.cockpit.demo',
          mode: CockpitAppMode.development,
          platform: 'android',
          deviceId: 'emulator-5554',
          projectDir: '/workspace/examples/cockpit_demo',
          target: 'cockpit/main.dart',
          baseUrl: 'http://127.0.0.1:57331',
          launchedAt: DateTime.utc(2026, 4, 11),
        ),
      ),
    );

    final result = await service.launch(
      const CockpitLaunchTargetRequest(
        projectDir: '/workspace/examples/cockpit_demo',
        platform: 'android',
        deviceId: 'emulator-5554',
        sessionPort: 57331,
      ),
    );

    expect(result.target.targetKind, CockpitTargetKind.flutterApp);
    expect(result.target.baseUri.toString(), 'http://127.0.0.1:57331');
    expect(result.app?.appId, 'dev.cockpit.demo');
  });
}

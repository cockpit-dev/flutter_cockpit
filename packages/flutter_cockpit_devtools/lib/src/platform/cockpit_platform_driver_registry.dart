import 'android/cockpit_android_platform_driver.dart';
import 'cockpit_evidence_driver.dart';
import 'cockpit_platform_driver.dart';
import 'ios/cockpit_ios_device_connection.dart';
import 'ios/cockpit_ios_physical_platform_driver.dart';
import 'ios/cockpit_ios_simulator_platform_driver.dart';
import 'linux/cockpit_linux_platform_driver.dart';
import 'macos/cockpit_macos_platform_driver.dart';
import 'web/cockpit_web_platform_driver.dart';
import 'windows/cockpit_windows_platform_driver.dart';

typedef CockpitPlatformDriverFactory = CockpitPlatformDriver Function({
  required String deviceId,
});

final class CockpitPlatformDriverRegistry {
  CockpitPlatformDriverRegistry({
    Map<String, CockpitPlatformDriverFactory> drivers = const {},
  }) : _drivers = Map<String, CockpitPlatformDriverFactory>.unmodifiable(
          drivers,
        );

  final Map<String, CockpitPlatformDriverFactory> _drivers;

  CockpitPlatformDriver? resolve({
    required String platform,
    required String deviceId,
    String? appId,
    int? processId,
  }) {
    final override = _drivers[platform];
    if (override != null) {
      return override(deviceId: deviceId);
    }
    return switch (platform) {
      'android' => CockpitAndroidPlatformDriver(deviceId: deviceId),
      'ios' => cockpitLooksLikeIosSimulatorDeviceId(deviceId)
          ? CockpitIosSimulatorPlatformDriver(deviceId: deviceId)
          : CockpitIosPhysicalPlatformDriver(deviceId: deviceId),
      'macos' => CockpitMacosPlatformDriver(appId: appId),
      'windows' => CockpitWindowsPlatformDriver(
          appId: appId,
          processId: processId,
        ),
      'linux' => CockpitLinuxPlatformDriver(
          appId: appId,
          processId: processId,
        ),
      'web' => CockpitWebPlatformDriver(deviceId: deviceId),
      _ => null,
    };
  }

  CockpitEvidenceDriver? resolveEvidenceDriver({
    required String platform,
    required String deviceId,
    String? appId,
    int? processId,
  }) {
    final driver = resolve(
      platform: platform,
      deviceId: deviceId,
      appId: appId,
      processId: processId,
    );
    if (driver is CockpitEvidenceDriver) {
      return driver as CockpitEvidenceDriver;
    }
    return null;
  }
}

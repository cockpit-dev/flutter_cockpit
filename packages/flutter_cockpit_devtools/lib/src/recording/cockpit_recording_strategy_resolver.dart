import '../adapters/cockpit_recording_adapter.dart';
import '../remote/cockpit_remote_recording_adapter.dart';
import '../remote/cockpit_remote_session_client.dart';
import '../session/cockpit_remote_session_handle.dart';
import 'cockpit_adb_recording_adapter.dart';
import 'cockpit_linux_recording_adapter.dart';
import 'cockpit_macos_recording_adapter.dart';
import 'cockpit_simctl_recording_adapter.dart';
import 'cockpit_windows_recording_adapter.dart';

typedef CockpitRemoteRecordingAdapterFactory = CockpitRecordingAdapter Function(
    CockpitRemoteSessionClient client);
typedef CockpitAdbRecordingAdapterFactory = CockpitRecordingAdapter Function(
    String deviceId);
typedef CockpitSimctlRecordingAdapterFactory = CockpitRecordingAdapter Function(
    String deviceId);
typedef CockpitMacosRecordingAdapterFactory = CockpitRecordingAdapter Function(
    String appId);
typedef CockpitWindowsRecordingAdapterFactory = CockpitRecordingAdapter
    Function(String appId);
typedef CockpitLinuxRecordingAdapterFactory = CockpitRecordingAdapter Function(
    String appId);

final class CockpitRecordingStrategyResolver {
  const CockpitRecordingStrategyResolver({
    this.remoteAdapterFactory = _defaultRemoteAdapterFactory,
    this.adbAdapterFactory = _defaultAdbAdapterFactory,
    this.simctlAdapterFactory = _defaultSimctlAdapterFactory,
    this.macosAdapterFactory = _defaultMacosAdapterFactory,
    this.windowsAdapterFactory = _defaultWindowsAdapterFactory,
    this.linuxAdapterFactory = _defaultLinuxAdapterFactory,
  });

  final CockpitRemoteRecordingAdapterFactory remoteAdapterFactory;
  final CockpitAdbRecordingAdapterFactory adbAdapterFactory;
  final CockpitSimctlRecordingAdapterFactory simctlAdapterFactory;
  final CockpitMacosRecordingAdapterFactory macosAdapterFactory;
  final CockpitWindowsRecordingAdapterFactory windowsAdapterFactory;
  final CockpitLinuxRecordingAdapterFactory linuxAdapterFactory;

  CockpitRecordingAdapter? resolve({
    required String platform,
    required Object? recording,
    required CockpitRemoteSessionClient client,
    CockpitRemoteSessionHandle? sessionHandle,
    String? androidDeviceId,
    String? iosDeviceId,
  }) {
    if (recording == null) {
      return null;
    }
    if (platform == 'android' &&
        androidDeviceId != null &&
        androidDeviceId.isNotEmpty) {
      return adbAdapterFactory(androidDeviceId);
    }
    if (platform == 'ios' && iosDeviceId != null && iosDeviceId.isNotEmpty) {
      return simctlAdapterFactory(iosDeviceId);
    }
    if (platform == 'macos' &&
        sessionHandle != null &&
        sessionHandle.appId.isNotEmpty) {
      return macosAdapterFactory(sessionHandle.appId);
    }
    if (platform == 'windows' &&
        sessionHandle != null &&
        sessionHandle.appId.isNotEmpty) {
      return windowsAdapterFactory(sessionHandle.appId);
    }
    if (platform == 'linux' &&
        sessionHandle != null &&
        sessionHandle.appId.isNotEmpty) {
      return linuxAdapterFactory(sessionHandle.appId);
    }
    return remoteAdapterFactory(client);
  }

  static CockpitRecordingAdapter _defaultRemoteAdapterFactory(
    CockpitRemoteSessionClient client,
  ) {
    return CockpitRemoteRecordingAdapter(client: client);
  }

  static CockpitRecordingAdapter _defaultAdbAdapterFactory(String deviceId) {
    return CockpitAdbRecordingAdapter(deviceId: deviceId);
  }

  static CockpitRecordingAdapter _defaultSimctlAdapterFactory(String deviceId) {
    return CockpitSimctlRecordingAdapter(deviceId: deviceId);
  }

  static CockpitRecordingAdapter _defaultMacosAdapterFactory(String appId) {
    return CockpitMacosRecordingAdapter(appId: appId);
  }

  static CockpitRecordingAdapter _defaultWindowsAdapterFactory(String appId) {
    return CockpitWindowsRecordingAdapter(appId: appId);
  }

  static CockpitRecordingAdapter _defaultLinuxAdapterFactory(String appId) {
    return CockpitLinuxRecordingAdapter(appId: appId);
  }
}

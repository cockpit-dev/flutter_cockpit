import '../adapters/cockpit_capture_adapter.dart';
import '../remote/cockpit_remote_capture_adapter.dart';
import '../remote/cockpit_remote_session_client.dart';
import '../session/cockpit_remote_session_handle.dart';
import 'cockpit_adb_capture_adapter.dart';
import 'cockpit_host_preferred_capture_adapter.dart';
import 'cockpit_macos_capture_adapter.dart';
import 'cockpit_simctl_capture_adapter.dart';

typedef CockpitRemoteCaptureAdapterFactory = CockpitCaptureAdapter Function(
    CockpitRemoteSessionClient client);
typedef CockpitAdbCaptureAdapterFactory = CockpitCaptureAdapter Function(
    String deviceId);
typedef CockpitSimctlCaptureAdapterFactory = CockpitCaptureAdapter Function(
    String deviceId);
typedef CockpitMacosCaptureAdapterFactory = CockpitCaptureAdapter Function(
    String appId);

final class CockpitCaptureStrategyResolver {
  const CockpitCaptureStrategyResolver({
    this.remoteAdapterFactory = _defaultRemoteAdapterFactory,
    this.adbAdapterFactory = _defaultAdbAdapterFactory,
    this.simctlAdapterFactory = _defaultSimctlAdapterFactory,
    this.macosAdapterFactory = _defaultMacosAdapterFactory,
  });

  final CockpitRemoteCaptureAdapterFactory remoteAdapterFactory;
  final CockpitAdbCaptureAdapterFactory adbAdapterFactory;
  final CockpitSimctlCaptureAdapterFactory simctlAdapterFactory;
  final CockpitMacosCaptureAdapterFactory macosAdapterFactory;

  CockpitCaptureAdapter resolve({
    required String platform,
    required CockpitRemoteSessionClient client,
    CockpitRemoteSessionHandle? sessionHandle,
    String? androidDeviceId,
    String? iosDeviceId,
  }) {
    final remoteAdapter = remoteAdapterFactory(client);
    if (platform == 'android' &&
        androidDeviceId != null &&
        androidDeviceId.isNotEmpty) {
      return CockpitHostPreferredCaptureAdapter(
        remoteAdapter: remoteAdapter,
        hostAcceptanceAdapter: adbAdapterFactory(androidDeviceId),
        client: client,
      );
    }
    if (platform == 'ios' && iosDeviceId != null && iosDeviceId.isNotEmpty) {
      return CockpitHostPreferredCaptureAdapter(
        remoteAdapter: remoteAdapter,
        hostAcceptanceAdapter: simctlAdapterFactory(iosDeviceId),
        client: client,
      );
    }
    if (platform == 'macos' &&
        sessionHandle != null &&
        sessionHandle.appId.isNotEmpty) {
      return CockpitHostPreferredCaptureAdapter(
        remoteAdapter: remoteAdapter,
        hostAcceptanceAdapter: macosAdapterFactory(sessionHandle.appId),
        client: client,
      );
    }
    return remoteAdapter;
  }

  static CockpitCaptureAdapter _defaultRemoteAdapterFactory(
    CockpitRemoteSessionClient client,
  ) {
    return CockpitRemoteCaptureAdapter(client: client);
  }

  static CockpitCaptureAdapter _defaultAdbAdapterFactory(String deviceId) {
    return CockpitAdbCaptureAdapter(deviceId: deviceId);
  }

  static CockpitCaptureAdapter _defaultSimctlAdapterFactory(String deviceId) {
    return CockpitSimctlCaptureAdapter(deviceId: deviceId);
  }

  static CockpitCaptureAdapter _defaultMacosAdapterFactory(String appId) {
    return CockpitMacosCaptureAdapter(appId: appId);
  }
}

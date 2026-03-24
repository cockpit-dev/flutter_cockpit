import '../adapters/cockpit_capture_adapter.dart';
import '../remote/cockpit_remote_capture_adapter.dart';
import '../remote/cockpit_remote_session_client.dart';
import 'cockpit_adb_capture_adapter.dart';
import 'cockpit_host_preferred_capture_adapter.dart';
import 'cockpit_simctl_capture_adapter.dart';

typedef CockpitRemoteCaptureAdapterFactory = CockpitCaptureAdapter Function(
    CockpitRemoteSessionClient client);
typedef CockpitAdbCaptureAdapterFactory = CockpitCaptureAdapter Function(
    String deviceId);
typedef CockpitSimctlCaptureAdapterFactory = CockpitCaptureAdapter Function(
    String deviceId);

final class CockpitCaptureStrategyResolver {
  const CockpitCaptureStrategyResolver({
    this.remoteAdapterFactory = _defaultRemoteAdapterFactory,
    this.adbAdapterFactory = _defaultAdbAdapterFactory,
    this.simctlAdapterFactory = _defaultSimctlAdapterFactory,
  });

  final CockpitRemoteCaptureAdapterFactory remoteAdapterFactory;
  final CockpitAdbCaptureAdapterFactory adbAdapterFactory;
  final CockpitSimctlCaptureAdapterFactory simctlAdapterFactory;

  CockpitCaptureAdapter resolve({
    required String platform,
    required CockpitRemoteSessionClient client,
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
}

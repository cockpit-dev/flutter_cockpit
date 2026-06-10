import '../adapters/cockpit_capture_adapter.dart';
import '../platform/ios/cockpit_ios_device_connection.dart';
import '../remote/cockpit_remote_capture_adapter.dart';
import '../remote/cockpit_remote_session_client.dart';
import '../session/cockpit_remote_session_handle.dart';
import 'cockpit_adb_capture_adapter.dart';
import 'cockpit_host_preferred_capture_adapter.dart';
import 'cockpit_linux_capture_adapter.dart';
import 'cockpit_macos_capture_adapter.dart';
import 'cockpit_simctl_capture_adapter.dart';
import 'cockpit_windows_capture_adapter.dart';

typedef CockpitRemoteCaptureAdapterFactory =
    CockpitCaptureAdapter Function(CockpitRemoteSessionClient client);
typedef CockpitAdbCaptureAdapterFactory =
    CockpitCaptureAdapter Function(String deviceId);
typedef CockpitSimctlCaptureAdapterFactory =
    CockpitCaptureAdapter Function(String deviceId);
typedef CockpitMacosCaptureAdapterFactory =
    CockpitCaptureAdapter Function(String appId);
typedef CockpitWindowsCaptureAdapterFactory =
    CockpitCaptureAdapter Function(String appId, {int? processId});
typedef CockpitLinuxCaptureAdapterFactory =
    CockpitCaptureAdapter Function(String appId, {int? processId});

final class CockpitCaptureStrategyResolver {
  const CockpitCaptureStrategyResolver({
    this.remoteAdapterFactory = _defaultRemoteAdapterFactory,
    this.adbAdapterFactory = _defaultAdbAdapterFactory,
    this.simctlAdapterFactory = _defaultSimctlAdapterFactory,
    this.macosAdapterFactory = _defaultMacosAdapterFactory,
    this.windowsAdapterFactory = _defaultWindowsAdapterFactory,
    this.linuxAdapterFactory = _defaultLinuxAdapterFactory,
  });

  final CockpitRemoteCaptureAdapterFactory remoteAdapterFactory;
  final CockpitAdbCaptureAdapterFactory adbAdapterFactory;
  final CockpitSimctlCaptureAdapterFactory simctlAdapterFactory;
  final CockpitMacosCaptureAdapterFactory macosAdapterFactory;
  final CockpitWindowsCaptureAdapterFactory windowsAdapterFactory;
  final CockpitLinuxCaptureAdapterFactory linuxAdapterFactory;

  CockpitCaptureAdapter resolve({
    required String platform,
    required CockpitRemoteSessionClient client,
    String? platformAppId,
    int? processId,
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
    if (platform == 'ios' &&
        iosDeviceId != null &&
        iosDeviceId.isNotEmpty &&
        cockpitLooksLikeIosSimulatorDeviceId(iosDeviceId)) {
      return CockpitHostPreferredCaptureAdapter(
        remoteAdapter: remoteAdapter,
        hostAcceptanceAdapter: simctlAdapterFactory(iosDeviceId),
        client: client,
      );
    }
    final resolvedAppId = _hostAppIdFor(
      platform: platform,
      platformAppId: platformAppId ?? sessionHandle?.effectivePlatformAppId,
      processId: processId ?? sessionHandle?.processId,
    );
    final resolvedProcessId = processId ?? sessionHandle?.processId;
    if (platform == 'macos' &&
        resolvedAppId != null &&
        resolvedAppId.isNotEmpty) {
      return CockpitHostPreferredCaptureAdapter(
        remoteAdapter: remoteAdapter,
        hostAcceptanceAdapter: macosAdapterFactory(resolvedAppId),
        client: client,
      );
    }
    if (platform == 'windows' &&
        resolvedAppId != null &&
        resolvedAppId.isNotEmpty) {
      return CockpitHostPreferredCaptureAdapter(
        remoteAdapter: remoteAdapter,
        hostAcceptanceAdapter: windowsAdapterFactory(
          resolvedAppId,
          processId: resolvedProcessId,
        ),
        client: client,
      );
    }
    if (platform == 'linux' &&
        resolvedAppId != null &&
        resolvedAppId.isNotEmpty) {
      return CockpitHostPreferredCaptureAdapter(
        remoteAdapter: remoteAdapter,
        hostAcceptanceAdapter: linuxAdapterFactory(
          resolvedAppId,
          processId: resolvedProcessId,
        ),
        client: client,
      );
    }
    return remoteAdapter;
  }

  String? _hostAppIdFor({
    required String platform,
    required String? platformAppId,
    required int? processId,
  }) {
    final trimmed = platformAppId?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      return trimmed;
    }
    if ((platform == 'windows' || platform == 'linux') && processId != null) {
      return 'pid-$processId';
    }
    return null;
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

  static CockpitCaptureAdapter _defaultWindowsAdapterFactory(
    String appId, {
    int? processId,
  }) {
    return CockpitWindowsCaptureAdapter(appId: appId, processId: processId);
  }

  static CockpitCaptureAdapter _defaultLinuxAdapterFactory(
    String appId, {
    int? processId,
  }) {
    return CockpitLinuxCaptureAdapter(appId: appId, processId: processId);
  }
}

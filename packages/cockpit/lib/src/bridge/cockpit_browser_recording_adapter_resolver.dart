import 'dart:io';

import '../recording/cockpit_host_recording_adapter.dart';
import '../recording/cockpit_linux_recording_adapter.dart';
import '../recording/cockpit_macos_recording_adapter.dart';
import '../recording/cockpit_windows_recording_adapter.dart';
import '../platform/web/cockpit_browser_host_app_id.dart';

bool cockpitSupportsBrowserRecordingDeviceId(String deviceId) {
  return cockpitResolveBrowserHostAppId(deviceId) != null;
}

CockpitHostRecordingAdapter? cockpitResolveBrowserRecordingAdapter({
  required String deviceId,
}) {
  final appId = cockpitResolveBrowserHostAppId(deviceId);
  if (appId == null) {
    return null;
  }

  if (Platform.isMacOS) {
    return CockpitMacosRecordingAdapter(appId: appId);
  }

  if (Platform.isWindows) {
    return CockpitWindowsRecordingAdapter(appId: appId);
  }

  if (Platform.isLinux) {
    return CockpitLinuxRecordingAdapter(appId: appId);
  }

  return null;
}

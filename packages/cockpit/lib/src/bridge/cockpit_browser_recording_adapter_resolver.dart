import 'dart:io';

import '../recording/cockpit_host_recording_adapter.dart';
import '../recording/cockpit_linux_recording_adapter.dart';
import '../recording/cockpit_macos_recording_adapter.dart';
import '../recording/cockpit_windows_recording_adapter.dart';

bool cockpitSupportsBrowserRecordingDeviceId(String deviceId) {
  return _resolveBrowserRecordingAppId(deviceId) != null;
}

CockpitHostRecordingAdapter? cockpitResolveBrowserRecordingAdapter({
  required String deviceId,
}) {
  final appId = _resolveBrowserRecordingAppId(deviceId);
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

String? _resolveBrowserRecordingAppId(String deviceId) {
  final normalized = deviceId.trim().toLowerCase();
  if (normalized.isEmpty) {
    return null;
  }

  if (Platform.isMacOS) {
    return switch (normalized) {
      'chrome' => 'com.google.Chrome',
      'edge' => 'com.microsoft.edgemac',
      'firefox' => 'org.mozilla.firefox',
      _ => null,
    };
  }

  if (Platform.isWindows) {
    return switch (normalized) {
      'chrome' => 'chrome',
      'edge' => 'msedge',
      'firefox' => 'firefox',
      _ => null,
    };
  }

  if (Platform.isLinux) {
    return switch (normalized) {
      'chrome' => 'google-chrome',
      'edge' => 'microsoft-edge',
      'firefox' => 'firefox',
      _ => null,
    };
  }

  return null;
}

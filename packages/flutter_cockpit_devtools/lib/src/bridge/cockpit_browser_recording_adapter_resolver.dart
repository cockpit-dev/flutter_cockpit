import 'dart:io';

import '../recording/cockpit_host_recording_adapter.dart';
import '../recording/cockpit_linux_recording_adapter.dart';
import '../recording/cockpit_macos_recording_adapter.dart';
import '../recording/cockpit_windows_recording_adapter.dart';

CockpitHostRecordingAdapter? cockpitResolveBrowserRecordingAdapter({
  required String deviceId,
}) {
  final normalized = deviceId.trim().toLowerCase();
  if (normalized.isEmpty) {
    return null;
  }

  if (Platform.isMacOS) {
    final appId = switch (normalized) {
      'chrome' => 'com.google.Chrome',
      'edge' => 'com.microsoft.edgemac',
      'firefox' => 'org.mozilla.firefox',
      _ => null,
    };
    return appId == null ? null : CockpitMacosRecordingAdapter(appId: appId);
  }

  if (Platform.isWindows) {
    final appId = switch (normalized) {
      'chrome' => 'chrome',
      'edge' => 'msedge',
      'firefox' => 'firefox',
      _ => null,
    };
    return appId == null ? null : CockpitWindowsRecordingAdapter(appId: appId);
  }

  if (Platform.isLinux) {
    final appId = switch (normalized) {
      'chrome' => 'google-chrome',
      'edge' => 'microsoft-edge',
      'firefox' => 'firefox',
      _ => null,
    };
    return appId == null ? null : CockpitLinuxRecordingAdapter(appId: appId);
  }

  return null;
}

import 'dart:io';

String? cockpitResolveBrowserHostAppId(String deviceId) {
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

import 'dart:io';

import 'cockpit_android_remote_session_launcher.dart';
import 'cockpit_apple_bundle_support.dart';
import 'cockpit_linux_remote_session_launcher.dart';
import 'cockpit_session_path.dart';
import 'cockpit_windows_remote_session_launcher.dart';

typedef CockpitPlatformAppIdResolver =
    Future<String?> Function({
      required String projectDir,
      required String platform,
      String? flavor,
    });

Future<String?> cockpitResolvePlatformAppId({
  required String projectDir,
  required String platform,
  String? flavor,
}) async {
  switch (platform.trim().toLowerCase()) {
    case 'android':
      return CockpitAndroidRemoteSessionLauncher.resolveApplicationId(
        projectDir: projectDir,
      );
    case 'ios':
      return _resolveIosPlatformAppId(projectDir: projectDir, flavor: flavor);
    case 'macos':
      return _resolveMacosPlatformAppId(projectDir: projectDir, flavor: flavor);
    case 'windows':
      return CockpitWindowsRemoteSessionLauncher.resolveAppBaseName(
        projectDir: projectDir,
      );
    case 'linux':
      return CockpitLinuxRemoteSessionLauncher.resolveAppBaseName(
        projectDir: projectDir,
      );
    default:
      return null;
  }
}

Future<String?> _resolveIosPlatformAppId({
  required String projectDir,
  required String? flavor,
}) async {
  final pathContext = cockpitSessionPathContext(projectDir);
  for (final outputName in const <String>['iphonesimulator', 'iphoneos']) {
    final buildDirectory = Directory(
      pathContext.join(projectDir, 'build', 'ios', outputName),
    );
    if (!buildDirectory.existsSync()) {
      continue;
    }
    final appBundlePath = cockpitSelectBestAppBundlePath(
      searchRoot: buildDirectory,
      flavor: flavor,
      pathContext: pathContext,
      platformLabel: outputName == 'iphonesimulator'
          ? 'iOS simulator'
          : 'iOS device',
    );
    final bundleId = await cockpitResolveIosBundleId(
      appBundlePath: appBundlePath,
    );
    final normalized = bundleId.trim();
    if (normalized.isNotEmpty) {
      return normalized;
    }
  }
  return null;
}

Future<String?> _resolveMacosPlatformAppId({
  required String projectDir,
  required String? flavor,
}) async {
  final pathContext = cockpitSessionPathContext(projectDir);
  final productsDirectory = Directory(
    pathContext.join(
      projectDir,
      'build',
      'macos',
      'Build',
      'Products',
      'Debug',
    ),
  );
  if (!productsDirectory.existsSync()) {
    return null;
  }
  final appBundlePath = cockpitSelectBestAppBundlePath(
    searchRoot: productsDirectory,
    flavor: flavor,
    pathContext: pathContext,
    platformLabel: 'macOS',
  );
  final bundleId = await cockpitResolveMacosBundleId(
    appBundlePath: appBundlePath,
  );
  final normalized = bundleId.trim();
  return normalized.isEmpty ? null : normalized;
}

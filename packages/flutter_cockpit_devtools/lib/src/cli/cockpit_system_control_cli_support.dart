import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';

import '../application/cockpit_app_handle.dart';
import '../session/cockpit_platform_app_identity.dart';
import 'cockpit_interactive_cli_support.dart';

/// Reads the app handle backing system-control commands. The implicit default
/// handle file is best-effort, but an explicitly passed `--app-json` that is
/// unreadable or malformed must fail loudly instead of silently degrading
/// into a misleading missing-platform usage error.
CockpitAppHandle? cockpitReadSystemControlAppHandle({
  required ArgResults? argResults,
  required String usage,
}) {
  final path = cockpitResolveAppHandlePath(argResults);
  if (path == null || path.isEmpty) {
    return null;
  }
  final explicitPath = argResults?['app-json'] as String?;
  final isExplicit = explicitPath != null && explicitPath.isNotEmpty;
  try {
    final decoded = jsonDecode(File(path).readAsStringSync());
    if (decoded is Map<Object?, Object?>) {
      return CockpitAppHandle.fromJson(decoded.cast<String, Object?>());
    }
  } on Object catch (error) {
    if (isExplicit) {
      throw UsageException(
        'Failed to read the app handle at $path: $error',
        usage,
      );
    }
    return null;
  }
  if (isExplicit) {
    throw UsageException(
      'The app handle at $path must contain a JSON object.',
      usage,
    );
  }
  return null;
}

Map<String, Object?> cockpitReadSystemControlWdaMetadata(
  ArgResults? argResults,
) {
  final wdaUrl =
      argResults?['wda-url'] as String? ??
      Platform.environment['FLUTTER_COCKPIT_IOS_WDA_URL'];
  if (wdaUrl == null || wdaUrl.trim().isEmpty) {
    return const <String, Object?>{};
  }
  return <String, Object?>{'wdaUrl': wdaUrl.trim()};
}

Future<String?> cockpitResolveSystemControlAppId({
  required CockpitAppHandle? app,
  required String platform,
  required String? explicitAppId,
}) async {
  final explicit = explicitAppId?.trim();
  final handleAppId = app?.appId.trim();
  final appPlatformId = app?.platformAppId?.trim();
  if (explicit != null && explicit.isNotEmpty) {
    if (explicit == handleAppId &&
        appPlatformId != null &&
        appPlatformId.isNotEmpty) {
      return appPlatformId;
    }
    return explicit;
  }
  if (appPlatformId != null && appPlatformId.isNotEmpty) {
    return appPlatformId;
  }
  if (app == null) {
    return null;
  }
  try {
    return await cockpitResolvePlatformAppId(
      projectDir: app.projectDir,
      platform: platform,
    );
  } on Object {
    return null;
  }
}

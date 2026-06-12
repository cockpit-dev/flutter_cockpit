import '../application/cockpit_app_handle.dart';
import '../session/cockpit_platform_app_identity.dart';

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

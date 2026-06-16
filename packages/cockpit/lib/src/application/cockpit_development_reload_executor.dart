import 'dart:io';

import 'package:path/path.dart' as p;

import '../development/cockpit_development_session_status.dart';
import 'cockpit_app_handle.dart';
import 'cockpit_app_reference_resolver.dart';
import 'cockpit_application_service_exception.dart';
import 'cockpit_compact_json.dart';
import 'cockpit_reload_development_session_service.dart';
import 'cockpit_session_registry.dart';

final class CockpitDevelopmentReloadOutcome {
  const CockpitDevelopmentReloadOutcome({
    required this.app,
    required this.status,
    this.appJsonPath,
  });

  final CockpitAppHandle app;
  final CockpitDevelopmentSessionStatus status;
  final String? appJsonPath;
}

Future<CockpitDevelopmentReloadOutcome> cockpitExecuteDevelopmentReload({
  required CockpitDevelopmentReloadMode mode,
  required String unavailableCode,
  required String unavailableMessage,
  required CockpitReloadDevelopmentSessionService reloadService,
  required CockpitAppReferenceResolver appReferenceResolver,
  required CockpitSessionRegistry? registry,
  String? appId,
  CockpitAppHandle? app,
  String? appHandlePath,
}) async {
  final resolved = await appReferenceResolver.resolve(
    appId: appId,
    app: app,
    appHandlePath: appHandlePath,
  );
  final developmentHandle =
      resolved.app?.developmentSession ?? resolved.developmentRecord?.handle;
  if (developmentHandle == null) {
    throw CockpitApplicationServiceException(
      code: unavailableCode,
      message: unavailableMessage,
    );
  }
  final reloaded = await reloadService.reload(
    CockpitReloadDevelopmentSessionRequest(
      mode: mode,
      sessionHandle: developmentHandle,
    ),
  );
  registry?.recordDevelopmentSession(
    handle: reloaded.sessionHandle,
    status: reloaded.status,
    supervisorLogPath: resolved.developmentRecord?.supervisorLogPath,
  );
  final resultApp = CockpitAppHandle.fromDevelopmentSession(
    reloaded.sessionHandle,
    supervisorLogPath:
        resolved.app?.supervisorLogPath ??
        resolved.developmentRecord?.supervisorLogPath,
  );
  final appJsonPath = await _persistAppIfRequested(
    path: appHandlePath,
    app: resultApp,
  );
  return CockpitDevelopmentReloadOutcome(
    app: resultApp,
    status: reloaded.status,
    appJsonPath: appJsonPath,
  );
}

Future<String?> _persistAppIfRequested({
  required String? path,
  required CockpitAppHandle app,
}) async {
  if (path == null || path.isEmpty) {
    return null;
  }
  final file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsString(cockpitPrettyJsonText(app.toJson()));
  return p.normalize(file.path);
}

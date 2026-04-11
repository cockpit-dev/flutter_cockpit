import 'dart:io';

import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:path/path.dart' as p;

import '../targets/cockpit_target_handle.dart';
import 'cockpit_app_handle.dart';
import 'cockpit_application_service_exception.dart';
import 'cockpit_compact_json.dart';
import 'cockpit_launch_app_service.dart';

typedef CockpitLaunchTargetFunction = Future<CockpitLaunchTargetResult>
    Function(
  CockpitLaunchTargetRequest request,
);
typedef CockpitLaunchFlutterAppTargetFunction = Future<CockpitLaunchAppResult>
    Function(
  CockpitLaunchAppRequest request,
);

final class CockpitLaunchTargetRequest {
  const CockpitLaunchTargetRequest({
    required this.projectDir,
    required this.platform,
    required this.deviceId,
    required this.sessionPort,
    this.target,
    this.targetKind = CockpitTargetKind.flutterApp,
    this.mode = CockpitAppMode.development,
    this.launchTimeout = const Duration(seconds: 120),
    this.targetHandlePath,
  });

  final String projectDir;
  final String? target;
  final String platform;
  final String deviceId;
  final int sessionPort;
  final CockpitTargetKind targetKind;
  final CockpitAppMode mode;
  final Duration launchTimeout;
  final String? targetHandlePath;
}

final class CockpitLaunchTargetResult {
  const CockpitLaunchTargetResult({
    required this.target,
    this.targetJsonPath,
    this.app,
  });

  final CockpitTargetHandle target;
  final String? targetJsonPath;
  final CockpitAppHandle? app;

  Map<String, Object?> toJson() => <String, Object?>{
        'target': target.toJson(),
        if (targetJsonPath != null) 'targetJsonPath': targetJsonPath,
        if (app != null) 'app': app!.toJson(),
      };
}

final class CockpitLaunchTargetService {
  CockpitLaunchTargetService({
    CockpitLaunchTargetFunction? launchTarget,
    CockpitLaunchAppService? launchAppService,
    CockpitLaunchFlutterAppTargetFunction? launchFlutterApp,
  })  : _launchTargetOverride = launchTarget,
        _launchFlutterApp = launchFlutterApp ??
            (launchAppService ?? CockpitLaunchAppService()).launch;

  final CockpitLaunchTargetFunction? _launchTargetOverride;
  final CockpitLaunchFlutterAppTargetFunction _launchFlutterApp;

  Future<CockpitLaunchTargetResult> launch(
    CockpitLaunchTargetRequest request,
  ) async {
    final override = _launchTargetOverride;
    if (override != null) {
      return override(request);
    }

    if (request.targetKind != CockpitTargetKind.flutterApp) {
      throw CockpitApplicationServiceException(
        code: 'unsupportedTargetKind',
        message: 'launch-target currently supports flutterApp targets only.',
        details: <String, Object?>{'targetKind': request.targetKind.name},
      );
    }

    final appResult = await _launchFlutterApp(
      CockpitLaunchAppRequest(
        projectDir: request.projectDir,
        target: request.target,
        platform: request.platform,
        deviceId: request.deviceId,
        sessionPort: request.sessionPort,
        mode: request.mode,
        launchTimeout: request.launchTimeout,
      ),
    );
    final target = CockpitTargetHandle.fromAppHandle(appResult.app);
    final targetJsonPath = await _persistTargetIfRequested(
      path: request.targetHandlePath,
      target: target,
    );
    return CockpitLaunchTargetResult(
      target: target,
      targetJsonPath: targetJsonPath,
      app: appResult.app,
    );
  }

  Future<String?> _persistTargetIfRequested({
    required String? path,
    required CockpitTargetHandle target,
  }) async {
    if (path == null || path.isEmpty) {
      return null;
    }
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString(cockpitPrettyJsonText(target.toJson()));
    return p.normalize(file.path);
  }
}

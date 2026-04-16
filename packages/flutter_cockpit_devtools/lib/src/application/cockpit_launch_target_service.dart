import 'dart:io';

import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:path/path.dart' as p;

import '../platform/cockpit_platform_driver_registry.dart';
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
    this.flavor,
    this.targetKind = CockpitTargetKind.flutterApp,
    this.mode = CockpitAppMode.development,
    this.launchTimeout = const Duration(seconds: 120),
    this.targetHandlePath,
  });

  final String projectDir;
  final String? target;
  final String? flavor;
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
    CockpitPlatformDriverRegistry? platformDriverRegistry,
  })  : _launchTargetOverride = launchTarget,
        _launchFlutterApp = launchFlutterApp ??
            (launchAppService ?? CockpitLaunchAppService()).launch,
        _platformDriverRegistry =
            platformDriverRegistry ?? CockpitPlatformDriverRegistry();

  final CockpitLaunchTargetFunction? _launchTargetOverride;
  final CockpitLaunchFlutterAppTargetFunction _launchFlutterApp;
  final CockpitPlatformDriverRegistry _platformDriverRegistry;

  Future<CockpitLaunchTargetResult> launch(
    CockpitLaunchTargetRequest request,
  ) async {
    final override = _launchTargetOverride;
    if (override != null) {
      return override(request);
    }

    final capabilityProfile = await _resolveCapabilityProfile(
      platform: request.platform,
      deviceId: request.deviceId,
    );
    final normalizedTargetKind = _normalizeTargetKind(
      requestedTargetKind: request.targetKind,
      capabilityProfile: capabilityProfile,
    );

    if (!_isLaunchableTargetKind(normalizedTargetKind)) {
      throw CockpitApplicationServiceException(
        code: 'unsupportedTargetKind',
        message: 'launch-target cannot directly launch this target kind.',
        details: <String, Object?>{
          'targetKind': normalizedTargetKind.name,
          'platform': request.platform,
          'recommendedNextStep': 'createTargetHandleExternally',
        },
      );
    }

    final appResult = await _launchFlutterApp(
      CockpitLaunchAppRequest(
        projectDir: request.projectDir,
        target: request.target,
        flavor: request.flavor,
        platform: request.platform,
        deviceId: request.deviceId,
        sessionPort: request.sessionPort,
        mode: request.mode,
        launchTimeout: request.launchTimeout,
      ),
    );
    final target = CockpitTargetHandle.fromAppHandle(appResult.app).copyWith(
      targetKind: normalizedTargetKind,
      capabilityProfile: capabilityProfile,
    );
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

  Future<CockpitCapabilityProfile> _resolveCapabilityProfile({
    required String platform,
    required String deviceId,
  }) async {
    final driver = _platformDriverRegistry.resolve(
      platform: platform,
      deviceId: deviceId,
    );
    if (driver == null) {
      throw CockpitApplicationServiceException(
        code: 'unsupportedPlatform',
        message: 'launch-target does not support this platform.',
        details: <String, Object?>{'platform': platform},
      );
    }
    return driver.describeCapabilities();
  }

  CockpitTargetKind _normalizeTargetKind({
    required CockpitTargetKind requestedTargetKind,
    required CockpitCapabilityProfile capabilityProfile,
  }) {
    if (requestedTargetKind == capabilityProfile.targetKind) {
      return requestedTargetKind;
    }
    if (requestedTargetKind == CockpitTargetKind.flutterApp &&
        (capabilityProfile.targetKind == CockpitTargetKind.desktopApp ||
            capabilityProfile.targetKind == CockpitTargetKind.browserPage)) {
      return capabilityProfile.targetKind;
    }
    throw CockpitApplicationServiceException(
      code: 'unsupportedTargetKind',
      message: 'The requested target kind is incompatible with this platform.',
      details: <String, Object?>{
        'requestedTargetKind': requestedTargetKind.name,
        'platformTargetKind': capabilityProfile.targetKind.name,
      },
    );
  }

  bool _isLaunchableTargetKind(CockpitTargetKind targetKind) {
    return switch (targetKind) {
      CockpitTargetKind.flutterApp ||
      CockpitTargetKind.desktopApp ||
      CockpitTargetKind.browserPage =>
        true,
      CockpitTargetKind.nativeApp ||
      CockpitTargetKind.systemSurface ||
      CockpitTargetKind.device ||
      CockpitTargetKind.hostWorkspace =>
        false,
    };
  }
}

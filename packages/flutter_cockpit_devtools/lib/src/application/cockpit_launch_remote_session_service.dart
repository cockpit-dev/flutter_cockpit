import 'dart:io';

import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:path/path.dart' as p;

import '../session/cockpit_remote_session_handle.dart';
import '../session/cockpit_remote_session_launch_options.dart';
import '../session/cockpit_remote_session_launcher.dart';
import 'cockpit_entrypoint_resolver.dart';
import 'cockpit_compact_json.dart';

final class CockpitLaunchRemoteSessionRequest {
  const CockpitLaunchRemoteSessionRequest({
    required this.projectDir,
    required this.platform,
    required this.deviceId,
    required this.sessionPort,
    this.target,
    this.flavor,
    this.launchTimeout = const Duration(seconds: 120),
    this.persistHandlePath,
  });

  final String projectDir;
  final String? target;
  final String? flavor;
  final String platform;
  final String deviceId;
  final int sessionPort;
  final Duration launchTimeout;
  final String? persistHandlePath;
}

final class CockpitLaunchRemoteSessionResult {
  const CockpitLaunchRemoteSessionResult({
    required this.sessionHandle,
    required this.health,
    this.persistedHandlePath,
  });

  final CockpitRemoteSessionHandle sessionHandle;
  final CockpitRemoteSessionStatus health;
  final String? persistedHandlePath;
}

final class CockpitLaunchRemoteSessionService {
  CockpitLaunchRemoteSessionService({
    CockpitRemoteSessionLauncher? launcher,
    CockpitRemoteSessionStatusReader? statusReader,
    CockpitEntrypointResolver? entrypointResolver,
  }) : _launcher = launcher ?? CockpitPlatformRemoteSessionLauncher(),
       _statusReader = statusReader ?? cockpitReadRemoteSessionStatus,
       _entrypointResolver = entrypointResolver ?? CockpitEntrypointResolver();

  final CockpitRemoteSessionLauncher _launcher;
  final CockpitRemoteSessionStatusReader _statusReader;
  final CockpitEntrypointResolver _entrypointResolver;

  Future<CockpitLaunchRemoteSessionResult> launch(
    CockpitLaunchRemoteSessionRequest request,
  ) async {
    final normalizedProjectDir = cockpitNormalizeProjectDir(request.projectDir);
    final resolvedTarget = _entrypointResolver.resolve(
      projectDir: normalizedProjectDir,
      target: request.target,
    );
    final sessionHandle = await _launcher.launch(
      CockpitRemoteSessionLaunchOptions(
        projectDir: normalizedProjectDir,
        target: resolvedTarget,
        platform: request.platform,
        deviceId: request.deviceId,
        sessionPort: request.sessionPort,
        flavor: request.flavor,
        launchTimeout: request.launchTimeout,
      ),
    );
    final health = await _statusReader(sessionHandle.baseUri);
    final persistedHandlePath = await _persistHandleIfRequested(
      path: request.persistHandlePath,
      handle: sessionHandle,
    );

    return CockpitLaunchRemoteSessionResult(
      sessionHandle: sessionHandle,
      health: health,
      persistedHandlePath: persistedHandlePath,
    );
  }

  Future<String?> _persistHandleIfRequested({
    required String? path,
    required CockpitRemoteSessionHandle handle,
  }) async {
    if (path == null || path.isEmpty) {
      return null;
    }

    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString(cockpitPrettyJsonText(handle.toJson()));
    return p.normalize(file.path);
  }
}

import 'dart:async';
import 'dart:io';

import 'cockpit_app_handle.dart';
import 'cockpit_application_service_exception.dart';
import '../platform/ios/cockpit_ios_device_connection.dart';
import '../platform/ios/cockpit_ios_device_process.dart';
import '../session/cockpit_session_process_runner.dart';

typedef CockpitPlatformStopProcessRunner =
    Future<ProcessResult> Function(String executable, List<String> arguments);

final class CockpitPlatformAppStopper {
  CockpitPlatformAppStopper({
    CockpitPlatformStopProcessRunner? processRunner,
    CockpitIosDeviceProcessTerminator? iosDeviceProcessTerminator,
  }) : _processRunner = processRunner ?? _defaultProcessRunner,
       _iosDeviceProcessTerminator =
           iosDeviceProcessTerminator ?? CockpitIosDeviceProcessTerminator();

  final CockpitPlatformStopProcessRunner _processRunner;
  final CockpitIosDeviceProcessTerminator _iosDeviceProcessTerminator;

  Future<void> stop(CockpitAppHandle app) async {
    final appId = app.platformAppId ?? app.appId;
    final processId = app.processId;
    if (appId.isEmpty) {
      return;
    }

    switch (app.platform) {
      case 'android':
        await _bestEffortRun('adb', <String>[
          '-s',
          app.deviceId,
          'shell',
          'am',
          'force-stop',
          appId,
        ]);
        await _bestEffortRemoveAndroidForward(app);
      case 'ios':
        if (cockpitLooksLikeIosSimulatorDeviceId(app.deviceId)) {
          await _bestEffortRun('xcrun', <String>[
            'simctl',
            'terminate',
            app.deviceId,
            appId,
          ]);
        } else {
          if (app.platformAppId == null || app.platformAppId!.trim().isEmpty) {
            return;
          }
          await _bestEffortTerminateIosPhysicalApp(
            deviceId: app.deviceId,
            bundleId: appId,
          );
        }
      case 'macos':
        await _bestEffortRun('osascript', <String>[
          '-e',
          'tell application id "$appId" to quit',
        ]);
      case 'windows':
        await _bestEffortRun(
          'taskkill',
          processId == null
              ? <String>['/IM', '$appId.exe', '/F']
              : <String>['/PID', '$processId', '/T', '/F'],
        );
      case 'linux':
        await _bestEffortRun(
          processId == null ? 'pkill' : 'kill',
          processId == null
              ? <String>['-x', appId]
              : <String>['-TERM', '$processId'],
        );
      case 'web':
        throw const CockpitApplicationServiceException(
          code: 'unsupportedAutomationPlatform',
          message:
              'stop-app cannot terminate web automation sessions because '
              'web launches only support development mode.',
          details: <String, Object?>{
            'platform': 'web',
            'operation': 'stopApp',
            'recommendedMode': 'development',
          },
        );
    }
  }

  Future<void> _bestEffortRemoveAndroidForward(CockpitAppHandle app) async {
    final hostPort = app.baseUri.port;
    if (hostPort <= 0) {
      return;
    }
    await _bestEffortRun('adb', <String>[
      '-s',
      app.deviceId,
      'forward',
      '--remove',
      'tcp:$hostPort',
    ]);
  }

  Future<void> _bestEffortRun(String executable, List<String> arguments) async {
    try {
      await _processRunner(
        executable,
        arguments,
      ).timeout(const Duration(seconds: 5));
    } on Object {
      // Reachability checks decide whether stop really succeeded.
    }
  }

  Future<void> _bestEffortTerminateIosPhysicalApp({
    required String deviceId,
    required String bundleId,
  }) async {
    try {
      await _iosDeviceProcessTerminator
          .terminateApp(deviceId: deviceId, bundleId: bundleId)
          .timeout(const Duration(seconds: 5));
    } on Object {
      // Reachability checks decide whether stop really succeeded.
    }
  }

  static Future<ProcessResult> _defaultProcessRunner(
    String executable,
    List<String> arguments,
  ) {
    return cockpitRunProcessWithTimeout(
      executable,
      arguments,
      timeout: const Duration(seconds: 5),
    );
  }
}

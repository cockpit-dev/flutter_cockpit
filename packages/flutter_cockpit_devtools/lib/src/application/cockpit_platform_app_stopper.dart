import 'dart:async';
import 'dart:io';

import 'cockpit_app_handle.dart';

typedef CockpitPlatformStopProcessRunner = Future<ProcessResult> Function(
  String executable,
  List<String> arguments,
);

final class CockpitPlatformAppStopper {
  CockpitPlatformAppStopper({
    CockpitPlatformStopProcessRunner? processRunner,
  }) : _processRunner = processRunner ?? _defaultProcessRunner;

  final CockpitPlatformStopProcessRunner _processRunner;

  Future<void> stop(CockpitAppHandle app) async {
    final appId = app.platformAppId ?? app.appId;
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
      case 'ios':
        await _bestEffortRun('xcrun', <String>[
          'simctl',
          'terminate',
          app.deviceId,
          appId,
        ]);
      case 'macos':
        await _bestEffortRun('osascript', <String>[
          '-e',
          'tell application id "$appId" to quit',
        ]);
      case 'windows':
        await _bestEffortRun('taskkill', <String>[
          '/IM',
          '$appId.exe',
          '/F',
        ]);
      case 'linux':
        await _bestEffortRun('pkill', <String>['-x', appId]);
    }
  }

  Future<void> _bestEffortRun(
    String executable,
    List<String> arguments,
  ) async {
    try {
      await _processRunner(executable, arguments).timeout(
        const Duration(seconds: 5),
      );
    } on Object {
      // Reachability checks decide whether stop really succeeded.
    }
  }

  static Future<ProcessResult> _defaultProcessRunner(
    String executable,
    List<String> arguments,
  ) {
    return Process.run(executable, arguments);
  }
}

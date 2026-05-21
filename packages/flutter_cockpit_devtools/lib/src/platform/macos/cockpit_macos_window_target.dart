import 'dart:async';

import '../../capture/cockpit_host_capture_adapter.dart';

typedef CockpitMacosWindowTargetResolver = Future<CockpitMacosWindowTarget>
    Function({
  required String appId,
  required String osascriptExecutable,
  required CockpitCaptureProcessRunner processRunner,
  required Duration timeout,
  required Duration activationSettleDelay,
});

final class CockpitMacosWindowTarget {
  const CockpitMacosWindowTarget({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final int left;
  final int top;
  final int width;
  final int height;
}

Future<CockpitMacosWindowTarget> cockpitResolveMacosWindowTarget({
  required String appId,
  required String osascriptExecutable,
  required CockpitCaptureProcessRunner processRunner,
  required Duration timeout,
  required Duration activationSettleDelay,
}) async {
  final result = await processRunner(osascriptExecutable, <String>[
    '-e',
    _windowTargetScript,
    appId,
    activationSettleDelay.inMilliseconds.toString(),
  ]).timeout(timeout);
  if (result.exitCode != 0) {
    throw StateError(
      'Unable to resolve the active macOS window for $appId: '
      '${result.stderr ?? result.stdout}',
    );
  }

  final stdout = '${result.stdout}'.trim();
  final parts = stdout.split(',');
  if (parts.length != 4) {
    throw StateError(
      'Unable to resolve the active macOS window for $appId: invalid payload.',
    );
  }
  final left = int.tryParse(parts[0].trim());
  final top = int.tryParse(parts[1].trim());
  final width = int.tryParse(parts[2].trim());
  final height = int.tryParse(parts[3].trim());
  if (left == null ||
      top == null ||
      width == null ||
      height == null ||
      width <= 0 ||
      height <= 0) {
    throw StateError(
      'Unable to resolve the active macOS window for $appId: invalid bounds.',
    );
  }

  return CockpitMacosWindowTarget(
    left: left,
    top: top,
    width: width,
    height: height,
  );
}

const String _windowTargetScript = r'''
on run argv
  set appId to item 1 of argv
  set settleMs to item 2 of argv as integer
  set appName to name of application id appId
  tell application id appId to activate
  if settleMs > 0 then
    delay (settleMs / 1000.0)
  end if
  tell application "System Events"
    set targetProcess to first application process whose name is appName
    if (count of windows of targetProcess) is 0 then
      error "No visible macOS window was found for " & appId
    end if
    tell front window of targetProcess
      set {xPos, yPos} to position
      set {windowWidth, windowHeight} to size
    end tell
  end tell
  return (xPos as string) & "," & (yPos as string) & "," & (windowWidth as string) & "," & (windowHeight as string)
end run
''';

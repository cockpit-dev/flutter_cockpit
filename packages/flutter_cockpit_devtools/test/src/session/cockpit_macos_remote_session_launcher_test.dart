import 'dart:io';

import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_cockpit_devtools/src/session/cockpit_macos_remote_session_launcher.dart';
import 'package:flutter_cockpit_devtools/src/session/cockpit_remote_session_launch_options.dart';
import 'package:test/test.dart';

void main() {
  test('macos remote session launcher builds, opens, and returns a handle',
      () async {
    final invocations = <String>[];
    final launcher = CockpitMacosRemoteSessionLauncher(
      flutterVersionReader: () async => '3.38.9',
      processRunner: (executable, arguments, {String? workingDirectory}) async {
        invocations.add('$executable ${arguments.join(' ')}');
        return ProcessResult(0, 0, '', '');
      },
      appBundlePathResolver: ({required String projectDir}) async =>
          '$projectDir/build/macos/Build/Products/Debug/cockpit_demo.app',
      bundleIdResolver: ({required String appBundlePath}) async =>
          'dev.cockpit.cockpitDemo',
      statusReader: (baseUri) async => CockpitRemoteSessionStatus(
        sessionId: 'macos-bootstrap-session',
        platform: 'macos',
        transportType: 'remoteHttp',
        currentRouteName: '/home',
        capabilities: CockpitCapabilities(
          platform: 'macos',
          transportType: 'remoteHttp',
          supportsInAppControl: true,
          supportsFlutterViewCapture: true,
          supportsNativeScreenCapture: true,
          supportsHostAutomation: true,
          supportedCommands: <CockpitCommandType>[CockpitCommandType.tap],
          supportedLocatorStrategies: CockpitLocatorKind.values,
        ),
        recordingCapabilities: CockpitRecordingCapabilities(
          supportsNativeRecording: true,
          preferredAcceptanceRecordingKind: CockpitRecordingKind.nativeScreen,
        ),
        snapshot: CockpitSnapshot(routeName: '/home'),
      ),
    );

    final handle = await launcher.launch(
      const CockpitRemoteSessionLaunchOptions(
        projectDir: '/workspace/examples/cockpit_demo',
        target: 'cockpit/main.dart',
        platform: 'macos',
        deviceId: 'macos',
        sessionPort: 47331,
      ),
    );

    expect(handle.platform, 'macos');
    expect(handle.deviceId, 'macos');
    expect(handle.appId, 'dev.cockpit.cockpitDemo');
    expect(handle.baseUrl, 'http://127.0.0.1:47331');
    expect(
      invocations,
      contains(
        'flutter build macos --debug --target cockpit/main.dart --dart-define=FLUTTER_PILOT_REMOTE_ENABLED=true --dart-define=FLUTTER_PILOT_REMOTE_HOST=127.0.0.1 --dart-define=FLUTTER_PILOT_REMOTE_PORT=47331 --dart-define=FLUTTER_PILOT_FLUTTER_VERSION=3.38.9',
      ),
    );
    expect(
      invocations,
      contains(
        'open -n /workspace/examples/cockpit_demo/build/macos/Build/Products/Debug/cockpit_demo.app',
      ),
    );
  });
}

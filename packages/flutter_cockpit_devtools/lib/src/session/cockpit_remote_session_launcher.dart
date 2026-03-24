import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_cockpit/flutter_cockpit.dart';

import '../remote/cockpit_remote_session_client.dart';
import 'cockpit_android_remote_session_launcher.dart';
import 'cockpit_ios_simulator_remote_session_launcher.dart';
import 'cockpit_macos_remote_session_launcher.dart';
import 'cockpit_remote_session_handle.dart';
import 'cockpit_remote_session_launch_options.dart';

typedef CockpitRemoteSessionStatusReader = Future<CockpitRemoteSessionStatus>
    Function(Uri baseUri);
typedef CockpitFlutterVersionReader = Future<String> Function();

abstract interface class CockpitRemoteSessionLauncher {
  Future<CockpitRemoteSessionHandle> launch(
    CockpitRemoteSessionLaunchOptions options,
  );
}

final class CockpitPlatformRemoteSessionLauncher
    implements CockpitRemoteSessionLauncher {
  CockpitPlatformRemoteSessionLauncher({
    CockpitRemoteSessionLauncher? androidLauncher,
    CockpitRemoteSessionLauncher? iosLauncher,
    CockpitRemoteSessionLauncher? macosLauncher,
  })  : _androidLauncher =
            androidLauncher ?? CockpitAndroidRemoteSessionLauncher(),
        _iosLauncher =
            iosLauncher ?? CockpitIosSimulatorRemoteSessionLauncher(),
        _macosLauncher = macosLauncher ?? CockpitMacosRemoteSessionLauncher();

  final CockpitRemoteSessionLauncher _androidLauncher;
  final CockpitRemoteSessionLauncher _iosLauncher;
  final CockpitRemoteSessionLauncher _macosLauncher;

  @override
  Future<CockpitRemoteSessionHandle> launch(
    CockpitRemoteSessionLaunchOptions options,
  ) {
    switch (options.platform) {
      case 'android':
        return _androidLauncher.launch(options);
      case 'ios':
        return _iosLauncher.launch(options);
      case 'macos':
        return _macosLauncher.launch(options);
      default:
        throw StateError(
          'Unsupported remote session launch platform: ${options.platform}',
        );
    }
  }
}

Future<CockpitRemoteSessionStatus> cockpitReadRemoteSessionStatus(Uri baseUri) {
  return CockpitRemoteSessionClient(baseUri: baseUri).readStatus();
}

Future<String> cockpitReadActiveFlutterVersion() async {
  final result = await Process.run('flutter', <String>[
    '--version',
    '--machine',
  ]);
  if (result.exitCode != 0) {
    throw StateError(
      'Unable to resolve Flutter version: ${result.stderr ?? result.stdout}',
    );
  }

  final decoded = jsonDecode('${result.stdout}');
  if (decoded is! Map<Object?, Object?>) {
    throw StateError('Unable to resolve Flutter version from machine output.');
  }

  final frameworkVersion = decoded['frameworkVersion'];
  if (frameworkVersion is! String || frameworkVersion.trim().isEmpty) {
    throw StateError(
      'Flutter machine output did not include frameworkVersion.',
    );
  }

  return frameworkVersion.trim();
}

Future<CockpitRemoteSessionStatus> cockpitWaitForRemoteSessionReady({
  required Uri baseUri,
  required Duration timeout,
  required CockpitRemoteSessionStatusReader statusReader,
  Duration pollInterval = const Duration(milliseconds: 500),
}) async {
  final deadline = DateTime.now().add(timeout);

  while (DateTime.now().isBefore(deadline)) {
    try {
      return await statusReader(baseUri);
    } on Object {
      await Future<void>.delayed(pollInterval);
    }
  }

  throw TimeoutException(
    'Remote session did not become ready at $baseUri.',
    timeout,
  );
}

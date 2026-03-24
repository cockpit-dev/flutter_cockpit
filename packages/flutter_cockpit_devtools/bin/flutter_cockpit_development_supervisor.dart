import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:flutter_cockpit_devtools/src/development/cockpit_development_session_handle.dart';
import 'package:flutter_cockpit_devtools/src/development/cockpit_development_session_supervisor.dart';
import 'package:flutter_cockpit_devtools/src/development/cockpit_flutter_run_machine_client.dart';
import 'package:flutter_cockpit_devtools/src/remote/cockpit_android_port_forwarder.dart';
import 'package:flutter_cockpit_devtools/src/remote/cockpit_remote_session_client.dart';
import 'package:flutter_cockpit_devtools/src/session/cockpit_remote_session_launch_options.dart';
import 'package:flutter_cockpit_devtools/src/session/cockpit_remote_session_launcher.dart';

Future<void> main(List<String> args) async {
  final parser = ArgParser()
    ..addOption('project-dir', mandatory: true)
    ..addOption('target', mandatory: true)
    ..addOption('platform', mandatory: true)
    ..addOption('device-id', mandatory: true)
    ..addOption('session-port', mandatory: true)
    ..addOption('app-host-port', mandatory: true)
    ..addOption('supervisor-port', mandatory: true)
    ..addOption('flutter-version', mandatory: true)
    ..addOption('launch-timeout-seconds', defaultsTo: '300');
  final results = parser.parse(args);

  final projectDir = results['project-dir']! as String;
  final target = results['target']! as String;
  final platform = results['platform']! as String;
  final deviceId = results['device-id']! as String;
  final sessionPort = int.parse(results['session-port']! as String);
  final appHostPort = int.parse(results['app-host-port']! as String);
  final supervisorPort = int.parse(results['supervisor-port']! as String);
  final launchTimeout = Duration(
    seconds: int.parse(results['launch-timeout-seconds']! as String),
  );

  final remoteHandle = await CockpitPlatformRemoteSessionLauncher().launch(
    CockpitRemoteSessionLaunchOptions(
      projectDir: projectDir,
      target: target,
      platform: platform,
      deviceId: deviceId,
      sessionPort: sessionPort,
      launchTimeout: launchTimeout,
    ),
  );
  final developmentHandle = CockpitDevelopmentSessionHandle(
    developmentSessionId:
        'dev-$platform-${DateTime.now().toUtc().microsecondsSinceEpoch}',
    platform: platform,
    deviceId: deviceId,
    projectDir: projectDir,
    target: target,
    appId: remoteHandle.appId,
    appBaseUrl: remoteHandle.baseUrl,
    supervisorBaseUrl: 'http://127.0.0.1:$supervisorPort',
    remoteSessionHandle: remoteHandle,
    launchedAt: DateTime.now().toUtc(),
    reloadGeneration: 0,
  );

  final portForwarder = const CockpitAndroidPortForwarder();
  final machineClient = await CockpitFlutterRunMachineClient.attach(
    projectDir: projectDir,
    target: target,
    deviceId: deviceId,
    appId: remoteHandle.appId,
  );

  final supervisor = CockpitDevelopmentSessionSupervisor(
    initialHandle: developmentHandle,
    machineClient: machineClient,
    remoteReachabilityProbe: (baseUri) async {
      if (platform == 'android') {
        await portForwarder.ensureForwarded(
          deviceId: deviceId,
          preferredHostPort: appHostPort,
          devicePort: sessionPort,
        );
      }
      try {
        await CockpitRemoteSessionClient(baseUri: baseUri).readStatus();
        return true;
      } on Object {
        return false;
      }
    },
    uiIdleWaiter: (baseUri) async {
      try {
        return await CockpitRemoteSessionClient(
          baseUri: baseUri,
        ).waitForUiIdle();
      } on Object {
        return false;
      }
    },
    appStopper: platform == 'macos'
        ? (appId) async {
            await Process.run('osascript', <String>[
              '-e',
              'tell application id "$appId" to quit',
            ]).timeout(const Duration(seconds: 5));
          }
        : null,
    bindPort: supervisorPort,
  );

  final sigtermSubscription = ProcessSignal.sigterm.watch().listen((_) {
    unawaited(supervisor.stop());
  });
  final sigintSubscription = ProcessSignal.sigint.watch().listen((_) {
    unawaited(supervisor.stop());
  });

  try {
    await supervisor.start();
    await supervisor.done;
  } finally {
    await sigtermSubscription.cancel();
    await sigintSubscription.cancel();
  }
  exit(0);
}

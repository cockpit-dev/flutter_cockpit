import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:flutter_cockpit_devtools/src/development/cockpit_development_session_machine_launcher.dart';
import 'package:flutter_cockpit_devtools/src/development/cockpit_development_session_handle.dart';
import 'package:flutter_cockpit_devtools/src/development/cockpit_development_session_supervisor.dart';
import 'package:flutter_cockpit_devtools/src/development/cockpit_flutter_run_machine_client.dart';
import 'package:flutter_cockpit_devtools/src/remote/cockpit_android_port_forwarder.dart';
import 'package:flutter_cockpit_devtools/src/remote/cockpit_remote_session_client.dart';
import 'package:flutter_cockpit_devtools/src/session/cockpit_remote_session_handle.dart';
import 'package:flutter_cockpit_devtools/src/session/cockpit_remote_session_launcher.dart';

Future<void> main(List<String> args) async {
  final parser = ArgParser()
    ..addOption('project-dir', mandatory: true)
    ..addOption('target', mandatory: true)
    ..addOption('flavor')
    ..addOption('platform', mandatory: true)
    ..addOption('device-id', mandatory: true)
    ..addOption('session-port', mandatory: true)
    ..addOption('app-host-port', mandatory: true)
    ..addOption('supervisor-port', mandatory: true)
    ..addOption('flutter-executable', mandatory: true)
    ..addOption('log-file', mandatory: true)
    ..addOption('flutter-version', mandatory: true)
    ..addOption('launch-timeout-seconds', defaultsTo: '300');
  final results = parser.parse(args);

  final projectDir = results['project-dir']! as String;
  final target = results['target']! as String;
  final flavor = results['flavor'] as String?;
  final platform = results['platform']! as String;
  final deviceId = results['device-id']! as String;
  final sessionPort = int.parse(results['session-port']! as String);
  final appHostPort = int.parse(results['app-host-port']! as String);
  final supervisorPort = int.parse(results['supervisor-port']! as String);
  final flutterExecutable = results['flutter-executable']! as String;
  final flutterVersion = results['flutter-version']! as String;
  final logFilePath = results['log-file']! as String;
  final launchTimeout = Duration(
    seconds: int.parse(results['launch-timeout-seconds']! as String),
  );

  final logFile = File(logFilePath);
  await logFile.parent.create(recursive: true);
  final logSink = logFile.openWrite(mode: FileMode.writeOnlyAppend);
  var pendingLogWrite = Future<void>.value();
  Future<void> writeLog(String message) async {
    final timestamp = DateTime.now().toUtc().toIso8601String();
    pendingLogWrite = pendingLogWrite.then((_) async {
      logSink.writeln('[$timestamp] $message');
      await logSink.flush();
    });
    await pendingLogWrite;
  }

  StreamSubscription<ProcessSignal>? sigtermSubscription;
  StreamSubscription<ProcessSignal>? sigintSubscription;
  try {
    CockpitRemoteSessionHandle? remoteHandle;
    CockpitFlutterRunMachineClient? machineClient;
    final developmentHandle = CockpitDevelopmentSessionHandle(
      developmentSessionId:
          'dev-$platform-${DateTime.now().toUtc().microsecondsSinceEpoch}',
      platform: platform,
      deviceId: deviceId,
      projectDir: projectDir,
      target: target,
      appId: '',
      appBaseUrl:
          'http://${cockpitRemotePublicHostForPlatform(platform)}:$appHostPort',
      supervisorBaseUrl: 'http://127.0.0.1:$supervisorPort',
      launchedAt: DateTime.now().toUtc(),
      reloadGeneration: 0,
    );

    final portForwarder = const CockpitAndroidPortForwarder();
    final machineLauncher = CockpitDevelopmentSessionMachineLauncher(
      portForwarder: portForwarder,
    );
    final machineLaunchRequest = CockpitLaunchDevelopmentMachineSessionRequest(
      projectDir: projectDir,
      target: target,
      flavor: flavor,
      platform: platform,
      deviceId: deviceId,
      sessionPort: sessionPort,
      hostPort: appHostPort,
      launchTimeout: launchTimeout,
      flutterExecutable: flutterExecutable,
      flutterVersion: flutterVersion,
    );
    await writeLog(
      'boot project_dir=$projectDir target=$target platform=$platform '
      'flavor=${flavor ?? ''} '
      'device_id=$deviceId app_host_port=$appHostPort '
      'supervisor_port=$supervisorPort flutter_executable=$flutterExecutable '
      'flutter_version=$flutterVersion',
    );
    final endpoint = await machineLauncher.resolveRemoteSessionEndpoint(
      machineLaunchRequest,
    );
    await writeLog('development machine launch start');
    try {
      machineClient = await machineLauncher.startMachineClient(
        machineLaunchRequest,
        endpoint: endpoint,
      );
    } on Object catch (error) {
      await writeLog('development machine launch failed error=$error');
      rethrow;
    }
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
      logger: writeLog,
      bindPort: supervisorPort,
      settleTimeout: const Duration(seconds: 90),
    );

    sigtermSubscription = ProcessSignal.sigterm.watch().listen((_) {
      unawaited(supervisor.stop());
    });
    sigintSubscription = ProcessSignal.sigint.watch().listen((_) {
      unawaited(supervisor.stop());
    });

    await supervisor.start();
    unawaited(() async {
      try {
        remoteHandle = await machineLauncher.waitForRemoteSession(
          request: machineLaunchRequest,
          machineClient: machineClient!,
          endpoint: endpoint,
        );
        await writeLog(
          'development machine ready app_id=${remoteHandle!.appId} '
          'base_url=${remoteHandle!.baseUrl}',
        );
        await supervisor.bindRemoteSession(remoteHandle!);
      } on Object catch (error) {
        await writeLog('remote launch failed error=$error');
        supervisor.reportStartupFailure(error);
      }
    }());
    await supervisor.done;
  } on Object catch (error, stackTrace) {
    await writeLog('development supervisor failed error=$error');
    await writeLog('development supervisor stack_trace=$stackTrace');
    exitCode = 1;
  } finally {
    await sigtermSubscription?.cancel();
    await sigintSubscription?.cancel();
    await pendingLogWrite;
    await logSink.flush();
    await logSink.close();
  }
  exit(exitCode);
}

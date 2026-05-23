import 'dart:async';

import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_cockpit_devtools/src/development/cockpit_development_session_machine_launcher.dart';
import 'package:flutter_cockpit_devtools/src/development/cockpit_flutter_run_machine_client.dart';
import 'package:flutter_cockpit_devtools/src/platform/ios/cockpit_ios_device_connection.dart';
import 'package:flutter_cockpit_devtools/src/remote/cockpit_android_port_forwarder.dart';
import 'package:test/test.dart';

void main() {
  test(
    'launch starts flutter run with remote session defines and returns the machine app id',
    () async {
      final stdoutController = StreamController<String>();
      final stderrController = StreamController<String>();
      final exitCode = Completer<int>();
      final capturedStarts = <Map<String, Object?>>[];

      final launcher = CockpitDevelopmentSessionMachineLauncher(
        machineClientStarter:
            ({
              required projectDir,
              required target,
              required deviceId,
              flavor,
              flutterExecutable,
              extraArgs = const <String>[],
            }) async {
              capturedStarts.add(<String, Object?>{
                'projectDir': projectDir,
                'target': target,
                'deviceId': deviceId,
                'flavor': flavor,
                'flutterExecutable': flutterExecutable,
                'extraArgs': extraArgs,
              });
              final client = CockpitFlutterRunMachineClient(
                stdoutLines: stdoutController.stream,
                stderrLines: stderrController.stream,
                exitCode: exitCode.future,
                requestWriter: (_) async {},
              );
              stdoutController.add(
                '[{"event":"app.start","params":{"appId":"machine-app-1"}}]',
              );
              stdoutController.add(
                '[{"event":"app.debugPort","params":{"wsUri":"ws://127.0.0.1:34567/abcd/ws"}}]',
              );
              return client;
            },
        statusReader: (_) async => _readyStatus('android'),
        portForwarder: const _RecordingPortForwarder(58331),
        platformAppIdResolver:
            ({required projectDir, required platform, flavor}) async {
              expect(projectDir, '/workspace/examples/cockpit_demo');
              expect(platform, 'android');
              expect(flavor, isNull);
              return 'dev.example.android';
            },
        now: () => DateTime.utc(2026, 4, 4, 15),
      );

      final result = await launcher.launch(
        const CockpitLaunchDevelopmentMachineSessionRequest(
          projectDir: '/workspace/examples/cockpit_demo',
          target: 'cockpit/main.dart',
          platform: 'android',
          deviceId: 'emulator-5554',
          sessionPort: 47331,
          hostPort: 57331,
          launchTimeout: Duration(seconds: 10),
          flutterVersion: '3.39.0',
          flutterExecutable: '/opt/flutter/bin/flutter',
        ),
      );

      expect(capturedStarts, hasLength(1));
      expect(capturedStarts.single['extraArgs'], <String>[
        '--dart-define=FLUTTER_COCKPIT_REMOTE_ENABLED=true',
        '--dart-define=FLUTTER_COCKPIT_REMOTE_HOST=127.0.0.1',
        '--dart-define=FLUTTER_COCKPIT_REMOTE_PORT=47331',
        '--dart-define=FLUTTER_COCKPIT_FLUTTER_VERSION=3.39.0',
      ]);
      expect(result.remoteSessionHandle.appId, 'machine-app-1');
      expect(result.remoteSessionHandle.platformAppId, 'dev.example.android');
      expect(
        result.remoteSessionHandle.effectivePlatformAppId,
        'dev.example.android',
      );
      expect(result.remoteSessionHandle.hostPort, 58331);
      expect(
        result.machineClient.currentVmServiceUri,
        Uri.parse('ws://127.0.0.1:34567/abcd/ws'),
      );

      await stdoutController.close();
      await stderrController.close();
      exitCode.complete(0);
      await result.machineClient.dispose();
    },
  );

  test(
    'ios development launch binds the remote session to a host-reachable address',
    () async {
      final stdoutController = StreamController<String>();
      final stderrController = StreamController<String>();
      final exitCode = Completer<int>();
      final capturedStarts = <Map<String, Object?>>[];

      final launcher = CockpitDevelopmentSessionMachineLauncher(
        machineClientStarter:
            ({
              required projectDir,
              required target,
              required deviceId,
              flavor,
              flutterExecutable,
              extraArgs = const <String>[],
            }) async {
              capturedStarts.add(<String, Object?>{
                'projectDir': projectDir,
                'target': target,
                'deviceId': deviceId,
                'flavor': flavor,
                'flutterExecutable': flutterExecutable,
                'extraArgs': extraArgs,
              });
              final client = CockpitFlutterRunMachineClient(
                stdoutLines: stdoutController.stream,
                stderrLines: stderrController.stream,
                exitCode: exitCode.future,
                requestWriter: (_) async {},
              );
              stdoutController.add(
                '[{"event":"app.start","params":{"appId":"machine-ios-app"}}]',
              );
              stdoutController.add(
                '[{"event":"app.debugPort","params":{"wsUri":"ws://127.0.0.1:35567/ios/ws"}}]',
              );
              return client;
            },
        statusReader: (_) async => _readyStatus('ios'),
        platformAppIdResolver:
            ({required projectDir, required platform, flavor}) async {
              expect(projectDir, '/workspace/examples/cockpit_demo');
              expect(platform, 'ios');
              expect(flavor, isNull);
              return 'dev.example.ios';
            },
        now: () => DateTime.utc(2026, 4, 4, 16),
      );

      final result = await launcher.launch(
        const CockpitLaunchDevelopmentMachineSessionRequest(
          projectDir: '/workspace/examples/cockpit_demo',
          target: 'cockpit/main.dart',
          platform: 'ios',
          deviceId: 'FC5B7D0F-B7FB-4A7A-B1B0-FF28BC289BC2',
          sessionPort: 47331,
          hostPort: 57331,
          launchTimeout: Duration(seconds: 10),
          flutterVersion: '3.39.0',
          flutterExecutable: '/opt/flutter/bin/flutter',
        ),
      );

      expect(capturedStarts, hasLength(1));
      expect(capturedStarts.single['extraArgs'], <String>[
        '--dart-define=FLUTTER_COCKPIT_REMOTE_ENABLED=true',
        '--dart-define=FLUTTER_COCKPIT_REMOTE_HOST=0.0.0.0',
        '--dart-define=FLUTTER_COCKPIT_REMOTE_PORT=47331',
        '--dart-define=FLUTTER_COCKPIT_FLUTTER_VERSION=3.39.0',
      ]);
      expect(result.remoteSessionHandle.appId, 'machine-ios-app');
      expect(result.remoteSessionHandle.platformAppId, 'dev.example.ios');
      expect(
        result.remoteSessionHandle.effectivePlatformAppId,
        'dev.example.ios',
      );
      expect(result.remoteSessionHandle.hostPort, 57331);

      await stdoutController.close();
      await stderrController.close();
      exitCode.complete(0);
      await result.machineClient.dispose();
    },
  );

  test(
    'web development launch uses explicit IPv4 loopback health probes',
    () async {
      final stdoutController = StreamController<String>();
      final stderrController = StreamController<String>();
      final exitCode = Completer<int>();
      final capturedStarts = <Map<String, Object?>>[];
      final probedBaseUris = <Uri>[];

      final launcher = CockpitDevelopmentSessionMachineLauncher(
        machineClientStarter:
            ({
              required projectDir,
              required target,
              required deviceId,
              flavor,
              flutterExecutable,
              extraArgs = const <String>[],
            }) async {
              capturedStarts.add(<String, Object?>{
                'projectDir': projectDir,
                'target': target,
                'deviceId': deviceId,
                'flavor': flavor,
                'flutterExecutable': flutterExecutable,
                'extraArgs': extraArgs,
              });
              final client = CockpitFlutterRunMachineClient(
                stdoutLines: stdoutController.stream,
                stderrLines: stderrController.stream,
                exitCode: exitCode.future,
                requestWriter: (_) async {},
              );
              stdoutController.add(
                '[{"event":"app.start","params":{"appId":"machine-web-app"}}]',
              );
              stdoutController.add(
                '[{"event":"app.debugPort","params":{"wsUri":"ws://127.0.0.1:37567/web/ws"}}]',
              );
              return client;
            },
        statusReader: (baseUri) async {
          probedBaseUris.add(baseUri);
          return _readyStatus('web');
        },
        now: () => DateTime.utc(2026, 4, 4, 17),
      );

      final result = await launcher.launch(
        const CockpitLaunchDevelopmentMachineSessionRequest(
          projectDir: '/workspace/examples/cockpit_demo',
          target: 'cockpit/main.dart',
          platform: 'web',
          deviceId: 'chrome',
          sessionPort: 59331,
          hostPort: 59331,
          launchTimeout: Duration(seconds: 10),
          flutterVersion: '3.39.0',
          flutterExecutable: '/opt/flutter/bin/flutter',
        ),
      );

      expect(capturedStarts, hasLength(1));
      expect(capturedStarts.single['extraArgs'], <String>[
        '--dart-define=FLUTTER_COCKPIT_REMOTE_ENABLED=true',
        '--dart-define=FLUTTER_COCKPIT_REMOTE_HOST=127.0.0.1',
        '--dart-define=FLUTTER_COCKPIT_REMOTE_PORT=59331',
        '--dart-define=FLUTTER_COCKPIT_FLUTTER_VERSION=3.39.0',
      ]);
      expect(probedBaseUris, <Uri>[Uri.parse('http://127.0.0.1:59331')]);
      expect(result.remoteSessionHandle.host, '127.0.0.1');
      expect(result.remoteSessionHandle.baseUrl, 'http://127.0.0.1:59331');

      await stdoutController.close();
      await stderrController.close();
      exitCode.complete(0);
      await result.machineClient.dispose();
    },
  );

  test('passes flavor through the development machine launch', () async {
    final stdoutController = StreamController<String>();
    final stderrController = StreamController<String>();
    final exitCode = Completer<int>();
    final capturedStarts = <Map<String, Object?>>[];

    final launcher = CockpitDevelopmentSessionMachineLauncher(
      machineClientStarter:
          ({
            required projectDir,
            required target,
            required deviceId,
            flavor,
            flutterExecutable,
            extraArgs = const <String>[],
          }) async {
            capturedStarts.add(<String, Object?>{
              'projectDir': projectDir,
              'target': target,
              'deviceId': deviceId,
              'flavor': flavor,
              'flutterExecutable': flutterExecutable,
              'extraArgs': extraArgs,
            });
            final client = CockpitFlutterRunMachineClient(
              stdoutLines: stdoutController.stream,
              stderrLines: stderrController.stream,
              exitCode: exitCode.future,
              requestWriter: (_) async {},
            );
            stdoutController.add(
              '[{"event":"app.start","params":{"appId":"machine-flavor-app"}}]',
            );
            stdoutController.add(
              '[{"event":"app.debugPort","params":{"wsUri":"ws://127.0.0.1:38567/flavor/ws"}}]',
            );
            return client;
          },
      statusReader: (_) async => _readyStatus('android'),
      portForwarder: const _RecordingPortForwarder(58331),
      now: () => DateTime.utc(2026, 4, 4, 17, 30),
    );

    final result = await launcher.launch(
      const CockpitLaunchDevelopmentMachineSessionRequest(
        projectDir: '/workspace/examples/cockpit_demo',
        target: 'cockpit/main.dart',
        flavor: 'staging',
        platform: 'android',
        deviceId: 'emulator-5554',
        sessionPort: 47331,
        hostPort: 57331,
        launchTimeout: Duration(seconds: 10),
        flutterVersion: '3.39.0',
        flutterExecutable: '/opt/flutter/bin/flutter',
      ),
    );

    expect(capturedStarts.single['flavor'], 'staging');

    await stdoutController.close();
    await stderrController.close();
    exitCode.complete(0);
    await result.machineClient.dispose();
  });

  test(
    'physical iOS development launch uses the device tunnel host and IPv6 bind host',
    () async {
      final stdoutController = StreamController<String>();
      final stderrController = StreamController<String>();
      final exitCode = Completer<int>();
      final capturedStarts = <Map<String, Object?>>[];
      final probedBaseUris = <Uri>[];

      final launcher = CockpitDevelopmentSessionMachineLauncher(
        machineClientStarter:
            ({
              required projectDir,
              required target,
              required deviceId,
              flavor,
              flutterExecutable,
              extraArgs = const <String>[],
            }) async {
              capturedStarts.add(<String, Object?>{
                'projectDir': projectDir,
                'target': target,
                'deviceId': deviceId,
                'flavor': flavor,
                'flutterExecutable': flutterExecutable,
                'extraArgs': extraArgs,
              });
              final client = CockpitFlutterRunMachineClient(
                stdoutLines: stdoutController.stream,
                stderrLines: stderrController.stream,
                exitCode: exitCode.future,
                requestWriter: (_) async {},
              );
              stdoutController.add(
                '[{"event":"app.start","params":{"appId":"machine-ios-device-app"}}]',
              );
              stdoutController.add(
                '[{"event":"app.debugPort","params":{"wsUri":"ws://127.0.0.1:36567/ios-device/ws"}}]',
              );
              return client;
            },
        statusReader: (baseUri) async {
          probedBaseUris.add(baseUri);
          return _readyStatus('ios');
        },
        iosDeviceConnectionResolver: (deviceId) async {
          expect(deviceId, '00008110-0009341C2EF3801E');
          return const CockpitIosDeviceConnection(
            isPhysical: true,
            tunnelIpAddress: 'fd69:8f18:f0a9::1',
          );
        },
        now: () => DateTime.utc(2026, 4, 4, 18),
      );

      final result = await launcher.launch(
        const CockpitLaunchDevelopmentMachineSessionRequest(
          projectDir: '/workspace/examples/cockpit_demo',
          target: 'cockpit/main.dart',
          platform: 'ios',
          deviceId: '00008110-0009341C2EF3801E',
          sessionPort: 47331,
          hostPort: 57331,
          launchTimeout: Duration(seconds: 10),
          flutterVersion: '3.39.0',
          flutterExecutable: '/opt/flutter/bin/flutter',
        ),
      );

      expect(capturedStarts, hasLength(1));
      expect(capturedStarts.single['extraArgs'], <String>[
        '--dart-define=FLUTTER_COCKPIT_REMOTE_ENABLED=true',
        '--dart-define=FLUTTER_COCKPIT_REMOTE_HOST=::',
        '--dart-define=FLUTTER_COCKPIT_REMOTE_PORT=47331',
        '--dart-define=FLUTTER_COCKPIT_ENABLE_HTTP_NETWORK_OBSERVER=false',
        '--dart-define=FLUTTER_COCKPIT_ENABLE_RUNTIME_OBSERVER=false',
        '--dart-define=FLUTTER_COCKPIT_FLUTTER_VERSION=3.39.0',
      ]);
      expect(probedBaseUris, <Uri>[
        Uri.parse('http://[fd69:8f18:f0a9::1]:57331'),
      ]);
      expect(result.remoteSessionHandle.host, 'fd69:8f18:f0a9::1');
      expect(
        result.remoteSessionHandle.baseUrl,
        'http://[fd69:8f18:f0a9::1]:57331',
      );

      await stdoutController.close();
      await stderrController.close();
      exitCode.complete(0);
      await result.machineClient.dispose();
    },
  );

  test(
    'fails fast when flutter run exits before the remote session becomes reachable',
    () async {
      final stdoutController = StreamController<String>();
      final stderrController = StreamController<String>();
      final exitCode = Completer<int>();

      final launcher = CockpitDevelopmentSessionMachineLauncher(
        machineClientStarter:
            ({
              required projectDir,
              required target,
              required deviceId,
              flavor,
              flutterExecutable,
              extraArgs = const <String>[],
            }) async {
              final client = CockpitFlutterRunMachineClient(
                stdoutLines: stdoutController.stream,
                stderrLines: stderrController.stream,
                exitCode: exitCode.future,
                requestWriter: (_) async {},
              );
              Future<void>.microtask(() {
                stderrController.add('Lost connection to device.');
                exitCode.complete(1);
              });
              return client;
            },
        statusReader: (_) async => throw StateError('connection refused'),
        portForwarder: const _RecordingPortForwarder(58331),
        now: () => DateTime.utc(2026, 4, 4, 19),
      );

      await expectLater(
        () => launcher.launch(
          const CockpitLaunchDevelopmentMachineSessionRequest(
            projectDir: '/workspace/examples/cockpit_demo',
            target: 'cockpit/main.dart',
            platform: 'android',
            deviceId: 'emulator-5554',
            sessionPort: 47331,
            hostPort: 57331,
            launchTimeout: Duration(seconds: 10),
            flutterVersion: '3.39.0',
            flutterExecutable: '/opt/flutter/bin/flutter',
          ),
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('exitCode=1'),
          ),
        ),
      );

      await stdoutController.close();
      await stderrController.close();
    },
  );

  test(
    'reports a safe automation fallback when physical iOS remote session is ready but app.start never arrives',
    () async {
      final stdoutController = StreamController<String>();
      final stderrController = StreamController<String>();
      final exitCode = Completer<int>();

      final launcher = CockpitDevelopmentSessionMachineLauncher(
        machineClientStarter:
            ({
              required projectDir,
              required target,
              required deviceId,
              flavor,
              flutterExecutable,
              extraArgs = const <String>[],
            }) async {
              final client = CockpitFlutterRunMachineClient(
                stdoutLines: stdoutController.stream,
                stderrLines: stderrController.stream,
                exitCode: exitCode.future,
                requestWriter: (_) async {},
              );
              Future<void>.microtask(() {
                stderrController.add('The Dart VM Service was not discovered.');
                exitCode.complete(1);
              });
              return client;
            },
        statusReader: (_) async => _readyStatus('ios'),
        iosDeviceConnectionResolver: (_) async =>
            const CockpitIosDeviceConnection(
              isPhysical: true,
              tunnelIpAddress: 'fd69:8f18:f0a9::1',
            ),
        now: () => DateTime.utc(2026, 4, 4, 20),
      );

      await expectLater(
        () => launcher.launch(
          const CockpitLaunchDevelopmentMachineSessionRequest(
            projectDir: '/workspace/examples/cockpit_demo',
            target: 'cockpit/main.dart',
            platform: 'ios',
            deviceId: '00008110-0009341C2EF3801E',
            sessionPort: 47331,
            hostPort: 57331,
            launchTimeout: Duration(seconds: 10),
            flutterVersion: '3.39.0',
            flutterExecutable: '/opt/flutter/bin/flutter',
          ),
        ),
        throwsA(
          isA<CockpitDevelopmentSessionFallbackException>()
              .having(
                (error) => error.code,
                'code',
                'iosPhysicalRemoteSessionReadyButDevelopmentAttachFailed',
              )
              .having(
                (error) => error.message,
                'message',
                contains('Automation fallback is safe'),
              ),
        ),
      );

      await stdoutController.close();
      await stderrController.close();
    },
  );

  test(
    'keeps polling physical iOS remote health after flutter run exits so a ready tunnel session can still be reused',
    () async {
      final stdoutController = StreamController<String>();
      final stderrController = StreamController<String>();
      final exitCode = Completer<int>();
      var now = DateTime.utc(2026, 4, 4, 20, 30);
      var statusReadCount = 0;

      final launcher = CockpitDevelopmentSessionMachineLauncher(
        machineClientStarter:
            ({
              required projectDir,
              required target,
              required deviceId,
              flavor,
              flutterExecutable,
              extraArgs = const <String>[],
            }) async {
              final client = CockpitFlutterRunMachineClient(
                stdoutLines: stdoutController.stream,
                stderrLines: stderrController.stream,
                exitCode: exitCode.future,
                requestWriter: (_) async {},
              );
              Future<void>.microtask(() {
                stderrController.add('The Dart VM Service was not discovered.');
                exitCode.complete(1);
              });
              return client;
            },
        statusReader: (_) async {
          statusReadCount += 1;
          if (statusReadCount < 3) {
            throw StateError('connection refused');
          }
          return _readyStatus('ios');
        },
        iosDeviceConnectionResolver: (_) async =>
            const CockpitIosDeviceConnection(
              isPhysical: true,
              tunnelIpAddress: 'fd69:8f18:f0a9::1',
            ),
        delay: (duration) async {
          now = now.add(duration);
        },
        now: () => now,
      );

      await expectLater(
        () => launcher.launch(
          const CockpitLaunchDevelopmentMachineSessionRequest(
            projectDir: '/workspace/examples/cockpit_demo',
            target: 'cockpit/main.dart',
            platform: 'ios',
            deviceId: '00008110-0009341C2EF3801E',
            sessionPort: 47331,
            hostPort: 57331,
            launchTimeout: Duration(seconds: 10),
            flutterVersion: '3.39.0',
            flutterExecutable: '/opt/flutter/bin/flutter',
          ),
        ),
        throwsA(
          isA<CockpitDevelopmentSessionFallbackException>()
              .having(
                (error) => error.code,
                'code',
                'iosPhysicalRemoteSessionReadyButDevelopmentAttachFailed',
              )
              .having(
                (error) => error.remoteSessionHandle?.baseUrl,
                'baseUrl',
                'http://[fd69:8f18:f0a9::1]:57331',
              ),
        ),
      );

      expect(statusReadCount, 3);
      await stdoutController.close();
      await stderrController.close();
    },
  );

  test(
    'physical iOS fallback preserves session identity but leaves platform app id unknown when bundle lookup fails',
    () async {
      final stdoutController = StreamController<String>();
      final stderrController = StreamController<String>();
      final exitCode = Completer<int>();

      final launcher = CockpitDevelopmentSessionMachineLauncher(
        machineClientStarter:
            ({
              required projectDir,
              required target,
              required deviceId,
              flavor,
              flutterExecutable,
              extraArgs = const <String>[],
            }) async {
              final client = CockpitFlutterRunMachineClient(
                stdoutLines: stdoutController.stream,
                stderrLines: stderrController.stream,
                exitCode: exitCode.future,
                requestWriter: (_) async {},
              );
              Future<void>.microtask(() {
                stderrController.add('The Dart VM Service was not discovered.');
                exitCode.complete(1);
              });
              return client;
            },
        statusReader: (_) async => _readyStatus('ios'),
        iosDeviceConnectionResolver: (_) async =>
            const CockpitIosDeviceConnection(
              isPhysical: true,
              tunnelIpAddress: 'fd69:8f18:f0a9::1',
            ),
        iosFallbackAppBundlePathResolver:
            ({required projectDir, flavor}) async {
              throw StateError('missing device app bundle');
            },
        now: () => DateTime.utc(2026, 4, 4, 20, 45),
      );

      await expectLater(
        () => launcher.launch(
          const CockpitLaunchDevelopmentMachineSessionRequest(
            projectDir: '/workspace/examples/cockpit_demo',
            target: 'cockpit/main.dart',
            platform: 'ios',
            deviceId: '00008110-0009341C2EF3801E',
            sessionPort: 47331,
            hostPort: 57331,
            launchTimeout: Duration(seconds: 10),
            flutterVersion: '3.39.0',
            flutterExecutable: '/opt/flutter/bin/flutter',
          ),
        ),
        throwsA(
          isA<CockpitDevelopmentSessionFallbackException>()
              .having(
                (error) => error.remoteSessionHandle?.appId,
                'remoteSessionHandle.appId',
                'remote-session-1',
              )
              .having(
                (error) => error.remoteSessionHandle?.platformAppIdKnown,
                'remoteSessionHandle.platformAppIdKnown',
                isFalse,
              )
              .having(
                (error) => error.remoteSessionHandle?.effectivePlatformAppId,
                'remoteSessionHandle.effectivePlatformAppId',
                isNull,
              ),
        ),
      );

      await stdoutController.close();
      await stderrController.close();
    },
  );

  test(
    'development machine launcher enforces the launch timeout on a hanging remote-health probe',
    () async {
      final launcher = CockpitDevelopmentSessionMachineLauncher(
        machineClientStarter:
            ({
              required projectDir,
              required target,
              required deviceId,
              flavor,
              flutterExecutable,
              extraArgs = const <String>[],
            }) async => CockpitFlutterRunMachineClient(
              stdoutLines: const Stream<String>.empty(),
              stderrLines: const Stream<String>.empty(),
              exitCode: Completer<int>().future,
              requestWriter: (_) async {},
            ),
        statusReader: (_) => Completer<CockpitRemoteSessionStatus>().future,
        portForwarder: const _RecordingPortForwarder(58331),
      );

      expect(
        () => launcher
            .launch(
              const CockpitLaunchDevelopmentMachineSessionRequest(
                projectDir: '/workspace/examples/cockpit_demo',
                target: 'cockpit/main.dart',
                platform: 'android',
                deviceId: 'emulator-5554',
                sessionPort: 47331,
                hostPort: 57331,
                launchTimeout: Duration(milliseconds: 50),
                flutterVersion: '3.39.0',
                flutterExecutable: '/opt/flutter/bin/flutter',
              ),
            )
            .timeout(
              const Duration(milliseconds: 120),
              onTimeout: () => throw StateError(
                'development launcher did not enforce probe timeout',
              ),
            ),
        throwsA(isA<TimeoutException>()),
      );
    },
  );

  test(
    'development machine launcher caps remote-health retry delays to the remaining deadline',
    () async {
      final launcher = CockpitDevelopmentSessionMachineLauncher(
        machineClientStarter:
            ({
              required projectDir,
              required target,
              required deviceId,
              flavor,
              flutterExecutable,
              extraArgs = const <String>[],
            }) async => CockpitFlutterRunMachineClient(
              stdoutLines: const Stream<String>.empty(),
              stderrLines: const Stream<String>.empty(),
              exitCode: Completer<int>().future,
              requestWriter: (_) async {},
            ),
        statusReader: (_) async => throw StateError('still booting'),
        portForwarder: const _RecordingPortForwarder(58331),
      );

      expect(
        () => launcher
            .launch(
              const CockpitLaunchDevelopmentMachineSessionRequest(
                projectDir: '/workspace/examples/cockpit_demo',
                target: 'cockpit/main.dart',
                platform: 'android',
                deviceId: 'emulator-5554',
                sessionPort: 47331,
                hostPort: 57331,
                launchTimeout: Duration(milliseconds: 50),
                flutterVersion: '3.39.0',
                flutterExecutable: '/opt/flutter/bin/flutter',
              ),
            )
            .timeout(
              const Duration(milliseconds: 120),
              onTimeout: () => throw StateError(
                'development launcher slept past the remaining deadline',
              ),
            ),
        throwsA(isA<TimeoutException>()),
      );
    },
  );
}

final class _RecordingPortForwarder extends CockpitAndroidPortForwarder {
  const _RecordingPortForwarder(this.hostPort);

  final int hostPort;

  @override
  Future<int> ensureForwarded({
    required String deviceId,
    required int preferredHostPort,
    required int devicePort,
  }) async {
    expect(deviceId, 'emulator-5554');
    expect(preferredHostPort, 57331);
    expect(devicePort, 47331);
    return hostPort;
  }
}

CockpitRemoteSessionStatus _readyStatus(String platform) {
  return CockpitRemoteSessionStatus(
    sessionId: 'remote-session-1',
    platform: platform,
    transportType: 'http',
    currentRouteName: '/inbox',
    capabilities: CockpitCapabilities(
      platform: platform,
      transportType: 'http',
      supportsInAppControl: true,
      supportsFlutterViewCapture: true,
      supportsNativeScreenCapture: false,
      supportsHostAutomation: false,
    ),
    recordingCapabilities: CockpitRecordingCapabilities(
      supportsNativeRecording: false,
    ),
    snapshot: CockpitSnapshot(routeName: '/inbox'),
  );
}

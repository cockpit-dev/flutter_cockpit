import 'dart:convert';
import 'dart:io';

import 'package:cockpit/src/application/cockpit_launch_development_session_service.dart';
import 'package:cockpit/src/application/cockpit_entrypoint_resolver.dart';
import 'package:cockpit/src/development/cockpit_development_session_handle.dart';
import 'package:cockpit/src/development/cockpit_development_session_machine_launcher.dart';
import 'package:cockpit/src/development/cockpit_development_session_status.dart';
import 'package:cockpit/src/development/cockpit_development_session_supervisor_client.dart';
import 'package:cockpit/src/infrastructure/cockpit_sdk_environment.dart';
import 'package:cockpit/src/remote/cockpit_android_port_forwarder.dart';
import 'package:cockpit/src/session/cockpit_remote_session_handle.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test(
    'launch service returns a reusable development handle, ready status, and optional persisted json',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_launch_development_session_service',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final expectedHandle = _handle();
      final expectedStatus = _readyStatus(expectedHandle);
      final outputFile = File(
        p.join(tempDir.path, 'developmentSessionHandle.json'),
      );

      final service = CockpitLaunchDevelopmentSessionService(
        entrypointResolver: CockpitEntrypointResolver(exists: (_) => true),
        launcher: (request) async {
          expect(
            request.projectDir,
            cockpitNormalizeProjectDir(expectedHandle.projectDir),
          );
          expect(request.target, p.normalize(expectedHandle.target));
          expect(request.platform, expectedHandle.platform);
          expect(request.deviceId, expectedHandle.deviceId);
          expect(request.sessionPort, 47331);
          return CockpitDevelopmentSessionBootstrap(
            sessionHandle: expectedHandle,
            status: expectedStatus,
          );
        },
      );

      final result = await service.launch(
        CockpitLaunchDevelopmentSessionRequest(
          projectDir: expectedHandle.projectDir,
          target: expectedHandle.target,
          platform: expectedHandle.platform,
          deviceId: expectedHandle.deviceId,
          sessionPort: 47331,
          persistHandlePath: outputFile.path,
        ),
      );

      expect(result.sessionHandle.toJson(), expectedHandle.toJson());
      expect(result.status.toJson(), expectedStatus.toJson());
      expect(result.persistedHandlePath, outputFile.path);

      final persistedJson =
          jsonDecode(await outputFile.readAsString()) as Map<String, Object?>;
      expect(persistedJson['developmentSessionId'], 'dev-session-1');
      expect(persistedJson['reloadGeneration'], 1);
      expect(persistedJson['supervisorBaseUrl'], 'http://127.0.0.1:59421');
    },
  );

  test(
    'launch service persists an app handle for app-scoped recording commands',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_launch_development_session_app_handle',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final expectedHandle = _handle();
      final expectedStatus = _readyStatus(expectedHandle);
      final appHandleFile = File(p.join(tempDir.path, 'latest_app.json'));
      final service = CockpitLaunchDevelopmentSessionService(
        entrypointResolver: CockpitEntrypointResolver(exists: (_) => true),
        launcher: (_) async => CockpitDevelopmentSessionBootstrap(
          sessionHandle: expectedHandle,
          status: expectedStatus,
          supervisorLogPath: '/tmp/dev-supervisor.log',
        ),
      );

      final result = await service.launch(
        CockpitLaunchDevelopmentSessionRequest(
          projectDir: expectedHandle.projectDir,
          target: expectedHandle.target,
          platform: expectedHandle.platform,
          deviceId: expectedHandle.deviceId,
          sessionPort: 47331,
          persistAppHandlePath: appHandleFile.path,
        ),
      );

      expect(result.appJsonPath, appHandleFile.path);
      expect(result.app.mode.jsonValue, 'development');
      expect(result.app.remoteSession, isNotNull);
      expect(appHandleFile.existsSync(), isTrue);

      final persistedJson =
          jsonDecode(await appHandleFile.readAsString())
              as Map<String, Object?>;
      expect(persistedJson['mode'], 'development');
      expect(persistedJson['platform'], expectedHandle.platform);
      expect(persistedJson['deviceId'], expectedHandle.deviceId);
      expect(persistedJson['baseUrl'], expectedHandle.appBaseUrl);
      expect(persistedJson['supervisorLogPath'], '/tmp/dev-supervisor.log');
      expect(persistedJson['developmentSession'], isA<Map<String, Object?>>());
      expect(persistedJson['remoteSession'], isA<Map<String, Object?>>());
    },
  );

  test(
    'launch service infers cockpit/main.dart when target is omitted',
    () async {
      final expectedHandle = _handle(target: 'cockpit/main.dart');
      final expectedStatus = _readyStatus(expectedHandle);
      final normalizedProjectDir = cockpitNormalizeProjectDir(
        expectedHandle.projectDir,
      );
      final expectedEntrypointPath = p.join(
        normalizedProjectDir,
        'cockpit',
        'main.dart',
      );

      final service = CockpitLaunchDevelopmentSessionService(
        entrypointResolver: CockpitEntrypointResolver(
          exists: (path) =>
              p.normalize(path) == p.normalize(expectedEntrypointPath),
        ),
        launcher: (request) async {
          expect(request.target, 'cockpit/main.dart');
          return CockpitDevelopmentSessionBootstrap(
            sessionHandle: expectedHandle,
            status: expectedStatus,
          );
        },
      );

      final result = await service.launch(
        CockpitLaunchDevelopmentSessionRequest(
          projectDir: expectedHandle.projectDir,
          platform: expectedHandle.platform,
          deviceId: expectedHandle.deviceId,
          sessionPort: 47331,
        ),
      );

      expect(result.sessionHandle.target, 'cockpit/main.dart');
    },
  );

  test(
    'launch service passes the configured SDK executables to the daemon launcher',
    () async {
      CockpitLaunchDevelopmentSessionRequest? capturedRequest;
      String? versionExecutable;

      final service = CockpitLaunchDevelopmentSessionService(
        sdkEnvironment: const CockpitSdkEnvironment(
          dartExecutable: '/opt/flutter/bin/cache/dart-sdk/bin/dart',
          flutterExecutable: '/opt/flutter/bin/flutter',
        ),
        flutterVersionForExecutableReader: (executable) async {
          versionExecutable = executable;
          return '3.32.0';
        },
        entrypointResolver: CockpitEntrypointResolver(exists: (_) => true),
        supervisorStatusReader: (_) async =>
            CockpitDevelopmentSessionSupervisorResponse(
              sessionHandle: _handle().copyWith(
                platform: 'macos',
                deviceId: 'macos',
                supervisorBaseUrl: 'http://127.0.0.1:60021',
              ),
              status: _readyStatus(_handle()),
            ),
        spawnSupervisor:
            ({
              required request,
              required flutterVersion,
              required flutterExecutable,
              required dartExecutable,
              required hostPort,
              required supervisorPort,
              required supervisorLogFile,
            }) async {
              capturedRequest = request;
              expect(flutterVersion, '3.32.0');
              expect(flutterExecutable, '/opt/flutter/bin/flutter');
              expect(
                dartExecutable,
                '/opt/flutter/bin/cache/dart-sdk/bin/dart',
              );
              return CockpitSpawnedDevelopmentSupervisor(
                baseUri: Uri.parse('http://127.0.0.1:$supervisorPort'),
                stop: () async {},
              );
            },
        allocatePort: () async => 60021,
        delay: (_) async {},
      );

      await service.launch(
        CockpitLaunchDevelopmentSessionRequest(
          projectDir: '/workspace/examples/cockpit_demo',
          target: 'lib/main.dart',
          platform: 'macos',
          deviceId: 'macos',
          sessionPort: 47331,
          launchTimeout: const Duration(seconds: 1),
        ),
      );

      expect(capturedRequest?.platform, 'macos');
      expect(versionExecutable, '/opt/flutter/bin/flutter');
    },
  );

  test(
    'launch service remaps the iOS simulator session port when the preferred host port is occupied',
    () async {
      CockpitLaunchDevelopmentSessionRequest? capturedRequest;
      final remoteSessionHandle = CockpitRemoteSessionHandle(
        platform: 'ios',
        deviceId: 'FC5B7D0F-B7FB-4A7A-B1B0-FF28BC289BC2',
        projectDir: '/workspace/examples/cockpit_demo',
        target: 'cockpit/main.dart',
        appId: 'dev.cockpit.cockpit_demo',
        host: '127.0.0.1',
        hostPort: 59331,
        devicePort: 59331,
        baseUrl: 'http://127.0.0.1:59331',
        launchedAt: DateTime.utc(2026, 3, 21, 0, 0),
      );

      final service = CockpitLaunchDevelopmentSessionService(
        entrypointResolver: CockpitEntrypointResolver(exists: (_) => true),
        launcher: (request) async {
          capturedRequest = request;
          return CockpitDevelopmentSessionBootstrap(
            sessionHandle: _handle().copyWith(
              platform: 'ios',
              deviceId: 'FC5B7D0F-B7FB-4A7A-B1B0-FF28BC289BC2',
              appBaseUrl: 'http://127.0.0.1:59331',
              remoteSessionHandle: remoteSessionHandle,
            ),
            status: _readyStatus(
              _handle().copyWith(
                platform: 'ios',
                deviceId: 'FC5B7D0F-B7FB-4A7A-B1B0-FF28BC289BC2',
                appBaseUrl: 'http://127.0.0.1:59331',
                remoteSessionHandle: remoteSessionHandle,
              ),
            ),
          );
        },
        sessionPortAvailabilityChecker: (_) async => false,
        sessionPortAllocator: () async => 59331,
      );

      final result = await service.launch(
        CockpitLaunchDevelopmentSessionRequest(
          projectDir: '/workspace/examples/cockpit_demo',
          platform: 'ios',
          deviceId: 'FC5B7D0F-B7FB-4A7A-B1B0-FF28BC289BC2',
          sessionPort: 57331,
        ),
      );

      expect(capturedRequest?.sessionPort, 59331);
      expect(result.sessionHandle.remoteSessionHandle?.devicePort, 59331);
      expect(result.app.baseUrl, 'http://127.0.0.1:59331');
    },
  );

  test(
    'daemon launcher writes supervisor logs under the configured directory',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit-supervisor-log-dir-',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });
      String? capturedLogPath;

      final launcher = CockpitDevelopmentSessionDaemonLauncher(
        supervisorStatusReader: (_) async =>
            CockpitDevelopmentSessionSupervisorResponse(
              sessionHandle: _handle().copyWith(
                supervisorBaseUrl: 'http://127.0.0.1:60031',
              ),
              status: _readyStatus(_handle()),
            ),
        portForwarder: const _StubPortForwarder(57331),
        flutterVersionReader: () async => '3.32.0',
        flutterExecutableReader: () async => '/opt/flutter/bin/flutter',
        dartExecutableReader: () async =>
            '/opt/flutter/bin/cache/dart-sdk/bin/dart',
        supervisorLogDirectoryReader: () => tempDir.path,
        allocatePort: () async => 60031,
        delay: (_) async {},
        spawnSupervisor:
            ({
              required request,
              required flutterVersion,
              required flutterExecutable,
              required dartExecutable,
              required hostPort,
              required supervisorPort,
              required supervisorLogFile,
            }) async {
              capturedLogPath = supervisorLogFile.path;
              return CockpitSpawnedDevelopmentSupervisor(
                baseUri: Uri.parse('http://127.0.0.1:$supervisorPort'),
                stop: () async {},
                logPath: supervisorLogFile.path,
              );
            },
      );

      final result = await launcher.launch(
        const CockpitLaunchDevelopmentSessionRequest(
          projectDir: '/workspace/examples/cockpit_demo',
          target: 'cockpit/main.dart',
          platform: 'windows',
          deviceId: 'windows',
          sessionPort: 47331,
          launchTimeout: Duration(seconds: 1),
        ),
      );

      expect(capturedLogPath, startsWith(tempDir.path));
      expect(result.supervisorLogPath, capturedLogPath);
    },
  );

  test(
    'daemon launcher retries by stopping only the failed spawned attempt',
    () async {
      final statusesByBaseUri =
          <Uri, List<CockpitDevelopmentSessionBootstrap?>>{};
      final stopCalls = <Uri>[];
      final spawnCalls = <Uri>[];
      final readyHandle = _handle();
      final readyStatus = _readyStatus(readyHandle);

      final firstBaseUri = Uri.parse('http://127.0.0.1:60001');
      final secondBaseUri = Uri.parse('http://127.0.0.1:60002');
      statusesByBaseUri[firstBaseUri] = <CockpitDevelopmentSessionBootstrap?>[
        null,
        CockpitDevelopmentSessionBootstrap(
          sessionHandle: readyHandle.copyWith(
            supervisorBaseUrl: firstBaseUri.toString(),
          ),
          status: readyStatus.copyWith(
            state: CockpitDevelopmentSessionState.failed,
            lastError: 'startup lock held by another cockpit attempt',
          ),
        ),
      ];
      statusesByBaseUri[secondBaseUri] = <CockpitDevelopmentSessionBootstrap?>[
        CockpitDevelopmentSessionBootstrap(
          sessionHandle: readyHandle.copyWith(
            supervisorBaseUrl: secondBaseUri.toString(),
          ),
          status: readyStatus.copyWith(
            developmentSessionId: readyHandle.developmentSessionId,
          ),
        ),
      ];

      final launcher = CockpitDevelopmentSessionDaemonLauncher(
        supervisorStatusReader: (baseUri) async {
          final queue = statusesByBaseUri[baseUri]!;
          final next = queue.removeAt(0);
          if (next == null) {
            throw StateError('connection refused');
          }
          return CockpitDevelopmentSessionSupervisorResponse(
            sessionHandle: next.sessionHandle,
            status: next.status,
          );
        },
        portForwarder: const _StubPortForwarder(57331),
        flutterVersionReader: () async => '3.39.0',
        flutterExecutableReader: () async => '/opt/flutter/bin/flutter',
        dartExecutableReader: () async =>
            '/opt/flutter/bin/cache/dart-sdk/bin/dart',
        allocatePort: () async => spawnCalls.isEmpty ? 60001 : 60002,
        delay: (_) async {},
        spawnSupervisor:
            ({
              required request,
              required flutterVersion,
              required flutterExecutable,
              required dartExecutable,
              required hostPort,
              required supervisorPort,
              required supervisorLogFile,
            }) async {
              expect(flutterExecutable, '/opt/flutter/bin/flutter');
              expect(
                dartExecutable,
                '/opt/flutter/bin/cache/dart-sdk/bin/dart',
              );
              final baseUri = Uri.parse('http://127.0.0.1:$supervisorPort');
              spawnCalls.add(baseUri);
              return CockpitSpawnedDevelopmentSupervisor(
                baseUri: baseUri,
                stop: () async {
                  stopCalls.add(baseUri);
                },
              );
            },
      );

      final result = await launcher.launch(
        const CockpitLaunchDevelopmentSessionRequest(
          projectDir: '/workspace/examples/cockpit_demo',
          target: 'lib/main.dart',
          platform: 'android',
          deviceId: 'emulator-5554',
          sessionPort: 47331,
          launchTimeout: Duration(seconds: 5),
        ),
      );

      expect(spawnCalls, orderedEquals(<Uri>[firstBaseUri, secondBaseUri]));
      expect(stopCalls, orderedEquals(<Uri>[firstBaseUri]));
      expect(result.sessionHandle.supervisorBaseUri, secondBaseUri);
      expect(result.status.state, CockpitDevelopmentSessionState.ready);
    },
  );

  test(
    'daemon launcher releases successful spawned supervisor without stopping it',
    () async {
      var releaseCalls = 0;
      var stopCalls = 0;

      final launcher = CockpitDevelopmentSessionDaemonLauncher(
        supervisorStatusReader: (_) async =>
            CockpitDevelopmentSessionSupervisorResponse(
              sessionHandle: _handle(),
              status: _readyStatus(_handle()),
            ),
        portForwarder: const _StubPortForwarder(57331),
        flutterVersionReader: () async => '3.39.0',
        flutterExecutableReader: () async => '/opt/flutter/bin/flutter',
        dartExecutableReader: () async =>
            '/opt/flutter/bin/cache/dart-sdk/bin/dart',
        allocatePort: () async => 60041,
        delay: (_) async {},
        spawnSupervisor:
            ({
              required request,
              required flutterVersion,
              required flutterExecutable,
              required dartExecutable,
              required hostPort,
              required supervisorPort,
              required supervisorLogFile,
            }) async {
              return CockpitSpawnedDevelopmentSupervisor(
                baseUri: Uri.parse('http://127.0.0.1:$supervisorPort'),
                stop: () async {
                  stopCalls += 1;
                },
                release: () async {
                  releaseCalls += 1;
                },
              );
            },
      );

      final result = await launcher.launch(
        const CockpitLaunchDevelopmentSessionRequest(
          projectDir: '/workspace/examples/cockpit_demo',
          target: 'lib/main.dart',
          platform: 'macos',
          deviceId: 'macos',
          sessionPort: 47331,
          launchTimeout: Duration(seconds: 5),
        ),
      );

      expect(result.status.state, CockpitDevelopmentSessionState.ready);
      expect(releaseCalls, 1);
      expect(stopCalls, 0);
    },
  );

  test(
    'daemon launcher preserves the original startup failure when stop throws for a detached process',
    () async {
      final launcher = CockpitDevelopmentSessionDaemonLauncher(
        supervisorStatusReader: (_) async {
          throw StateError('connection refused');
        },
        portForwarder: const _StubPortForwarder(57331),
        flutterVersionReader: () async => '3.39.0',
        flutterExecutableReader: () async => '/opt/flutter/bin/flutter',
        dartExecutableReader: () async =>
            '/opt/flutter/bin/cache/dart-sdk/bin/dart',
        allocatePort: () async => 60011,
        delay: (_) async {},
        spawnSupervisor:
            ({
              required request,
              required flutterVersion,
              required flutterExecutable,
              required dartExecutable,
              required hostPort,
              required supervisorPort,
              required supervisorLogFile,
            }) async {
              return CockpitSpawnedDevelopmentSupervisor(
                baseUri: Uri.parse('http://127.0.0.1:$supervisorPort'),
                stop: () async {
                  throw StateError('Process is detached');
                },
              );
            },
      );

      await expectLater(
        () => launcher.launch(
          const CockpitLaunchDevelopmentSessionRequest(
            projectDir: '/workspace/examples/cockpit_demo',
            target: 'lib/main.dart',
            platform: 'android',
            deviceId: 'emulator-5554',
            sessionPort: 47331,
            launchTimeout: Duration(seconds: 1),
          ),
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('connection refused'),
          ),
        ),
      );
    },
  );

  test(
    'daemon launcher retries transient failed supervisor status before timeout',
    () async {
      final firstBaseUri = Uri.parse('http://127.0.0.1:60021');
      final secondBaseUri = Uri.parse('http://127.0.0.1:60022');
      final spawnCalls = <Uri>[];
      final stopCalls = <Uri>[];
      final readyHandle = _handle().copyWith(
        supervisorBaseUrl: secondBaseUri.toString(),
      );

      final launcher = CockpitDevelopmentSessionDaemonLauncher(
        supervisorStatusReader: (baseUri) async {
          if (baseUri == firstBaseUri) {
            return CockpitDevelopmentSessionSupervisorResponse(
              sessionHandle: _handle().copyWith(
                supervisorBaseUrl: firstBaseUri.toString(),
              ),
              status: _readyStatus(_handle()).copyWith(
                state: CockpitDevelopmentSessionState.failed,
                appReachable: false,
                remoteSessionReachable: false,
                lastError:
                    'SocketException: The remote computer refused the network connection. '
                    '(OS Error: The remote computer refused the network connection., errno = 1225)',
              ),
            );
          }
          return CockpitDevelopmentSessionSupervisorResponse(
            sessionHandle: readyHandle,
            status: _readyStatus(readyHandle),
          );
        },
        portForwarder: const _StubPortForwarder(57331),
        flutterVersionReader: () async => '3.39.0',
        flutterExecutableReader: () async => '/opt/flutter/bin/flutter',
        dartExecutableReader: () async =>
            '/opt/flutter/bin/cache/dart-sdk/bin/dart',
        allocatePort: () async => spawnCalls.isEmpty ? 60021 : 60022,
        delay: (_) async {},
        spawnSupervisor:
            ({
              required request,
              required flutterVersion,
              required flutterExecutable,
              required dartExecutable,
              required hostPort,
              required supervisorPort,
              required supervisorLogFile,
            }) async {
              final baseUri = Uri.parse('http://127.0.0.1:$supervisorPort');
              spawnCalls.add(baseUri);
              return CockpitSpawnedDevelopmentSupervisor(
                baseUri: baseUri,
                stop: () async {
                  stopCalls.add(baseUri);
                },
              );
            },
      );

      final result = await launcher.launch(
        const CockpitLaunchDevelopmentSessionRequest(
          projectDir: '/workspace/examples/cockpit_demo',
          target: 'lib/main.dart',
          platform: 'windows',
          deviceId: 'windows',
          sessionPort: 47331,
          launchTimeout: Duration(seconds: 5),
        ),
      );

      expect(spawnCalls, orderedEquals(<Uri>[firstBaseUri, secondBaseUri]));
      expect(stopCalls, orderedEquals(<Uri>[firstBaseUri]));
      expect(result.sessionHandle.supervisorBaseUri, secondBaseUri);
      expect(result.status.state, CockpitDevelopmentSessionState.ready);
    },
  );

  test('daemon launcher appends supervisor log tails to startup failures', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'cockpit-development-supervisor-log-',
    );
    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });
    final supervisorLog = File(p.join(tempDir.path, 'supervisor.log'));
    await supervisorLog.writeAsString(
      '[2026-05-23T18:17:57Z] machine stderr Xcode build failed\n'
      '[2026-05-23T18:17:57Z] resolved remote endpoint bind_host=127.0.0.1 public_host=127.0.0.1 session_port=47331 app_host_port=47331\n'
      '[2026-05-23T18:17:58Z] control plane ready base_url=http://127.0.0.1:60014\n'
      '[2026-05-23T18:17:58Z] development machine client started\n'
      '[2026-05-23T18:17:58Z] remote launch failed error=flutter run exited\n',
    );

    final launcher = CockpitDevelopmentSessionDaemonLauncher(
      supervisorStatusReader: (_) async =>
          CockpitDevelopmentSessionSupervisorResponse(
            sessionHandle: _handle(),
            status: _readyStatus(_handle()).copyWith(
              state: CockpitDevelopmentSessionState.failed,
              lastError: 'flutter run exited with code 1',
            ),
          ),
      portForwarder: const _StubPortForwarder(57331),
      flutterVersionReader: () async => '3.39.0',
      flutterExecutableReader: () async => '/opt/flutter/bin/flutter',
      dartExecutableReader: () async =>
          '/opt/flutter/bin/cache/dart-sdk/bin/dart',
      allocatePort: () async => 60014,
      delay: (_) async {},
      spawnSupervisor:
          ({
            required request,
            required flutterVersion,
            required flutterExecutable,
            required dartExecutable,
            required hostPort,
            required supervisorPort,
            required supervisorLogFile,
          }) async {
            return CockpitSpawnedDevelopmentSupervisor(
              baseUri: Uri.parse('http://127.0.0.1:$supervisorPort'),
              stop: () async {},
              logPath: supervisorLog.path,
            );
          },
    );

    await expectLater(
      () => launcher.launch(
        const CockpitLaunchDevelopmentSessionRequest(
          projectDir: '/workspace/examples/cockpit_demo',
          target: 'lib/main.dart',
          platform: 'ios',
          deviceId: '6FD25DED-11E9-4AE9-B4B5-EDF4601981DC',
          sessionPort: 47331,
          launchTimeout: Duration(seconds: 30),
        ),
      ),
      throwsA(
        isA<StateError>()
            .having(
              (error) => error.message,
              'message',
              contains('supervisorLogPath'),
            )
            .having(
              (error) => error.message,
              'message',
              contains('Xcode build failed'),
            )
            .having(
              (error) => error.message,
              'message',
              contains('resolved remote endpoint bind_host=127.0.0.1'),
            )
            .having(
              (error) => error.message,
              'message',
              contains('development machine client started'),
            ),
      ),
    );
  });

  test(
    'daemon launcher fails fast when supervisor reports a permanent startup error',
    () async {
      var spawnCount = 0;
      final launcher = CockpitDevelopmentSessionDaemonLauncher(
        supervisorStatusReader: (_) async =>
            CockpitDevelopmentSessionSupervisorResponse(
              sessionHandle: _handle(),
              status: _readyStatus(_handle()).copyWith(
                state: CockpitDevelopmentSessionState.failed,
                lastError: 'flutter build failed: missing entitlement',
              ),
            ),
        portForwarder: const _StubPortForwarder(57331),
        flutterVersionReader: () async => '3.39.0',
        flutterExecutableReader: () async => '/opt/flutter/bin/flutter',
        dartExecutableReader: () async =>
            '/opt/flutter/bin/cache/dart-sdk/bin/dart',
        allocatePort: () async => 60012,
        delay: (_) async {},
        spawnSupervisor:
            ({
              required request,
              required flutterVersion,
              required flutterExecutable,
              required dartExecutable,
              required hostPort,
              required supervisorPort,
              required supervisorLogFile,
            }) async {
              spawnCount += 1;
              return CockpitSpawnedDevelopmentSupervisor(
                baseUri: Uri.parse('http://127.0.0.1:$supervisorPort'),
                stop: () async {},
              );
            },
      );

      await expectLater(
        () => launcher.launch(
          const CockpitLaunchDevelopmentSessionRequest(
            projectDir: '/workspace/examples/cockpit_demo',
            target: 'lib/main.dart',
            platform: 'macos',
            deviceId: 'macos',
            sessionPort: 47331,
            launchTimeout: Duration(seconds: 30),
          ),
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('missing entitlement'),
          ),
        ),
      );
      expect(spawnCount, 1);
    },
  );

  test(
    'daemon launcher fails fast when supervisor logs a bootstrap failure before control plane readiness',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit-development-supervisor-bootstrap-failure-',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      var spawnCount = 0;
      var delayCalls = 0;
      final launcher = CockpitDevelopmentSessionDaemonLauncher(
        supervisorStatusReader: (_) async {
          throw StateError('connection refused');
        },
        portForwarder: const _StubPortForwarder(57331),
        flutterVersionReader: () async => '3.39.0',
        flutterExecutableReader: () async => '/opt/flutter/bin/flutter',
        dartExecutableReader: () async =>
            '/opt/flutter/bin/cache/dart-sdk/bin/dart',
        supervisorLogDirectoryReader: () => tempDir.path,
        allocatePort: () async => 60016,
        delay: (_) async {
          delayCalls += 1;
        },
        spawnSupervisor:
            ({
              required request,
              required flutterVersion,
              required flutterExecutable,
              required dartExecutable,
              required hostPort,
              required supervisorPort,
              required supervisorLogFile,
            }) async {
              spawnCount += 1;
              await supervisorLogFile.writeAsString(
                '[2026-06-06T04:47:35Z] development supervisor failed '
                'error=Bad state: Unable to resolve a reachable iOS tunnel address for device 00008110-0009341C2EF3801E.\n',
              );
              return CockpitSpawnedDevelopmentSupervisor(
                baseUri: Uri.parse('http://127.0.0.1:$supervisorPort'),
                stop: () async {},
                logPath: supervisorLogFile.path,
              );
            },
      );

      await expectLater(
        () => launcher.launch(
          const CockpitLaunchDevelopmentSessionRequest(
            projectDir: '/workspace/examples/cockpit_demo',
            target: 'cockpit/main.dart',
            platform: 'ios',
            deviceId: '00008110-0009341C2EF3801E',
            sessionPort: 47331,
            launchTimeout: Duration(milliseconds: 80),
          ),
        ),
        throwsA(
          isA<StateError>()
              .having(
                (error) => error.message,
                'message',
                contains('Development supervisor failed before readiness'),
              )
              .having(
                (error) => error.message,
                'message',
                contains('Unable to resolve a reachable iOS tunnel address'),
              )
              .having(
                (error) => error.message,
                'message',
                isNot(contains('did not become ready before timeout')),
              ),
        ),
      );
      expect(spawnCount, 1);
      expect(delayCalls, lessThanOrEqualTo(1));
    },
  );

  test(
    'daemon launcher reports the last supervisor state and log tail when startup times out',
    () async {
      final stuckHandle = _handle().copyWith(
        supervisorBaseUrl: 'http://127.0.0.1:60015',
      );
      final stuckStatus = _readyStatus(stuckHandle).copyWith(
        state: CockpitDevelopmentSessionState.starting,
        appReachable: false,
        remoteSessionReachable: false,
        lastError: null,
      );

      final launcher = CockpitDevelopmentSessionDaemonLauncher(
        supervisorStatusReader: (_) async =>
            CockpitDevelopmentSessionSupervisorResponse(
              sessionHandle: stuckHandle,
              status: stuckStatus,
            ),
        portForwarder: const _StubPortForwarder(57331),
        flutterVersionReader: () async => '3.39.0',
        flutterExecutableReader: () async => '/opt/flutter/bin/flutter',
        dartExecutableReader: () async =>
            '/opt/flutter/bin/cache/dart-sdk/bin/dart',
        allocatePort: () async => 60015,
        delay: (_) => Future<void>.delayed(const Duration(milliseconds: 10)),
        spawnSupervisor:
            ({
              required request,
              required flutterVersion,
              required flutterExecutable,
              required dartExecutable,
              required hostPort,
              required supervisorPort,
              required supervisorLogFile,
            }) async {
              await supervisorLogFile.writeAsString(
                '[2026-05-24T11:37:24Z] machine progress Running Xcode build...\n',
              );
              return CockpitSpawnedDevelopmentSupervisor(
                baseUri: Uri.parse('http://127.0.0.1:$supervisorPort'),
                stop: () async {},
                logPath: supervisorLogFile.path,
              );
            },
      );

      await expectLater(
        () => launcher.launch(
          const CockpitLaunchDevelopmentSessionRequest(
            projectDir: '/workspace/examples/cockpit_demo',
            target: 'cockpit/main.dart',
            platform: 'ios',
            deviceId: '6FD25DED-11E9-4AE9-B4B5-EDF4601981DC',
            sessionPort: 47331,
            launchTimeout: Duration(milliseconds: 60),
          ),
        ),
        throwsA(
          isA<StateError>()
              .having(
                (error) => error.message,
                'message',
                contains('last supervisor status state=starting'),
              )
              .having(
                (error) => error.message,
                'message',
                contains('appReachable=false'),
              )
              .having(
                (error) => error.message,
                'message',
                contains('Running Xcode build'),
              ),
        ),
      );
    },
  );

  test(
    'daemon launcher does not let an old transient connection error hide the last supervisor state',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit-development-supervisor-transient-',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final stuckHandle = _handle().copyWith(
        supervisorBaseUrl: 'http://127.0.0.1:60019',
      );
      final stuckStatus = _readyStatus(stuckHandle).copyWith(
        state: CockpitDevelopmentSessionState.starting,
        appReachable: false,
        remoteSessionReachable: false,
      );
      var statusReadCount = 0;

      final launcher = CockpitDevelopmentSessionDaemonLauncher(
        supervisorStatusReader: (_) async {
          statusReadCount += 1;
          if (statusReadCount == 1) {
            throw SocketException(
              'Connection refused',
              address: InternetAddress.loopbackIPv4,
              port: 38624,
            );
          }
          return CockpitDevelopmentSessionSupervisorResponse(
            sessionHandle: stuckHandle,
            status: stuckStatus,
          );
        },
        portForwarder: const _StubPortForwarder(57331),
        flutterVersionReader: () async => '3.39.0',
        flutterExecutableReader: () async => '/opt/flutter/bin/flutter',
        dartExecutableReader: () async =>
            '/opt/flutter/bin/cache/dart-sdk/bin/dart',
        supervisorLogDirectoryReader: () => tempDir.path,
        allocatePort: () async => 60019,
        delay: (_) => Future<void>.delayed(const Duration(milliseconds: 10)),
        spawnSupervisor:
            ({
              required request,
              required flutterVersion,
              required flutterExecutable,
              required dartExecutable,
              required hostPort,
              required supervisorPort,
              required supervisorLogFile,
            }) async {
              await supervisorLogFile.writeAsString(
                '[2026-06-19T06:15:37Z] machine event app.started\n'
                '[2026-06-19T06:15:38Z] remote_status_probe base_url=http://127.0.0.1:58431 failed=connection refused\n',
              );
              return CockpitSpawnedDevelopmentSupervisor(
                baseUri: Uri.parse('http://127.0.0.1:$supervisorPort'),
                stop: () async {},
                logPath: supervisorLogFile.path,
              );
            },
      );

      await expectLater(
        () => launcher.launch(
          const CockpitLaunchDevelopmentSessionRequest(
            projectDir: '/workspace/examples/cockpit_demo',
            target: 'cockpit/main.dart',
            platform: 'android',
            deviceId: 'emulator-5554',
            sessionPort: 58431,
            launchTimeout: Duration(milliseconds: 80),
          ),
        ),
        throwsA(
          isA<StateError>()
              .having(
                (error) => error.message,
                'message',
                contains('last supervisor status state=starting'),
              )
              .having(
                (error) => error.message,
                'message',
                contains('remote_status_probe base_url=http://127.0.0.1:58431'),
              )
              .having(
                (error) => error.message,
                'message',
                isNot(contains('port = 38624')),
              ),
        ),
      );
    },
  );

  test('daemon launcher rehydrates fallback-coded supervisor failures', () async {
    final launcher = CockpitDevelopmentSessionDaemonLauncher(
      supervisorStatusReader: (_) async =>
          CockpitDevelopmentSessionSupervisorResponse(
            sessionHandle: _handle(),
            status: _readyStatus(_handle()).copyWith(
              state: CockpitDevelopmentSessionState.failed,
              lastError:
                  '[iosPhysicalRemoteSessionReadyButDevelopmentAttachFailed] The remote session is ready, automation fallback is safe.',
            ),
          ),
      portForwarder: const _StubPortForwarder(57331),
      flutterVersionReader: () async => '3.39.0',
      flutterExecutableReader: () async => '/opt/flutter/bin/flutter',
      dartExecutableReader: () async =>
          '/opt/flutter/bin/cache/dart-sdk/bin/dart',
      allocatePort: () async => 60013,
      delay: (_) async {},
      spawnSupervisor:
          ({
            required request,
            required flutterVersion,
            required flutterExecutable,
            required dartExecutable,
            required hostPort,
            required supervisorPort,
            required supervisorLogFile,
          }) async {
            return CockpitSpawnedDevelopmentSupervisor(
              baseUri: Uri.parse('http://127.0.0.1:$supervisorPort'),
              stop: () async {},
            );
          },
    );

    await expectLater(
      () => launcher.launch(
        const CockpitLaunchDevelopmentSessionRequest(
          projectDir: '/workspace/examples/cockpit_demo',
          target: 'lib/main.dart',
          platform: 'ios',
          deviceId: '00008110-0009341C2EF3801E',
          sessionPort: 47331,
          launchTimeout: Duration(seconds: 30),
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
              'remoteSessionHandle.baseUrl',
              _handle().remoteSessionHandle?.baseUrl,
            ),
      ),
    );
  });

  test(
    'daemon launcher uses direct host port for macos without Android forwarding',
    () async {
      final readyHandle = CockpitDevelopmentSessionHandle(
        developmentSessionId: 'dev-session-macos',
        platform: 'macos',
        deviceId: 'macos',
        projectDir: '/workspace/examples/cockpit_demo',
        target: 'cockpit/main.dart',
        appId: 'dev.cockpit.cockpitDemo',
        appBaseUrl: 'http://127.0.0.1:47331',
        supervisorBaseUrl: 'http://127.0.0.1:60003',
        launchedAt: DateTime.utc(2026, 3, 24, 0, 0),
        reloadGeneration: 0,
        remoteSessionHandle: CockpitRemoteSessionHandle(
          platform: 'macos',
          deviceId: 'macos',
          projectDir: '/workspace/examples/cockpit_demo',
          target: 'cockpit/main.dart',
          appId: 'dev.cockpit.cockpitDemo',
          host: '127.0.0.1',
          hostPort: 47331,
          devicePort: 47331,
          baseUrl: 'http://127.0.0.1:47331',
          launchedAt: DateTime.utc(2026, 3, 24, 0, 0),
        ),
      );
      final readyStatus = CockpitDevelopmentSessionStatus(
        developmentSessionId: readyHandle.developmentSessionId,
        state: CockpitDevelopmentSessionState.ready,
        appReachable: true,
        remoteSessionReachable: true,
        reloadGeneration: readyHandle.reloadGeneration,
        lastStatusAt: DateTime.utc(2026, 3, 24, 0, 1),
      );

      var capturedHostPort = -1;
      var capturedPlatform = '';
      final launcher = CockpitDevelopmentSessionDaemonLauncher(
        supervisorStatusReader: (baseUri) async =>
            CockpitDevelopmentSessionSupervisorResponse(
              sessionHandle: readyHandle,
              status: readyStatus,
            ),
        portForwarder: const _ThrowingPortForwarder(),
        flutterVersionReader: () async => '3.39.0',
        flutterExecutableReader: () async => '/opt/flutter/bin/flutter',
        dartExecutableReader: () async =>
            '/opt/flutter/bin/cache/dart-sdk/bin/dart',
        allocatePort: () async => 60003,
        delay: (_) async {},
        spawnSupervisor:
            ({
              required request,
              required flutterVersion,
              required flutterExecutable,
              required dartExecutable,
              required hostPort,
              required supervisorPort,
              required supervisorLogFile,
            }) async {
              capturedHostPort = hostPort;
              capturedPlatform = request.platform;
              return CockpitSpawnedDevelopmentSupervisor(
                baseUri: Uri.parse('http://127.0.0.1:$supervisorPort'),
                stop: () async {},
              );
            },
      );

      final result = await launcher.launch(
        const CockpitLaunchDevelopmentSessionRequest(
          projectDir: '/workspace/examples/cockpit_demo',
          target: 'cockpit/main.dart',
          platform: 'macos',
          deviceId: 'macos',
          sessionPort: 47331,
          launchTimeout: Duration(seconds: 5),
        ),
      );

      expect(capturedPlatform, 'macos');
      expect(capturedHostPort, 47331);
      expect(result.sessionHandle.platform, 'macos');
      expect(result.status.state, CockpitDevelopmentSessionState.ready);
    },
  );

  test(
    'daemon launcher uses direct host port for windows without Android forwarding',
    () async {
      final readyHandle = CockpitDevelopmentSessionHandle(
        developmentSessionId: 'dev-session-windows',
        platform: 'windows',
        deviceId: 'windows',
        projectDir: '/workspace/examples/cockpit_demo',
        target: 'cockpit/main.dart',
        appId: 'cockpit_demo',
        appBaseUrl: 'http://127.0.0.1:47331',
        supervisorBaseUrl: 'http://127.0.0.1:60004',
        launchedAt: DateTime.utc(2026, 3, 24, 0, 0),
        reloadGeneration: 0,
        remoteSessionHandle: CockpitRemoteSessionHandle(
          platform: 'windows',
          deviceId: 'windows',
          projectDir: '/workspace/examples/cockpit_demo',
          target: 'cockpit/main.dart',
          appId: 'cockpit_demo',
          host: '127.0.0.1',
          hostPort: 47331,
          devicePort: 47331,
          baseUrl: 'http://127.0.0.1:47331',
          launchedAt: DateTime.utc(2026, 3, 24, 0, 0),
        ),
      );
      final readyStatus = CockpitDevelopmentSessionStatus(
        developmentSessionId: readyHandle.developmentSessionId,
        state: CockpitDevelopmentSessionState.ready,
        appReachable: true,
        remoteSessionReachable: true,
        reloadGeneration: readyHandle.reloadGeneration,
        lastStatusAt: DateTime.utc(2026, 3, 24, 0, 1),
      );

      var capturedHostPort = -1;
      var capturedPlatform = '';
      final launcher = CockpitDevelopmentSessionDaemonLauncher(
        supervisorStatusReader: (baseUri) async =>
            CockpitDevelopmentSessionSupervisorResponse(
              sessionHandle: readyHandle,
              status: readyStatus,
            ),
        portForwarder: const _ThrowingPortForwarder(),
        flutterVersionReader: () async => '3.39.0',
        flutterExecutableReader: () async => '/opt/flutter/bin/flutter',
        dartExecutableReader: () async =>
            '/opt/flutter/bin/cache/dart-sdk/bin/dart',
        allocatePort: () async => 60004,
        delay: (_) async {},
        spawnSupervisor:
            ({
              required request,
              required flutterVersion,
              required flutterExecutable,
              required dartExecutable,
              required hostPort,
              required supervisorPort,
              required supervisorLogFile,
            }) async {
              capturedHostPort = hostPort;
              capturedPlatform = request.platform;
              return CockpitSpawnedDevelopmentSupervisor(
                baseUri: Uri.parse('http://127.0.0.1:$supervisorPort'),
                stop: () async {},
              );
            },
      );

      final result = await launcher.launch(
        const CockpitLaunchDevelopmentSessionRequest(
          projectDir: '/workspace/examples/cockpit_demo',
          target: 'cockpit/main.dart',
          platform: 'windows',
          deviceId: 'windows',
          sessionPort: 47331,
          launchTimeout: Duration(seconds: 5),
        ),
      );

      expect(capturedPlatform, 'windows');
      expect(capturedHostPort, 47331);
      expect(result.sessionHandle.platform, 'windows');
      expect(result.status.state, CockpitDevelopmentSessionState.ready);
    },
  );

  test(
    'daemon launcher uses direct host port for linux without Android forwarding',
    () async {
      final readyHandle = CockpitDevelopmentSessionHandle(
        developmentSessionId: 'dev-session-linux',
        platform: 'linux',
        deviceId: 'linux',
        projectDir: '/workspace/examples/cockpit_demo',
        target: 'cockpit/main.dart',
        appId: 'cockpit_demo',
        appBaseUrl: 'http://127.0.0.1:47331',
        supervisorBaseUrl: 'http://127.0.0.1:60005',
        launchedAt: DateTime.utc(2026, 3, 24, 0, 0),
        reloadGeneration: 0,
        remoteSessionHandle: CockpitRemoteSessionHandle(
          platform: 'linux',
          deviceId: 'linux',
          projectDir: '/workspace/examples/cockpit_demo',
          target: 'cockpit/main.dart',
          appId: 'cockpit_demo',
          host: '127.0.0.1',
          hostPort: 47331,
          devicePort: 47331,
          baseUrl: 'http://127.0.0.1:47331',
          launchedAt: DateTime.utc(2026, 3, 24, 0, 0),
        ),
      );
      final readyStatus = CockpitDevelopmentSessionStatus(
        developmentSessionId: readyHandle.developmentSessionId,
        state: CockpitDevelopmentSessionState.ready,
        appReachable: true,
        remoteSessionReachable: true,
        reloadGeneration: readyHandle.reloadGeneration,
        lastStatusAt: DateTime.utc(2026, 3, 24, 0, 1),
      );

      var capturedHostPort = -1;
      var capturedPlatform = '';
      final launcher = CockpitDevelopmentSessionDaemonLauncher(
        supervisorStatusReader: (baseUri) async =>
            CockpitDevelopmentSessionSupervisorResponse(
              sessionHandle: readyHandle,
              status: readyStatus,
            ),
        portForwarder: const _ThrowingPortForwarder(),
        flutterVersionReader: () async => '3.39.0',
        flutterExecutableReader: () async => '/opt/flutter/bin/flutter',
        dartExecutableReader: () async =>
            '/opt/flutter/bin/cache/dart-sdk/bin/dart',
        allocatePort: () async => 60005,
        delay: (_) async {},
        spawnSupervisor:
            ({
              required request,
              required flutterVersion,
              required flutterExecutable,
              required dartExecutable,
              required hostPort,
              required supervisorPort,
              required supervisorLogFile,
            }) async {
              capturedHostPort = hostPort;
              capturedPlatform = request.platform;
              return CockpitSpawnedDevelopmentSupervisor(
                baseUri: Uri.parse('http://127.0.0.1:$supervisorPort'),
                stop: () async {},
              );
            },
      );

      final result = await launcher.launch(
        const CockpitLaunchDevelopmentSessionRequest(
          projectDir: '/workspace/examples/cockpit_demo',
          target: 'cockpit/main.dart',
          platform: 'linux',
          deviceId: 'linux',
          sessionPort: 47331,
          launchTimeout: Duration(seconds: 5),
        ),
      );

      expect(capturedPlatform, 'linux');
      expect(capturedHostPort, 47331);
      expect(result.sessionHandle.platform, 'linux');
      expect(result.status.state, CockpitDevelopmentSessionState.ready);
    },
  );
}

final class _StubPortForwarder extends CockpitAndroidPortForwarder {
  const _StubPortForwarder(this.hostPort);

  final int hostPort;

  @override
  Future<int> ensureForwarded({
    required String deviceId,
    required int preferredHostPort,
    required int devicePort,
  }) async {
    return hostPort;
  }
}

final class _ThrowingPortForwarder extends CockpitAndroidPortForwarder {
  const _ThrowingPortForwarder();

  @override
  Future<int> ensureForwarded({
    required String deviceId,
    required int preferredHostPort,
    required int devicePort,
  }) async {
    throw StateError('macos bootstrap must not request Android forwarding');
  }
}

CockpitDevelopmentSessionHandle _handle({String target = 'lib/main.dart'}) {
  return CockpitDevelopmentSessionHandle(
    developmentSessionId: 'dev-session-1',
    platform: 'android',
    deviceId: 'emulator-5554',
    projectDir: '/workspace/examples/cockpit_demo',
    target: target,
    appId: 'dev.cockpit.cockpit_demo',
    appBaseUrl: 'http://127.0.0.1:57331',
    supervisorBaseUrl: 'http://127.0.0.1:59421',
    launchedAt: DateTime.utc(2026, 3, 23, 0, 0),
    reloadGeneration: 1,
    remoteSessionHandle: CockpitRemoteSessionHandle(
      platform: 'android',
      deviceId: 'emulator-5554',
      projectDir: '/workspace/examples/cockpit_demo',
      target: target,
      appId: 'dev.cockpit.cockpit_demo',
      host: '127.0.0.1',
      hostPort: 57331,
      devicePort: 47331,
      baseUrl: 'http://127.0.0.1:57331',
      launchedAt: DateTime.utc(2026, 3, 23, 0, 0),
    ),
  );
}

CockpitDevelopmentSessionStatus _readyStatus(
  CockpitDevelopmentSessionHandle handle,
) {
  return CockpitDevelopmentSessionStatus(
    developmentSessionId: handle.developmentSessionId,
    state: CockpitDevelopmentSessionState.ready,
    appReachable: true,
    remoteSessionReachable: true,
    reloadGeneration: handle.reloadGeneration,
    lastStatusAt: DateTime.utc(2026, 3, 23, 0, 1),
  );
}

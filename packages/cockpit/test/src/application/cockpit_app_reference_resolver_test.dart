import 'dart:convert';
import 'dart:io';

import 'package:cockpit_protocol/cockpit_protocol.dart';
import 'package:cockpit/src/application/cockpit_app_handle.dart';
import 'package:cockpit/src/application/cockpit_app_reference_resolver.dart';
import 'package:cockpit/src/application/cockpit_session_registry.dart';
import 'package:cockpit/src/development/cockpit_development_session_handle.dart';
import 'package:cockpit/src/development/cockpit_development_session_status.dart';
import 'package:cockpit/src/platform/ios/cockpit_ios_device_connection.dart';
import 'package:cockpit/src/remote/cockpit_android_port_forwarder.dart';
import 'package:cockpit/src/session/cockpit_remote_session_handle.dart';
import 'package:test/test.dart';

void main() {
  test('appId lookup returns the latest development session record', () async {
    final registry = CockpitSessionRegistry(
      now: _clockFrom(<DateTime>[
        DateTime.utc(2026, 5, 10, 10, 0, 0),
        DateTime.utc(2026, 5, 10, 10, 5, 0),
      ]),
    );
    registry.recordDevelopmentSession(
      handle: _developmentHandle(
        developmentSessionId: 'dev-1',
        appBaseUrl: 'http://127.0.0.1:57331',
      ),
      status: _developmentStatus('dev-1'),
    );
    registry.recordDevelopmentSession(
      handle: _developmentHandle(
        developmentSessionId: 'dev-2',
        appBaseUrl: 'http://127.0.0.1:58331',
      ),
      status: _developmentStatus('dev-2'),
    );

    final resolved = await CockpitAppReferenceResolver(
      registry: registry,
    ).resolve(appId: 'dev.example.app');

    expect(resolved.developmentRecord?.handle.developmentSessionId, 'dev-2');
    expect(resolved.baseUri.toString(), 'http://127.0.0.1:58331');
  });

  test('appId lookup returns the latest remote session record', () async {
    final registry = CockpitSessionRegistry(
      now: _clockFrom(<DateTime>[
        DateTime.utc(2026, 5, 10, 10, 0, 0),
        DateTime.utc(2026, 5, 10, 10, 5, 0),
      ]),
    );
    registry.recordRemoteSession(
      handle: _remoteHandle(host: '127.0.0.1', hostPort: 57331),
      status: _remoteStatus(),
      recommendedNextStep: 'ready',
    );
    registry.recordRemoteSession(
      handle: _remoteHandle(host: '127.0.0.1', hostPort: 58331),
      status: _remoteStatus(),
      recommendedNextStep: 'ready',
    );

    final resolved = await CockpitAppReferenceResolver(
      registry: registry,
      portForwarder: CockpitAndroidPortForwarder(
        processRunner: (_, _) async =>
            ProcessResult(0, 0, 'emulator-5554 tcp:58331 tcp:47331\n', ''),
        hostPortAllocator: () async => 58331,
        hostPortAvailabilityChecker: (_) async => true,
      ),
    ).resolve(appId: 'dev.example.app');

    expect(resolved.remoteRecord?.handle.hostPort, 58331);
    expect(resolved.baseUri.toString(), 'http://127.0.0.1:58331');
  });

  test(
    'appId lookup prefers the most recently updated record across development and remote sessions',
    () async {
      final forwardedDevicePorts = <int>[];
      final registry = CockpitSessionRegistry(
        now: _clockFrom(<DateTime>[
          DateTime.utc(2026, 5, 10, 10, 0, 0),
          DateTime.utc(2026, 5, 10, 10, 5, 0),
        ]),
      );
      registry.recordDevelopmentSession(
        handle: _developmentHandle(
          developmentSessionId: 'dev-1',
          appBaseUrl: 'http://127.0.0.1:57331',
          remoteSessionHandle: _remoteHandle(
            host: '127.0.0.1',
            hostPort: 57331,
            devicePort: 47331,
          ),
        ),
        status: _developmentStatus('dev-1'),
      );
      registry.recordRemoteSession(
        handle: _remoteHandle(
          host: '127.0.0.1',
          hostPort: 58331,
          devicePort: 48331,
        ),
        status: _remoteStatus(),
        recommendedNextStep: 'ready',
      );

      final resolved = await CockpitAppReferenceResolver(
        registry: registry,
        portForwarder: CockpitAndroidPortForwarder(
          processRunner: (_, arguments) async {
            if (arguments.contains('--list')) {
              return ProcessResult(0, 0, '', '');
            }
            final devicePortArgument = arguments.last;
            forwardedDevicePorts.add(
              int.parse(devicePortArgument.substring('tcp:'.length)),
            );
            return ProcessResult(0, 0, '', '');
          },
          hostPortAllocator: () async => 58331,
          hostPortAvailabilityChecker: (_) async => true,
        ),
      ).resolve(appId: 'dev.example.app');

      expect(resolved.developmentRecord?.handle.developmentSessionId, 'dev-1');
      expect(resolved.remoteRecord?.handle.hostPort, 58331);
      expect(resolved.baseUri.toString(), 'http://127.0.0.1:58331');
      expect(forwardedDevicePorts, <int>[48331]);
    },
  );

  test(
    'appId with explicit baseUri remains usable without a registry',
    () async {
      final resolved = await CockpitAppReferenceResolver().resolve(
        appId: 'dev.example.app',
        baseUri: Uri.parse('http://127.0.0.1:61331/cockpit'),
      );

      expect(resolved.baseUri.toString(), 'http://127.0.0.1:61331/cockpit');
      expect(resolved.app, isNull);
    },
  );

  test(
    'appId with explicit baseUri preserves registry metadata when available',
    () async {
      final registry = CockpitSessionRegistry();
      registry.recordRemoteSession(
        handle: _remoteHandle(
          host: '127.0.0.1',
          hostPort: 57331,
          devicePort: 47331,
        ),
        status: _remoteStatus(),
        recommendedNextStep: 'ready',
      );

      final resolved = await CockpitAppReferenceResolver(registry: registry)
          .resolve(
            appId: 'dev.example.app',
            baseUri: Uri.parse('http://127.0.0.1:61331/cockpit'),
          );

      expect(resolved.baseUri.toString(), 'http://127.0.0.1:61331/cockpit');
      expect(resolved.app?.appId, 'dev.example.app');
      expect(resolved.app?.baseUrl, 'http://127.0.0.1:61331/cockpit');
      expect(
        resolved.app?.remoteSession?.baseUrl,
        'http://127.0.0.1:61331/cockpit',
      );
      expect(resolved.app?.remoteSession?.devicePort, 47331);
    },
  );

  test(
    'android app handle path refreshes host forwarding from device port',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_app_reference_resolver_android',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final appFile = File('${tempDir.path}/app.json');
      await appFile.writeAsString(
        jsonEncode(
          CockpitAppHandle(
            appId: 'dev.example.app',
            mode: CockpitAppMode.automation,
            platform: 'android',
            deviceId: 'emulator-5554',
            projectDir: '/workspace/app',
            target: 'cockpit/main.dart',
            baseUrl: 'http://127.0.0.1:57331',
            launchedAt: DateTime.utc(2026, 5, 10),
            remoteSession: _remoteHandle(
              deviceId: 'emulator-5554',
              host: '127.0.0.1',
              hostPort: 57331,
              devicePort: 47331,
            ),
          ).toJson(),
        ),
      );

      final resolved = await CockpitAppReferenceResolver(
        portForwarder: CockpitAndroidPortForwarder(
          processRunner: (_, _) async =>
              ProcessResult(0, 0, 'emulator-5554 tcp:61331 tcp:47331\n', ''),
          hostPortAllocator: () async => 61331,
          hostPortAvailabilityChecker: (_) async => false,
        ),
      ).resolve(appHandlePath: appFile.path);

      expect(resolved.baseUri.toString(), 'http://127.0.0.1:61331');
      expect(resolved.app?.baseUrl, 'http://127.0.0.1:61331');
      expect(resolved.app?.remoteSession?.host, '127.0.0.1');
      expect(resolved.app?.remoteSession?.hostPort, 61331);
      expect(resolved.app?.remoteSession?.baseUrl, 'http://127.0.0.1:61331');
      expect(resolved.app?.remoteSession?.devicePort, 47331);
    },
  );

  test('android development app handles refresh nested session URLs', () async {
    final remoteSession = _remoteHandle(
      host: '127.0.0.1',
      hostPort: 57331,
      devicePort: 47331,
    );
    final resolved =
        await CockpitAppReferenceResolver(
          portForwarder: CockpitAndroidPortForwarder(
            processRunner: (_, _) async =>
                ProcessResult(0, 0, 'emulator-5554 tcp:61331 tcp:47331\n', ''),
            hostPortAllocator: () async => 61331,
            hostPortAvailabilityChecker: (_) async => false,
          ),
        ).resolve(
          app: CockpitAppHandle.fromDevelopmentSession(
            _developmentHandle(
              developmentSessionId: 'dev-1',
              appBaseUrl: 'http://127.0.0.1:57331',
              remoteSessionHandle: remoteSession,
            ),
          ),
        );

    expect(resolved.baseUri.toString(), 'http://127.0.0.1:61331');
    expect(resolved.app?.baseUrl, 'http://127.0.0.1:61331');
    expect(
      resolved.app?.developmentSession?.appBaseUrl,
      'http://127.0.0.1:61331',
    );
    expect(
      resolved.app?.developmentSession?.remoteSessionHandle?.baseUrl,
      'http://127.0.0.1:61331',
    );
    expect(resolved.app?.remoteSession?.baseUrl, 'http://127.0.0.1:61331');
  });

  test(
    'explicit baseUri overrides app handle connection while preserving app metadata',
    () async {
      final staleRemoteSession = _remoteHandle(
        host: '127.0.0.1',
        hostPort: 57331,
        devicePort: 47331,
      );
      final resolved = await CockpitAppReferenceResolver().resolve(
        app: CockpitAppHandle.fromDevelopmentSession(
          _developmentHandle(
            developmentSessionId: 'dev-1',
            appBaseUrl: 'http://127.0.0.1:57331',
            remoteSessionHandle: staleRemoteSession,
          ),
        ),
        baseUri: Uri.parse('http://127.0.0.1:61331/cockpit'),
      );

      expect(resolved.baseUri.toString(), 'http://127.0.0.1:61331/cockpit');
      expect(resolved.app?.appId, 'dev.example.app');
      expect(resolved.app?.baseUrl, 'http://127.0.0.1:61331/cockpit');
      expect(
        resolved.app?.developmentSession?.appBaseUrl,
        'http://127.0.0.1:61331/cockpit',
      );
      expect(
        resolved.app?.developmentSession?.remoteSessionHandle?.baseUrl,
        'http://127.0.0.1:61331/cockpit',
      );
      expect(resolved.app?.remoteSession?.host, '127.0.0.1');
      expect(resolved.app?.remoteSession?.hostPort, 61331);
      expect(
        resolved.app?.remoteSession?.baseUrl,
        'http://127.0.0.1:61331/cockpit',
      );
      expect(resolved.app?.remoteSession?.devicePort, 47331);
    },
  );

  test(
    'physical ios app handle path refreshes tunnel ip from device probe',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_app_reference_resolver_ios',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final appFile = File('${tempDir.path}/app.json');
      await appFile.writeAsString(
        jsonEncode(
          CockpitAppHandle(
            appId: 'dev.example.app',
            mode: CockpitAppMode.automation,
            platform: 'ios',
            deviceId: '00008110-001234560E10801E',
            projectDir: '/workspace/app',
            target: 'cockpit/main.dart',
            baseUrl: 'http://[fd00::1]:57331',
            launchedAt: DateTime.utc(2026, 5, 10),
            remoteSession: _remoteHandle(
              platform: 'ios',
              deviceId: '00008110-001234560E10801E',
              host: 'fd00::1',
              hostPort: 57331,
              devicePort: 57331,
            ),
          ).toJson(),
        ),
      );

      final resolved = await CockpitAppReferenceResolver(
        iosDeviceConnectionReader: (_) async =>
            const CockpitIosDeviceConnection(
              isPhysical: true,
              tunnelIpAddress: 'fd00::9',
            ),
      ).resolve(appHandlePath: appFile.path);

      expect(resolved.baseUri.toString(), 'http://[fd00::9]:57331');
      expect(resolved.app?.baseUrl, 'http://[fd00::9]:57331');
      expect(resolved.app?.remoteSession?.host, 'fd00::9');
      expect(resolved.app?.remoteSession?.hostPort, 57331);
      expect(resolved.app?.remoteSession?.baseUrl, 'http://[fd00::9]:57331');
    },
  );

  test(
    'baseUri with physical ios device id refreshes tunnel ip from device probe',
    () async {
      final resolved =
          await CockpitAppReferenceResolver(
            iosDeviceConnectionReader: (deviceId) async {
              expect(deviceId, '00008110-001234560E10801E');
              return const CockpitIosDeviceConnection(
                isPhysical: true,
                tunnelIpAddress: 'fd00::9',
              );
            },
          ).resolve(
            baseUri: Uri.parse('http://127.0.0.1:57331/cockpit'),
            iosDeviceId: '00008110-001234560E10801E',
          );

      expect(resolved.baseUri.toString(), 'http://[fd00::9]:57331/cockpit');
      expect(resolved.app, isNull);
    },
  );
}

DateTime Function() _clockFrom(List<DateTime> instants) {
  var index = 0;
  return () {
    final value = instants[index];
    if (index < instants.length - 1) {
      index += 1;
    }
    return value;
  };
}

CockpitDevelopmentSessionHandle _developmentHandle({
  required String developmentSessionId,
  required String appBaseUrl,
  CockpitRemoteSessionHandle? remoteSessionHandle,
}) {
  return CockpitDevelopmentSessionHandle(
    developmentSessionId: developmentSessionId,
    platform: 'android',
    deviceId: 'emulator-5554',
    projectDir: '/workspace/app',
    target: 'cockpit/main.dart',
    appId: 'dev.example.app',
    appBaseUrl: appBaseUrl,
    supervisorBaseUrl: 'http://127.0.0.1:57332',
    remoteSessionHandle: remoteSessionHandle,
    launchedAt: DateTime.utc(2026, 5, 10),
    reloadGeneration: 0,
  );
}

CockpitDevelopmentSessionStatus _developmentStatus(String id) {
  return CockpitDevelopmentSessionStatus(
    developmentSessionId: id,
    state: CockpitDevelopmentSessionState.ready,
    appReachable: true,
    remoteSessionReachable: true,
    reloadGeneration: 0,
    lastStatusAt: DateTime.utc(2026, 5, 10),
  );
}

CockpitRemoteSessionHandle _remoteHandle({
  String platform = 'android',
  String deviceId = 'emulator-5554',
  required String host,
  required int hostPort,
  int devicePort = 47331,
}) {
  return CockpitRemoteSessionHandle(
    platform: platform,
    deviceId: deviceId,
    projectDir: '/workspace/app',
    target: 'cockpit/main.dart',
    appId: 'dev.example.app',
    host: host,
    hostPort: hostPort,
    devicePort: devicePort,
    baseUrl: Uri(scheme: 'http', host: host, port: hostPort).toString(),
    launchedAt: DateTime.utc(2026, 5, 10),
  );
}

CockpitRemoteSessionStatus _remoteStatus() {
  return CockpitRemoteSessionStatus(
    sessionId: 'session-1',
    platform: 'android',
    transportType: 'remoteHttp',
    currentRouteName: '/home',
    capabilities: CockpitCapabilities(
      platform: 'android',
      transportType: 'remoteHttp',
      supportsInAppControl: true,
      supportsFlutterViewCapture: true,
      supportsNativeScreenCapture: true,
      supportsHostAutomation: false,
    ),
    recordingCapabilities: CockpitRecordingCapabilities(
      supportsNativeRecording: true,
      preferredAcceptanceRecordingKind: CockpitRecordingKind.nativeScreen,
      supportedLayers: <CockpitRecordingLayer>[CockpitRecordingLayer.system],
    ),
    snapshot: CockpitSnapshot(
      routeName: '/home',
      summary: const CockpitSnapshotSummary(
        visibleTargetCount: 0,
        targetsWithCockpitIdCount: 0,
        targetsWithTextCount: 0,
        styleDetailsIncluded: false,
        diagnosticPropertiesIncluded: false,
        ancestorSummariesIncluded: false,
        rebuildSummaryIncluded: false,
        accessibilitySummaryIncluded: false,
      ),
    ),
  );
}

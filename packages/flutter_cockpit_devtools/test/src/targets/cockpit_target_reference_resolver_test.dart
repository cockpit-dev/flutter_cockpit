import 'dart:convert';
import 'dart:io';

import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_app_handle.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_app_reference_resolver.dart';
import 'package:flutter_cockpit_devtools/src/platform/ios/cockpit_ios_device_connection.dart';
import 'package:flutter_cockpit_devtools/src/remote/cockpit_android_port_forwarder.dart';
import 'package:flutter_cockpit_devtools/src/session/cockpit_remote_session_handle.dart';
import 'package:flutter_cockpit_devtools/src/targets/cockpit_target_handle.dart';
import 'package:flutter_cockpit_devtools/src/targets/cockpit_target_reference_resolver.dart';
import 'package:test/test.dart';

void main() {
  test('reads target handle files', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'cockpit_target_reference_resolver',
    );
    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    final targetFile = File('${tempDir.path}/target.json');
    await targetFile.writeAsString(
      jsonEncode(
        CockpitTargetHandle(
          targetId: 'target-1',
          targetKind: CockpitTargetKind.browserPage,
          platform: 'web',
          deviceId: 'chrome',
          projectDir: '/workspace/app',
          target: '/app',
          connection: const CockpitTargetConnection(
            baseUrl: 'http://127.0.0.1:9222',
          ),
          launchedAt: DateTime.utc(2026, 4, 11),
        ).toJson(),
      ),
    );

    final resolved = await CockpitTargetReferenceResolver().resolve(
      targetHandlePath: targetFile.path,
    );

    expect(resolved.target?.targetKind, CockpitTargetKind.browserPage);
    expect(resolved.baseUri.toString(), 'http://127.0.0.1:9222');
  });

  test('projects app handle files into flutter targets', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'cockpit_target_reference_resolver_app',
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
          mode: CockpitAppMode.development,
          platform: 'android',
          deviceId: 'emulator-5554',
          projectDir: '/workspace/app',
          target: 'cockpit/main.dart',
          baseUrl: 'http://127.0.0.1:57331',
          launchedAt: DateTime.utc(2026, 4, 11),
          platformAppId: 'dev.example.platform',
          remoteSession: CockpitRemoteSessionHandle(
            platform: 'android',
            deviceId: 'emulator-5554',
            projectDir: '/workspace/app',
            target: 'cockpit/main.dart',
            appId: 'dev.example.platform',
            host: '127.0.0.1',
            hostPort: 57331,
            devicePort: 47331,
            baseUrl: 'http://127.0.0.1:57331',
            launchedAt: DateTime.utc(2026, 4, 11),
          ),
        ).toJson(),
      ),
    );

    final resolved = await CockpitTargetReferenceResolver(
      appReferenceResolver: CockpitAppReferenceResolver(
        portForwarder: CockpitAndroidPortForwarder(
          processRunner: (_, _) async =>
              ProcessResult(0, 0, 'emulator-5554 tcp:57331 tcp:47331\n', ''),
          hostPortAllocator: () async => 57331,
          hostPortAvailabilityChecker: (_) async => true,
        ),
      ),
    ).resolve(appHandlePath: appFile.path);

    expect(resolved.app?.appId, 'dev.example.app');
    expect(resolved.target?.targetKind, CockpitTargetKind.flutterApp);
    expect(resolved.target?.metadata['appMode'], 'development');
    expect(resolved.baseUri.toString(), 'http://127.0.0.1:57331');
  });

  test(
    'projects android app handle files into refreshed flutter targets',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_target_reference_resolver_android',
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
            remoteSession: CockpitRemoteSessionHandle(
              platform: 'android',
              deviceId: 'emulator-5554',
              projectDir: '/workspace/app',
              target: 'cockpit/main.dart',
              appId: 'dev.example.app',
              host: '127.0.0.1',
              hostPort: 57331,
              devicePort: 47331,
              baseUrl: 'http://127.0.0.1:57331',
              launchedAt: DateTime.utc(2026, 5, 10),
            ),
          ).toJson(),
        ),
      );

      final resolved = await CockpitTargetReferenceResolver(
        appReferenceResolver: CockpitAppReferenceResolver(
          portForwarder: CockpitAndroidPortForwarder(
            processRunner: (_, _) async =>
                ProcessResult(0, 0, 'emulator-5554 tcp:61331 tcp:47331\n', ''),
            hostPortAllocator: () async => 61331,
            hostPortAvailabilityChecker: (_) async => false,
          ),
        ),
      ).resolve(appHandlePath: appFile.path);

      expect(resolved.baseUri.toString(), 'http://127.0.0.1:61331');
      expect(
        resolved.target?.connection.baseUri.toString(),
        'http://127.0.0.1:61331',
      );
    },
  );

  test(
    'projects physical ios app handle files into refreshed flutter targets',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_target_reference_resolver_ios',
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
            remoteSession: CockpitRemoteSessionHandle(
              platform: 'ios',
              deviceId: '00008110-001234560E10801E',
              projectDir: '/workspace/app',
              target: 'cockpit/main.dart',
              appId: 'dev.example.app',
              host: 'fd00::1',
              hostPort: 57331,
              devicePort: 57331,
              baseUrl: 'http://[fd00::1]:57331',
              launchedAt: DateTime.utc(2026, 5, 10),
            ),
          ).toJson(),
        ),
      );

      final resolved = await CockpitTargetReferenceResolver(
        appReferenceResolver: CockpitAppReferenceResolver(
          iosDeviceConnectionReader: (_) async =>
              const CockpitIosDeviceConnection(
                isPhysical: true,
                tunnelIpAddress: 'fd00::9',
              ),
        ),
      ).resolve(appHandlePath: appFile.path);

      expect(resolved.baseUri.toString(), 'http://[fd00::9]:57331');
      expect(
        resolved.target?.connection.baseUri.toString(),
        'http://[fd00::9]:57331',
      );
    },
  );

  test(
    'refreshes android target handle files when remote session metadata exists',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_target_reference_resolver_target_android',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final targetFile = File('${tempDir.path}/target.json');
      await targetFile.writeAsString(
        jsonEncode(
          CockpitTargetHandle(
            targetId: 'dev.example.app',
            targetKind: CockpitTargetKind.flutterApp,
            platform: 'android',
            deviceId: 'emulator-5554',
            projectDir: '/workspace/app',
            target: 'cockpit/main.dart',
            connection: const CockpitTargetConnection(
              baseUrl: 'http://127.0.0.1:57331',
            ),
            launchedAt: DateTime.utc(2026, 5, 10),
            metadata: const <String, Object?>{
              'appId': 'dev.example.app',
              'appMode': 'automation',
              'remoteSession': <String, Object?>{
                'platform': 'android',
                'deviceId': 'emulator-5554',
                'projectDir': '/workspace/app',
                'target': 'cockpit/main.dart',
                'appId': 'dev.example.app',
                'host': '127.0.0.1',
                'hostPort': 57331,
                'devicePort': 47331,
                'baseUrl': 'http://127.0.0.1:57331',
                'launchedAt': '2026-05-10T00:00:00.000Z',
              },
            },
          ).toJson(),
        ),
      );

      final resolved = await CockpitTargetReferenceResolver(
        appReferenceResolver: CockpitAppReferenceResolver(
          portForwarder: CockpitAndroidPortForwarder(
            processRunner: (_, _) async =>
                ProcessResult(0, 0, 'emulator-5554 tcp:61331 tcp:47331\n', ''),
            hostPortAllocator: () async => 61331,
            hostPortAvailabilityChecker: (_) async => false,
          ),
        ),
      ).resolve(targetHandlePath: targetFile.path);

      expect(resolved.baseUri.toString(), 'http://127.0.0.1:61331');
      expect(
        resolved.target?.connection.baseUri.toString(),
        'http://127.0.0.1:61331',
      );
      final remoteSession =
          resolved.target?.metadata['remoteSession'] as Map<String, Object?>?;
      expect(remoteSession?['hostPort'], 61331);
      expect(remoteSession?['baseUrl'], 'http://127.0.0.1:61331');
      expect(remoteSession?['devicePort'], 47331);
    },
  );

  test(
    'explicit baseUri overrides target handle connection while preserving target metadata',
    () async {
      final target = CockpitTargetHandle(
        targetId: 'dev.example.app',
        targetKind: CockpitTargetKind.flutterApp,
        platform: 'android',
        deviceId: 'emulator-5554',
        projectDir: '/workspace/app',
        target: 'cockpit/main.dart',
        connection: const CockpitTargetConnection(
          baseUrl: 'http://127.0.0.1:57331',
        ),
        launchedAt: DateTime.utc(2026, 5, 10),
        metadata: const <String, Object?>{
          'appId': 'dev.example.app',
          'appMode': 'automation',
          'supportsHotReload': false,
          'platformAppId': 'dev.example.platform',
          'processId': 4242,
          'remoteSession': <String, Object?>{
            'platform': 'android',
            'deviceId': 'emulator-5554',
            'projectDir': '/workspace/app',
            'target': 'cockpit/main.dart',
            'appId': 'dev.example.app',
            'platformAppId': 'dev.example.platform',
            'processId': 4242,
            'host': '127.0.0.1',
            'hostPort': 57331,
            'devicePort': 47331,
            'baseUrl': 'http://127.0.0.1:57331',
            'launchedAt': '2026-05-10T00:00:00.000Z',
          },
        },
      );

      final resolved =
          await CockpitTargetReferenceResolver(
            appReferenceResolver: CockpitAppReferenceResolver(
              portForwarder: _FailingAndroidPortForwarder(),
            ),
          ).resolve(
            target: target,
            baseUri: Uri.parse('http://127.0.0.1:61331/cockpit'),
          );

      expect(resolved.baseUri.toString(), 'http://127.0.0.1:61331/cockpit');
      expect(
        resolved.target?.connection.baseUri.toString(),
        'http://127.0.0.1:61331/cockpit',
      );
      expect(resolved.target?.metadata['appId'], 'dev.example.app');
      expect(
        resolved.target?.metadata['platformAppId'],
        'dev.example.platform',
      );
      expect(resolved.target?.metadata['processId'], 4242);
      final remoteSession =
          resolved.target?.metadata['remoteSession'] as Map<String, Object?>?;
      expect(remoteSession?['hostPort'], 61331);
      expect(remoteSession?['baseUrl'], 'http://127.0.0.1:61331/cockpit');
      expect(remoteSession?['devicePort'], 47331);
    },
  );
}

final class _FailingAndroidPortForwarder extends CockpitAndroidPortForwarder {
  @override
  Future<int> ensureForwarded({
    required String deviceId,
    required int preferredHostPort,
    required int devicePort,
  }) {
    throw StateError('explicit baseUri must not refresh adb forwarding');
  }
}

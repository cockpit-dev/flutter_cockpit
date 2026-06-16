import 'dart:convert';
import 'dart:io';

import 'package:cockpit/src/platform/ios/cockpit_ios_device_connection.dart';
import 'package:cockpit/src/remote/cockpit_android_port_forwarder.dart';
import 'package:cockpit/src/session/cockpit_remote_session_handle.dart';
import 'package:cockpit/src/application/cockpit_session_reference_resolver.dart';
import 'package:test/test.dart';

void main() {
  test('reads lower camel case remote session handles', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'cockpit_session_reference_resolver',
    );
    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    final handleFile = File('${tempDir.path}/session.json');
    await handleFile.writeAsString(
      jsonEncode(<String, Object?>{
        'platform': 'android',
        'deviceId': 'emulator-5554',
        'projectDir': '/workspace/examples/cockpit_demo',
        'target': 'cockpit/main.dart',
        'appId': 'dev.cockpit.cockpit_demo',
        'host': '127.0.0.1',
        'hostPort': 58421,
        'devicePort': 47331,
        'baseUrl': 'http://127.0.0.1:58421',
        'launchedAt': DateTime.utc(2026, 3, 23).toIso8601String(),
      }),
    );

    final resolved = await CockpitSessionReferenceResolver().readSessionHandle(
      handleFile.path,
    );

    expect(resolved.deviceId, 'emulator-5554');
    expect(resolved.baseUrl, 'http://127.0.0.1:58421');
  });

  test('rejects legacy snake case remote session handles', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'cockpit_session_reference_resolver_legacy',
    );
    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    final handleFile = File('${tempDir.path}/session.json');
    await handleFile.writeAsString(
      jsonEncode(<String, Object?>{
        'platform': 'android',
        'device_id': 'emulator-5554',
        'project_dir': '/workspace/examples/cockpit_demo',
        'target': 'cockpit/main.dart',
        'app_id': 'dev.cockpit.cockpit_demo',
        'host': '127.0.0.1',
        'host_port': 58421,
        'device_port': 47331,
        'base_url': 'http://127.0.0.1:58421',
        'launched_at': DateTime.utc(2026, 3, 23).toIso8601String(),
      }),
    );

    expect(
      () =>
          CockpitSessionReferenceResolver().readSessionHandle(handleFile.path),
      throwsA(isA<TypeError>()),
    );
  });

  test(
    'refreshes android forwarding when resolving a session handle',
    () async {
      final resolver = CockpitSessionReferenceResolver(
        portForwarder: CockpitAndroidPortForwarder(
          processRunner: (_, _) async =>
              ProcessResult(0, 0, 'emulator-5554 tcp:61331 tcp:47331\n', ''),
          hostPortAllocator: () async => 61331,
          hostPortAvailabilityChecker: (_) async => false,
        ),
      );

      final resolved = await resolver.resolve(
        sessionHandle: CockpitRemoteSessionHandle(
          platform: 'android',
          deviceId: 'emulator-5554',
          projectDir: '/workspace/examples/cockpit_demo',
          target: 'cockpit/main.dart',
          appId: 'dev.cockpit.cockpit_demo',
          host: '127.0.0.1',
          hostPort: 58421,
          devicePort: 47331,
          baseUrl: 'http://127.0.0.1:58421',
          launchedAt: DateTime.utc(2026, 3, 23),
        ),
      );

      expect(resolved.baseUri.toString(), 'http://127.0.0.1:61331');
      expect(resolved.sessionHandle?.host, '127.0.0.1');
      expect(resolved.sessionHandle?.hostPort, 61331);
      expect(resolved.sessionHandle?.baseUrl, 'http://127.0.0.1:61331');
      expect(resolved.sessionHandle?.devicePort, 47331);
    },
  );

  test(
    'explicit baseUri is authoritative when paired with a session handle',
    () async {
      var processRunnerCalled = false;
      final resolver = CockpitSessionReferenceResolver(
        portForwarder: CockpitAndroidPortForwarder(
          processRunner: (_, _) async {
            processRunnerCalled = true;
            return ProcessResult(0, 0, '', '');
          },
        ),
      );

      final resolved = await resolver.resolve(
        baseUri: Uri.parse('http://127.0.0.1:61331/cockpit'),
        sessionHandle: CockpitRemoteSessionHandle(
          platform: 'android',
          deviceId: 'emulator-5554',
          projectDir: '/workspace/examples/cockpit_demo',
          target: 'cockpit/main.dart',
          appId: 'dev.cockpit.cockpit_demo',
          host: '127.0.0.1',
          hostPort: 58421,
          devicePort: 47331,
          baseUrl: 'http://127.0.0.1:58421',
          launchedAt: DateTime.utc(2026, 3, 23),
        ),
      );

      expect(processRunnerCalled, isFalse);
      expect(resolved.baseUri.toString(), 'http://127.0.0.1:61331/cockpit');
      expect(resolved.sessionHandle?.hostPort, 61331);
      expect(resolved.sessionHandle?.baseUrl, 'http://127.0.0.1:61331/cockpit');
      expect(resolved.sessionHandle?.devicePort, 47331);
    },
  );

  test(
    'baseUri with android device id resolves to local forwarded port',
    () async {
      final resolver = CockpitSessionReferenceResolver(
        portForwarder: CockpitAndroidPortForwarder(
          processRunner: (_, _) async =>
              ProcessResult(0, 0, 'emulator-5554 tcp:61331 tcp:47331\n', ''),
          hostPortAllocator: () async => 61331,
          hostPortAvailabilityChecker: (_) async => true,
        ),
      );

      final resolved = await resolver.resolve(
        baseUri: Uri.parse('http://10.0.2.2:47331/cockpit'),
        androidDeviceId: 'emulator-5554',
      );

      expect(resolved.baseUri.host, '127.0.0.1');
      expect(resolved.baseUri.port, 61331);
      expect(resolved.baseUri.path, '/cockpit');
    },
  );

  test('baseUri with physical ios device id resolves to tunnel ip', () async {
    final resolver = CockpitSessionReferenceResolver(
      iosDeviceConnectionReader: (deviceId) async {
        expect(deviceId, '00008110-001234560E10801E');
        return const CockpitIosDeviceConnection(
          isPhysical: true,
          tunnelIpAddress: 'fd00::9',
        );
      },
    );

    final resolved = await resolver.resolve(
      baseUri: Uri.parse('http://127.0.0.1:57331/cockpit'),
      iosDeviceId: '00008110-001234560E10801E',
    );

    expect(resolved.baseUri.toString(), 'http://[fd00::9]:57331/cockpit');
    expect(resolved.sessionHandle, isNull);
  });
}

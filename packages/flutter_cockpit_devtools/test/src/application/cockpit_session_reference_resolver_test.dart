import 'dart:convert';
import 'dart:io';

import 'package:flutter_cockpit_devtools/src/remote/cockpit_android_port_forwarder.dart';
import 'package:flutter_cockpit_devtools/src/session/cockpit_remote_session_handle.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_session_reference_resolver.dart';
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
      () => CockpitSessionReferenceResolver().readSessionHandle(
        handleFile.path,
      ),
      throwsA(isA<TypeError>()),
    );
  });

  test('refreshes android forwarding when resolving a session handle',
      () async {
    final resolver = CockpitSessionReferenceResolver(
      portForwarder: CockpitAndroidPortForwarder(
        processRunner: (_, __) async => ProcessResult(
          0,
          0,
          'emulator-5554 tcp:61331 tcp:47331\n',
          '',
        ),
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
  });
}

import 'package:flutter_cockpit_devtools/src/application/cockpit_app_handle.dart';
import 'package:flutter_cockpit_devtools/src/development/cockpit_development_session_handle.dart';
import 'package:flutter_cockpit_devtools/src/session/cockpit_remote_session_handle.dart';
import 'package:test/test.dart';

void main() {
  test('toJson emits lower camel case public keys', () {
    final handle =
        CockpitAppHandle.fromDevelopmentSession(_developmentHandle());

    expect(handle.toJson(), <String, Object?>{
      'appId': 'dev.cockpit.cockpit_demo',
      'mode': 'development',
      'platform': 'android',
      'deviceId': 'emulator-5554',
      'projectDir': '/workspace/examples/cockpit_demo',
      'target': 'cockpit/main.dart',
      'baseUrl': 'http://127.0.0.1:57331',
      'launchedAt': DateTime.utc(2026, 3, 23).toIso8601String(),
      'platformAppId': 'dev.cockpit.cockpit_demo',
      'supportsHotReload': true,
      'developmentSessionId': 'dev-session-1',
      'supervisorBaseUrl': 'http://127.0.0.1:59421',
      'reloadGeneration': 2,
      'vmServiceUri': 'ws://127.0.0.1:8181/ws',
      'lastReloadAt': DateTime.utc(2026, 3, 23, 0, 5).toIso8601String(),
    });
  });

  test('toJson omits nullable fields when they are absent', () {
    final handle = CockpitAppHandle.fromRemoteSession(
      _developmentHandle().remoteSessionHandle!,
    );

    expect(handle.toJson().containsKey('supervisorLogPath'), isFalse);
    expect(handle.toJson().containsKey('developmentSessionId'), isFalse);
    expect(handle.toJson().containsKey('supervisorBaseUrl'), isFalse);
    expect(handle.toJson().containsKey('vmServiceUri'), isFalse);
    expect(handle.toJson().containsKey('lastReloadAt'), isFalse);
  });

  test('fromJson reads the canonical lower camel case payload', () {
    final handle = CockpitAppHandle.fromJson(<String, Object?>{
      'appId': 'dev.cockpit.cockpit_demo',
      'mode': 'development',
      'platform': 'android',
      'deviceId': 'emulator-5554',
      'projectDir': '/workspace/examples/cockpit_demo',
      'target': 'cockpit/main.dart',
      'baseUrl': 'http://127.0.0.1:57331',
      'launchedAt': DateTime.utc(2026, 3, 23).toIso8601String(),
      'platformAppId': 'remote.dev.cockpit.cockpit_demo',
      'developmentSessionId': 'dev-session-1',
      'supervisorBaseUrl': 'http://127.0.0.1:59421',
      'reloadGeneration': 2,
      'vmServiceUri': 'ws://127.0.0.1:8181/ws',
      'lastReloadAt': DateTime.utc(2026, 3, 23, 0, 5).toIso8601String(),
    });

    expect(handle.appId, 'dev.cockpit.cockpit_demo');
    expect(handle.deviceId, 'emulator-5554');
    expect(handle.projectDir, '/workspace/examples/cockpit_demo');
    expect(handle.platformAppId, 'remote.dev.cockpit.cockpit_demo');
    expect(handle.supportsHotReload, isTrue);
    expect(handle.developmentSession?.reloadGeneration, 2);
    expect(
      handle.developmentSession?.vmServiceUri?.toString(),
      'ws://127.0.0.1:8181/ws',
    );
  });

  test('fromJson rejects legacy snake case payloads', () {
    expect(
      () => CockpitAppHandle.fromJson(<String, Object?>{
        'app_id': 'dev.cockpit.cockpit_demo',
        'mode': 'development',
        'platform': 'android',
        'device_id': 'emulator-5554',
        'project_dir': '/workspace/examples/cockpit_demo',
        'target': 'cockpit/main.dart',
        'base_url': 'http://127.0.0.1:57331',
        'launched_at': DateTime.utc(2026, 3, 23).toIso8601String(),
      }),
      throwsA(isA<TypeError>()),
    );
  });
}

CockpitDevelopmentSessionHandle _developmentHandle() {
  return CockpitDevelopmentSessionHandle(
    developmentSessionId: 'dev-session-1',
    platform: 'android',
    deviceId: 'emulator-5554',
    projectDir: '/workspace/examples/cockpit_demo',
    target: 'cockpit/main.dart',
    appId: 'dev.cockpit.cockpit_demo',
    appBaseUrl: 'http://127.0.0.1:57331',
    supervisorBaseUrl: 'http://127.0.0.1:59421',
    launchedAt: DateTime.utc(2026, 3, 23),
    reloadGeneration: 2,
    vmServiceUri: Uri.parse('ws://127.0.0.1:8181/ws'),
    lastReloadAt: DateTime.utc(2026, 3, 23, 0, 5),
    remoteSessionHandle: CockpitRemoteSessionHandle(
      platform: 'android',
      deviceId: 'emulator-5554',
      projectDir: '/workspace/examples/cockpit_demo',
      target: 'cockpit/main.dart',
      appId: 'dev.cockpit.cockpit_demo',
      host: '127.0.0.1',
      hostPort: 57331,
      devicePort: 57331,
      baseUrl: 'http://127.0.0.1:57331',
      launchedAt: DateTime.utc(2026, 3, 23),
    ),
  );
}

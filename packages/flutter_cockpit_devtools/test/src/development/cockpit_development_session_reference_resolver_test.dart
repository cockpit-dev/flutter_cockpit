import 'dart:convert';
import 'dart:io';

import 'package:flutter_cockpit_devtools/src/development/cockpit_development_session_reference_resolver.dart';
import 'package:test/test.dart';

void main() {
  test('reads both legacy camelCase and snake_case development handles',
      () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'cockpit_development_session_reference_resolver',
    );
    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    final legacyFile = File('${tempDir.path}/legacy.json');
    await legacyFile.writeAsString(
      jsonEncode(<String, Object?>{
        'developmentSessionId': 'dev-session-1',
        'platform': 'android',
        'deviceId': 'emulator-5554',
        'projectDir': '/workspace/examples/cockpit_demo',
        'target': 'cockpit/main.dart',
        'appId': 'dev.cockpit.cockpit_demo',
        'appBaseUrl': 'http://127.0.0.1:57331',
        'supervisorBaseUrl': 'http://127.0.0.1:59331',
        'launchedAt': DateTime.utc(2026, 3, 23).toIso8601String(),
        'reloadGeneration': 1,
      }),
    );

    final snakeCaseFile = File('${tempDir.path}/snake_case.json');
    await snakeCaseFile.writeAsString(
      jsonEncode(<String, Object?>{
        'development_session_id': 'dev-session-2',
        'platform': 'android',
        'device_id': 'emulator-5554',
        'project_dir': '/workspace/examples/cockpit_demo',
        'target': 'cockpit/main.dart',
        'app_id': 'dev.cockpit.cockpit_demo',
        'app_base_url': 'http://127.0.0.1:57332',
        'supervisor_base_url': 'http://127.0.0.1:59332',
        'launched_at': DateTime.utc(2026, 3, 23).toIso8601String(),
        'reload_generation': 2,
      }),
    );

    const resolver = CockpitDevelopmentSessionReferenceResolver();
    final legacy = await resolver.readSessionHandle(legacyFile.path);
    final snakeCase = await resolver.readSessionHandle(snakeCaseFile.path);

    expect(legacy.developmentSessionId, 'dev-session-1');
    expect(legacy.reloadGeneration, 1);
    expect(snakeCase.developmentSessionId, 'dev-session-2');
    expect(snakeCase.reloadGeneration, 2);
  });
}

import 'dart:convert';
import 'dart:io';

import 'package:flutter_cockpit_devtools/src/application/cockpit_session_reference_resolver.dart';
import 'package:test/test.dart';

void main() {
  test('reads snake_case remote session handles', () async {
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

    final resolved = await CockpitSessionReferenceResolver().readSessionHandle(
      handleFile.path,
    );

    expect(resolved.deviceId, 'emulator-5554');
    expect(resolved.baseUrl, 'http://127.0.0.1:58421');
  });
}

import 'dart:convert';
import 'dart:io';

import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_app_handle.dart';
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
        ).toJson(),
      ),
    );

    final resolved = await CockpitTargetReferenceResolver().resolve(
      appHandlePath: appFile.path,
    );

    expect(resolved.app?.appId, 'dev.example.app');
    expect(resolved.target?.targetKind, CockpitTargetKind.flutterApp);
    expect(resolved.target?.metadata['appMode'], 'development');
    expect(resolved.baseUri.toString(), 'http://127.0.0.1:57331');
  });
}

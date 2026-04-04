import 'dart:convert';
import 'dart:io';

import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_collect_remote_snapshot_service.dart';
import 'package:flutter_cockpit_devtools/src/session/cockpit_remote_session_handle.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test(
    'collect service resolves a persisted session handle and preserves forensic artifact preferences',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_collect_remote_snapshot_service',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final handle = CockpitRemoteSessionHandle(
        platform: 'ios',
        deviceId: 'simulator',
        projectDir: '/workspace/examples/cockpit_demo',
        target: 'lib/main.dart',
        appId: 'dev.cockpit.cockpit_demo',
        host: '127.0.0.1',
        hostPort: 58421,
        devicePort: 47331,
        baseUrl: 'http://127.0.0.1:58421',
        launchedAt: DateTime.utc(2026, 3, 22, 0, 0),
      );
      final sessionJsonFile = File(p.join(tempDir.path, 'sessionHandle.json'));
      await sessionJsonFile.writeAsString(jsonEncode(handle.toJson()));

      Uri? capturedBaseUri;
      CockpitSnapshotOptions? capturedOptions;
      final service = CockpitCollectRemoteSnapshotService(
        snapshotReader: (baseUri, options) async {
          capturedBaseUri = baseUri;
          capturedOptions = options;
          return CockpitRemoteSnapshotResponse(
            snapshot: CockpitSnapshot(
              routeName: '/inbox',
              diagnosticLevel: options.profile,
              truncated: true,
            ),
          );
        },
      );

      final result = await service.collect(
        CockpitCollectRemoteSnapshotRequest(
          sessionHandlePath: sessionJsonFile.path,
          options: const CockpitSnapshotOptions.forensic(),
        ),
      );

      expect(capturedBaseUri, handle.baseUri);
      expect(capturedOptions?.profile, CockpitSnapshotProfile.forensic);
      expect(capturedOptions?.emitArtifactWhenLarge, isTrue);
      expect(result.snapshot.routeName, '/inbox');
      expect(result.effectiveOptions.profile, CockpitSnapshotProfile.forensic);
      expect(result.effectiveOptions.emitArtifactWhenLarge, isTrue);
      expect(result.sessionHandle?.toJson(), handle.toJson());
      expect(result.warnings, isEmpty);
    },
  );
}

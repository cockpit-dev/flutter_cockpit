import 'dart:io';

import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_application_service_exception.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_bundle_artifact_paths.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_read_task_bundle_summary_service.dart';
import 'package:flutter_cockpit_devtools/src/mcp/cockpit_mcp_error.dart';
import 'package:flutter_cockpit_devtools/src/mcp/tools/cockpit_read_task_bundle_summary_tool.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test(
    'read bundle summary tool returns MCP-safe structured content',
    () async {
      CockpitReadTaskBundleSummaryRequest? capturedRequest;
      final bundleDir = Directory.systemTemp.createTempSync(
        'cockpit_read_task_bundle_summary_tool',
      );
      addTearDown(() async {
        if (bundleDir.existsSync()) {
          await bundleDir.delete(recursive: true);
        }
      });

      final tool = CockpitReadTaskBundleSummaryTool(
        read: (request) async {
          capturedRequest = request;
          return CockpitReadTaskBundleSummaryResult(
            bundleDir: bundleDir.path,
            manifest: CockpitRunManifest(
              sessionId: 'read-tool-session',
              taskId: 'read-tool-task',
              platform: 'ios',
              status: CockpitTaskStatus.completed,
              startedAt: DateTime.utc(2026, 3, 21, 0, 0),
              finishedAt: DateTime.utc(2026, 3, 21, 0, 5),
              commandCount: 2,
              screenshotCount: 1,
              recordingCount: 1,
              deliveryArtifactsReady: true,
              deliveryVideoReady: true,
            ),
            handoff: const <String, Object?>{'status': 'completed'},
            delivery: const <String, Object?>{
              'primaryScreenshotRef': 'screenshots/acceptance.png',
              'primaryRecordingRef': 'recordings/acceptance.mp4',
              'deliveryKeyframesReady': true,
              'keyframeCoverage': <String, Object?>{
                'isReady': true,
                'hasEarlyCoverage': true,
                'hasMidCoverage': true,
                'hasLateCoverage': true,
              },
              'keyframes': <Map<String, Object?>>[
                <String, Object?>{
                  'ref': 'keyframes/acceptance_midpoint.png',
                  'label': 'midpoint',
                  'offsetMs': 2100,
                  'linkedScreenshotRef': 'screenshots/acceptance.png',
                },
              ],
            },
            acceptanceMarkdown: '# Acceptance\n\n- Status: completed\n',
            artifactPaths: CockpitBundleArtifactPaths(
              primaryScreenshotPath: p.join(
                bundleDir.path,
                'screenshots',
                'acceptance.png',
              ),
              primaryRecordingPath: p.join(
                bundleDir.path,
                'recordings',
                'acceptance.mp4',
              ),
              keyframePaths: <String>[
                p.join(bundleDir.path, 'keyframes', 'acceptance_midpoint.png'),
              ],
            ),
            evidenceSummary: const <String, Object?>{
              'status': 'completed',
              'commandCount': 2,
              'screenshotCount': 1,
              'recordingCount': 1,
              'failureCount': 0,
              'keyframeCount': 1,
            },
            diagnosticsArtifactPaths: <String>[
              p.join(bundleDir.path, 'diagnostics', 'acceptance_snapshot.json'),
            ],
            networkSummary: const CockpitBundleNetworkSummary(
              totalEntryCount: 4,
              failureCount: 1,
              truncated: false,
            ),
            runtimeSummary: const CockpitBundleRuntimeSummary(
              totalEntryCount: 3,
              errorCount: 1,
              warningCount: 1,
              truncated: false,
            ),
          );
        },
      );

      final result = await tool.call(<String, Object?>{
        'bundleDir': bundleDir.path,
      });

      expect(capturedRequest?.bundleDir, bundleDir.path);
      final structuredContent =
          result['structuredContent'] as Map<String, Object?>;
      expect(
        (structuredContent['evidenceSummary']
            as Map<String, Object?>)['status'],
        'completed',
      );
      expect(
        (structuredContent['runtimeSummary']
            as Map<String, Object?>)['errorCount'],
        1,
      );
      expect(structuredContent['diagnosticsArtifactPaths'], <String>[
        p.join(bundleDir.path, 'diagnostics', 'acceptance_snapshot.json'),
      ]);
      expect(
        (structuredContent['artifactPaths']
            as Map<String, Object?>)['primaryScreenshotPath'],
        p.join(bundleDir.path, 'screenshots', 'acceptance.png'),
      );
      final evidence = structuredContent['evidence'] as Map<String, Object?>;
      expect(evidence['deliveryKeyframesReady'], isTrue);
      expect(evidence['keyframePaths'], <String>[
        p.join(bundleDir.path, 'keyframes', 'acceptance_midpoint.png'),
      ]);
      expect((evidence['keyframes'] as List<Object?>).single, <String, Object?>{
        'ref': 'keyframes/acceptance_midpoint.png',
        'path': p.join(bundleDir.path, 'keyframes', 'acceptance_midpoint.png'),
        'label': 'midpoint',
        'offsetMs': 2100,
        'linkedScreenshotRef': 'screenshots/acceptance.png',
        'linkedScreenshotPath': p.join(
          bundleDir.path,
          'screenshots',
          'acceptance.png',
        ),
      });
    },
  );

  test(
    'read bundle summary tool maps service errors into MCP errors',
    () async {
      final tool = CockpitReadTaskBundleSummaryTool(
        read: (_) async => throw const CockpitApplicationServiceException(
          code: 'bundleFileMissing',
          message: 'Bundle file is missing.',
        ),
      );

      expect(
        () => tool.call(<String, Object?>{'bundleDir': '/tmp/missing'}),
        throwsA(
          isA<CockpitMcpError>().having(
            (error) => error.data['serviceCode'],
            'serviceCode',
            'bundleFileMissing',
          ),
        ),
      );
    },
  );
}

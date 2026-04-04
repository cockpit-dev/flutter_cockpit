import 'dart:convert';
import 'dart:io';

import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_bundle_artifact_paths.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_read_task_bundle_summary_service.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_run_task_service.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_task_gate.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_validate_task_service.dart';
import 'package:flutter_cockpit_devtools/src/cli/cockpit_control_script.dart';
import 'package:flutter_cockpit_devtools/src/session/cockpit_remote_session_handle.dart';
import 'package:flutter_cockpit_devtools/src/validation/cockpit_bundle_artifact_validator.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test(
    'validate task completes when run_task completed and required delivery files exist',
    () async {
      final bundleDir = await _createBundleDir(
        name: 'cockpit_validate_task_service_completed',
        acceptanceMarkdown: '# Acceptance\n\n- Status: completed\n',
        environmentJson:
            '{"platform":"android","flutterVersion":"3.38.9","dartVersion":"3.10.8"}',
        screenshotRelativePath: 'screenshots/acceptance.png',
        recordingRelativePath: 'recordings/acceptance.mp4',
      );
      addTearDown(() async => _deleteDir(bundleDir));
      for (final name in <String>[
        'acceptance_tail.png',
        'acceptance_baseline.png',
        'acceptance_midpoint.png',
      ]) {
        final keyframeFile = File(p.join(bundleDir.path, 'keyframes', name));
        await keyframeFile.parent.create(recursive: true);
        await keyframeFile.writeAsBytes(_validPngBytes);
      }
      await File(
        p.join(bundleDir.path, 'screenshots', 'acceptance.png'),
      ).writeAsBytes(_structuredAcceptancePngBytes);

      final service = CockpitValidateTaskService(
        artifactValidator: CockpitBundleArtifactValidator(
          processRunner: (executable, arguments) async {
            if (executable == 'ffprobe') {
              final path = arguments.last;
              if (path.endsWith('.png')) {
                return ProcessResult(
                  0,
                  0,
                  '{"streams":[{"codec_name":"png","codec_type":"video","width":240,"height":480}],"format":{"format_name":"png_pipe"}}',
                  '',
                );
              }
              return ProcessResult(
                0,
                0,
                '{"streams":[{"codec_name":"h264","codec_type":"video","width":240,"height":480,"nb_frames":"44"}],"format":{"format_name":"mov,mp4,m4a,3gp,3g2,mj2","duration":"2.706"}}',
                '',
              );
            }
            if (executable == 'ffmpeg') {
              final outputPath = arguments.last;
              await File(outputPath).parent.create(recursive: true);
              await File(
                outputPath,
              ).writeAsBytes(_structuredAcceptancePngBytes);
              return ProcessResult(0, 0, '', '');
            }
            throw ProcessException(
              executable,
              arguments,
              'unexpected executable',
            );
          },
        ),
        runTask: (_) async => _runTaskResult(
          classification: CockpitRunTaskClassification.completed,
          bundleDir: bundleDir,
          platform: 'android',
          screenshotRelativePath: 'screenshots/acceptance.png',
          recordingRelativePath: 'recordings/acceptance.mp4',
          baselineEvidence: _acceptanceEvidence(
            routeName: '/editor',
            visibleTextPreviews: const <String>['Draft'],
            visibleSemanticIds: const <String>['draft-screen'],
            interactiveLabels: const <String>['Publish'],
            accessibilityLabels: const <String>['Draft screen'],
          ),
          acceptanceEvidence: _acceptanceEvidence(
            routeName: '/preview',
            visibleTextPreviews: const <String>['Published'],
            visibleSemanticIds: const <String>['preview-screen'],
            interactiveLabels: const <String>['Share'],
            accessibilityLabels: const <String>['Preview screen'],
          ),
          acceptanceDelta: _acceptanceDelta(
            baselineRouteName: '/editor',
            acceptanceRouteName: '/preview',
            routeChanged: true,
            addedVisibleTextPreviews: const <String>['Published'],
            removedVisibleTextPreviews: const <String>['Draft'],
            addedSemanticIds: const <String>['preview-screen'],
            removedSemanticIds: const <String>['draft-screen'],
            addedInteractiveLabels: const <String>['Share'],
            removedInteractiveLabels: const <String>['Publish'],
            addedAccessibilityLabels: const <String>['Preview screen'],
            removedAccessibilityLabels: const <String>['Draft screen'],
          ),
          keyframes: const <Map<String, Object?>>[
            <String, Object?>{
              'ref': 'keyframes/acceptance_tail.png',
              'label': 'tail_consistency',
              'offsetMs': 7600,
              'source': 'tailConsistency',
            },
            <String, Object?>{
              'ref': 'keyframes/acceptance_baseline.png',
              'label': 'baseline',
              'offsetMs': 600,
              'source': 'stepCapture',
            },
            <String, Object?>{
              'ref': 'keyframes/acceptance_midpoint.png',
              'label': 'midpoint',
              'offsetMs': 3600,
              'source': 'syntheticCoverage',
            },
          ],
          keyframeCoverage: const <String, Object?>{
            'durationMs': 7800,
            'hasEarlyCoverage': true,
            'hasMidCoverage': true,
            'hasLateCoverage': true,
            'isReady': true,
          },
        ),
      );

      final result = await service.validate(
        CockpitValidateTaskRequest(
          runTask: _runTaskRequest(platform: 'android'),
          validation: const CockpitValidateTaskRequirements(
            expectedClassification: CockpitRunTaskClassification.completed,
            requireAcceptanceMarkdown: true,
            requireEnvironmentSnapshot: true,
            requirePrimaryScreenshot: true,
            requirePrimaryRecording: true,
            requireArtifactFiles: true,
          ),
        ),
      );

      expect(result.classification, CockpitValidationClassification.completed);
      expect(result.recommendedNextStep, 'delivery_ready');
      expect(result.validationFailures, isEmpty);
      expect(result.bundleSummary?.bundleDir, bundleDir.path);
    },
  );

  test(
    'validate task downgrades to needs_more_work when primary screenshot exists but AI comparison evidence is missing',
    () async {
      final bundleDir = await _createBundleDir(
        name: 'cockpit_validate_task_service_comparison_missing',
        acceptanceMarkdown: '# Acceptance\n\n- Status: completed\n',
        environmentJson:
            '{"platform":"android","flutterVersion":"3.38.9","dartVersion":"3.10.8"}',
        screenshotRelativePath: 'screenshots/acceptance.png',
        recordingRelativePath: 'recordings/acceptance.mp4',
      );
      addTearDown(() async => _deleteDir(bundleDir));
      await File(
        p.join(bundleDir.path, 'screenshots', 'acceptance.png'),
      ).writeAsBytes(_structuredAcceptancePngBytes);

      final service = CockpitValidateTaskService(
        artifactValidator: CockpitBundleArtifactValidator(
          processRunner: (executable, arguments) async {
            if (executable == 'ffprobe') {
              final path = arguments.last;
              if (path.endsWith('.png')) {
                return ProcessResult(
                  0,
                  0,
                  '{"streams":[{"codec_name":"png","codec_type":"video","width":240,"height":480}],"format":{"format_name":"png_pipe"}}',
                  '',
                );
              }
              return ProcessResult(
                0,
                0,
                '{"streams":[{"codec_name":"h264","codec_type":"video","width":240,"height":480,"nb_frames":"44"}],"format":{"format_name":"mov,mp4,m4a,3gp,3g2,mj2","duration":"2.706"}}',
                '',
              );
            }
            if (executable == 'ffmpeg') {
              final outputPath = arguments.last;
              await File(outputPath).parent.create(recursive: true);
              await File(
                outputPath,
              ).writeAsBytes(_structuredAcceptancePngBytes);
              return ProcessResult(0, 0, '', '');
            }
            throw ProcessException(
              executable,
              arguments,
              'unexpected executable',
            );
          },
        ),
        runTask: (_) async => _runTaskResult(
          classification: CockpitRunTaskClassification.completed,
          bundleDir: bundleDir,
          platform: 'android',
          screenshotRelativePath: 'screenshots/acceptance.png',
          recordingRelativePath: 'recordings/acceptance.mp4',
          keyframes: const <Map<String, Object?>>[
            <String, Object?>{
              'ref': 'keyframes/acceptance_tail.png',
              'label': 'tail_consistency',
              'offsetMs': 7600,
              'source': 'tailConsistency',
            },
            <String, Object?>{
              'ref': 'keyframes/acceptance_baseline.png',
              'label': 'baseline',
              'offsetMs': 600,
              'source': 'stepCapture',
            },
            <String, Object?>{
              'ref': 'keyframes/acceptance_midpoint.png',
              'label': 'midpoint',
              'offsetMs': 3600,
              'source': 'syntheticCoverage',
            },
          ],
          keyframeCoverage: const <String, Object?>{
            'durationMs': 7800,
            'hasEarlyCoverage': true,
            'hasMidCoverage': true,
            'hasLateCoverage': true,
            'isReady': true,
          },
          acceptanceEvidence: _acceptanceEvidence(
            routeName: '/preview',
            visibleTextPreviews: const <String>['Published'],
            visibleSemanticIds: const <String>['preview-screen'],
            interactiveLabels: const <String>['Share'],
            accessibilityLabels: const <String>['Preview screen'],
          ),
        ),
      );

      final result = await service.validate(
        CockpitValidateTaskRequest(
          runTask: _runTaskRequest(platform: 'android'),
          validation: const CockpitValidateTaskRequirements(
            requirePrimaryScreenshot: true,
            requirePrimaryRecording: true,
          ),
        ),
      );

      expect(
        result.classification,
        CockpitValidationClassification.needsMoreWork,
      );
      expect(
        result.validationFailures.map((failure) => failure.code),
        contains('acceptanceComparisonEvidenceMissing'),
      );
    },
  );

  test(
    'validate task downgrades to needs_more_work when acceptance markdown is empty',
    () async {
      final bundleDir = await _createBundleDir(
        name: 'cockpit_validate_task_service_acceptance_empty',
        acceptanceMarkdown: '   \n',
        environmentJson:
            '{"platform":"ios","flutterVersion":"3.38.9","dartVersion":"3.10.8"}',
        screenshotRelativePath: 'screenshots/acceptance.png',
      );
      addTearDown(() async => _deleteDir(bundleDir));

      final service = CockpitValidateTaskService(
        runTask: (_) async => _runTaskResult(
          classification: CockpitRunTaskClassification.completed,
          bundleDir: bundleDir,
          platform: 'ios',
          screenshotRelativePath: 'screenshots/acceptance.png',
        ),
      );

      final result = await service.validate(
        CockpitValidateTaskRequest(
          runTask: _runTaskRequest(platform: 'ios'),
          validation: const CockpitValidateTaskRequirements(
            requireAcceptanceMarkdown: true,
          ),
        ),
      );

      expect(
        result.classification,
        CockpitValidationClassification.needsMoreWork,
      );
      expect(result.recommendedNextStep, 'collect_missing_evidence');
      expect(
        result.validationFailures.map((failure) => failure.code),
        containsAll(<String>[
          'acceptanceEmpty',
          'acceptanceComparisonEvidenceMissing',
        ]),
      );
    },
  );

  test('validate task surfaces runtime errors as failed_with_evidence',
      () async {
    final bundleDir = await _createBundleDir(
      name: 'cockpit_validate_task_service_runtime_error',
      acceptanceMarkdown: '# Acceptance\n',
      environmentJson:
          '{"platform":"android","flutterVersion":"3.38.9","dartVersion":"3.10.8"}',
      screenshotRelativePath: 'screenshots/acceptance.png',
    );
    addTearDown(() async => _deleteDir(bundleDir));

    final service = CockpitValidateTaskService(
      runTask: (_) async => _runTaskResult(
        classification: CockpitRunTaskClassification.failedWithEvidence,
        bundleDir: bundleDir,
        platform: 'android',
        screenshotRelativePath: 'screenshots/acceptance.png',
        runtimeEventCount: 1,
        runtimeErrorCount: 1,
      ),
    );

    final result = await service.validate(
      CockpitValidateTaskRequest(
        runTask: _runTaskRequest(platform: 'android'),
        validation: const CockpitValidateTaskRequirements(
          requirePrimaryScreenshot: true,
        ),
      ),
    );

    expect(
      result.classification,
      CockpitValidationClassification.failedWithEvidence,
    );
    expect(
      result.validationFailures.map((failure) => failure.code),
      contains('runtimeErrorsDetected'),
    );
  });

  test(
    'validate task downgrades to needs_more_work when a required artifact file is missing',
    () async {
      final bundleDir = await _createBundleDir(
        name: 'cockpit_validate_task_service_artifact_missing',
        acceptanceMarkdown: '# Acceptance\n',
        environmentJson:
            '{"platform":"android","flutterVersion":"3.38.9","dartVersion":"3.10.8"}',
        screenshotRelativePath: 'screenshots/acceptance.png',
      );
      addTearDown(() async => _deleteDir(bundleDir));
      final screenshotFile = File(
        p.join(bundleDir.path, 'screenshots', 'acceptance.png'),
      );
      if (screenshotFile.existsSync()) {
        await screenshotFile.delete();
      }

      final service = CockpitValidateTaskService(
        runTask: (_) async => _runTaskResult(
          classification: CockpitRunTaskClassification.completed,
          bundleDir: bundleDir,
          platform: 'android',
          screenshotRelativePath: 'screenshots/acceptance.png',
        ),
      );

      final result = await service.validate(
        CockpitValidateTaskRequest(
          runTask: _runTaskRequest(platform: 'android'),
          validation: const CockpitValidateTaskRequirements(
            requirePrimaryScreenshot: true,
            requireArtifactFiles: true,
          ),
        ),
      );

      expect(
        result.classification,
        CockpitValidationClassification.needsMoreWork,
      );
      expect(result.validationFailures, isNotEmpty);
      expect(
        result.validationFailures.map((failure) => failure.code),
        contains('missingBundleArtifact'),
      );
    },
  );

  test(
    'validate task downgrades to needs_more_work when the screenshot artifact is invalid',
    () async {
      final bundleDir = await _createBundleDir(
        name: 'cockpit_validate_task_service_invalid_screenshot',
        acceptanceMarkdown: '# Acceptance\n',
        environmentJson:
            '{"platform":"android","flutterVersion":"3.38.9","dartVersion":"3.10.8"}',
        screenshotRelativePath: 'screenshots/acceptance.png',
      );
      addTearDown(() async => _deleteDir(bundleDir));
      await File(
        p.join(bundleDir.path, 'screenshots', 'acceptance.png'),
      ).writeAsBytes(const <int>[1, 2, 3, 4]);

      final service = CockpitValidateTaskService(
        runTask: (_) async => _runTaskResult(
          classification: CockpitRunTaskClassification.completed,
          bundleDir: bundleDir,
          platform: 'android',
          screenshotRelativePath: 'screenshots/acceptance.png',
        ),
      );

      final result = await service.validate(
        CockpitValidateTaskRequest(
          runTask: _runTaskRequest(platform: 'android'),
          validation: const CockpitValidateTaskRequirements(
            requirePrimaryScreenshot: true,
          ),
        ),
      );

      expect(
        result.classification,
        CockpitValidationClassification.needsMoreWork,
      );
      expect(
        result.validationFailures.map((failure) => failure.code),
        contains('invalidScreenshotArtifact'),
      );
    },
  );

  test(
    'validate task downgrades to needs_more_work when the recording artifact is invalid',
    () async {
      final bundleDir = await _createBundleDir(
        name: 'cockpit_validate_task_service_invalid_recording',
        acceptanceMarkdown: '# Acceptance\n',
        environmentJson:
            '{"platform":"ios","flutterVersion":"3.38.9","dartVersion":"3.10.8"}',
        recordingRelativePath: 'recordings/acceptance.mp4',
      );
      addTearDown(() async => _deleteDir(bundleDir));
      await File(
        p.join(bundleDir.path, 'recordings', 'acceptance.mp4'),
      ).writeAsBytes(const <int>[1, 2, 3, 4]);

      final service = CockpitValidateTaskService(
        runTask: (_) async => _runTaskResult(
          classification: CockpitRunTaskClassification.completed,
          bundleDir: bundleDir,
          platform: 'ios',
          recordingRelativePath: 'recordings/acceptance.mp4',
        ),
      );

      final result = await service.validate(
        CockpitValidateTaskRequest(
          runTask: _runTaskRequest(platform: 'ios'),
          validation: const CockpitValidateTaskRequirements(
            requirePrimaryRecording: true,
          ),
        ),
      );

      expect(
        result.classification,
        CockpitValidationClassification.needsMoreWork,
      );
      expect(
        result.validationFailures.map((failure) => failure.code),
        contains('invalidRecordingArtifact'),
      );
    },
  );

  test(
    'validate task surfaces recording gate failures when delivery video is unavailable',
    () async {
      final bundleDir = await _createBundleDir(
        name: 'cockpit_validate_task_service_recording_gate_failure',
        acceptanceMarkdown: '# Acceptance\n',
        environmentJson:
            '{"platform":"ios","flutterVersion":"3.38.9","dartVersion":"3.10.8"}',
      );
      addTearDown(() async => _deleteDir(bundleDir));

      final service = CockpitValidateTaskService(
        runTask: (_) async => _runTaskResult(
          classification: CockpitRunTaskClassification.completed,
          bundleDir: bundleDir,
          platform: 'ios',
          deliveryVideoFailureCodes: const <String>['recordingFailed'],
        ),
      );

      final result = await service.validate(
        CockpitValidateTaskRequest(
          runTask: _runTaskRequest(platform: 'ios'),
          validation: const CockpitValidateTaskRequirements(
            requirePrimaryRecording: true,
          ),
        ),
      );

      expect(
        result.classification,
        CockpitValidationClassification.needsMoreWork,
      );
      final recordingFailure = result.validationFailures.firstWhere(
        (failure) => failure.code == 'recordingFailed',
      );
      expect(
        recordingFailure.details['gate'],
        CockpitTaskGate.recordingReadyOrExplained.name,
      );
      expect(
        recordingFailure.details['failureCodes'],
        const <String>['recordingFailed'],
      );
    },
  );

  test(
    'validate task downgrades to needs_more_work when semantic acceptance evidence is required but missing',
    () async {
      final bundleDir = await _createBundleDir(
        name: 'cockpit_validate_task_service_acceptanceEvidence_missing',
        acceptanceMarkdown: '# Acceptance\n',
        environmentJson:
            '{"platform":"android","flutterVersion":"3.38.9","dartVersion":"3.10.8"}',
        screenshotRelativePath: 'screenshots/acceptance.png',
        recordingRelativePath: 'recordings/acceptance.mp4',
      );
      addTearDown(() async => _deleteDir(bundleDir));

      final service = CockpitValidateTaskService(
        runTask: (_) async => _runTaskResult(
          classification: CockpitRunTaskClassification.completed,
          bundleDir: bundleDir,
          platform: 'android',
          screenshotRelativePath: 'screenshots/acceptance.png',
          recordingRelativePath: 'recordings/acceptance.mp4',
        ),
      );

      final result = await service.validate(
        CockpitValidateTaskRequest(
          runTask: _runTaskRequest(platform: 'android'),
          validation: const CockpitValidateTaskRequirements(
            requirePrimaryScreenshot: true,
            requirePrimaryRecording: true,
            requireAcceptanceSemanticEvidence: true,
          ),
        ),
      );

      expect(
        result.classification,
        CockpitValidationClassification.needsMoreWork,
      );
      expect(
        result.validationFailures.map((failure) => failure.code),
        contains('acceptanceSemanticEvidenceMissing'),
      );
    },
  );

  test(
    'validate task downgrades to needs_more_work when delivery screenshot and recording are inconsistent',
    () async {
      final bundleDir = await _createBundleDir(
        name: 'cockpit_validate_task_service_inconsistent_delivery',
        acceptanceMarkdown: '# Acceptance\n',
        environmentJson:
            '{"platform":"android","flutterVersion":"3.38.9","dartVersion":"3.10.8"}',
        screenshotRelativePath: 'screenshots/acceptance.png',
        recordingRelativePath: 'recordings/acceptance.mp4',
      );
      addTearDown(() async => _deleteDir(bundleDir));
      await File(
        p.join(bundleDir.path, 'screenshots', 'acceptance.png'),
      ).writeAsBytes(_structuredAcceptancePngBytes);

      final service = CockpitValidateTaskService(
        artifactValidator: CockpitBundleArtifactValidator(
          processRunner: (executable, arguments) async {
            if (executable == 'ffprobe') {
              final path = arguments.last;
              if (path.endsWith('.png')) {
                return ProcessResult(
                  0,
                  0,
                  '{"streams":[{"codec_name":"png","codec_type":"video","width":240,"height":480}],"format":{"format_name":"png_pipe"}}',
                  '',
                );
              }
              return ProcessResult(
                0,
                0,
                '{"streams":[{"codec_name":"h264","codec_type":"video","width":16,"height":16}],"format":{"format_name":"mov,mp4,m4a,3gp,3g2,mj2"}}',
                '',
              );
            }
            if (executable == 'ffmpeg') {
              final outputPath = arguments.last;
              await File(outputPath).parent.create(recursive: true);
              await File(outputPath).writeAsBytes(_contrastAcceptancePngBytes);
              return ProcessResult(0, 0, '', '');
            }
            throw ProcessException(
              executable,
              arguments,
              'unexpected executable',
            );
          },
        ),
        runTask: (_) async => _runTaskResult(
          classification: CockpitRunTaskClassification.completed,
          bundleDir: bundleDir,
          platform: 'android',
          screenshotRelativePath: 'screenshots/acceptance.png',
          recordingRelativePath: 'recordings/acceptance.mp4',
        ),
      );

      final result = await service.validate(
        CockpitValidateTaskRequest(
          runTask: _runTaskRequest(platform: 'android'),
          validation: const CockpitValidateTaskRequirements(
            requirePrimaryScreenshot: true,
            requirePrimaryRecording: true,
          ),
        ),
      );

      expect(
        result.classification,
        CockpitValidationClassification.needsMoreWork,
      );
      expect(
        result.validationFailures.map((failure) => failure.code),
        contains('inconsistentDeliveryEvidence'),
      );
    },
  );

  test(
    'validate task accepts bundle keyframes as delivery consistency candidates',
    () async {
      final bundleDir = await _createBundleDir(
        name: 'cockpit_validate_task_service_keyframe_consistency',
        acceptanceMarkdown: '# Acceptance\n\n- Status: completed\n',
        environmentJson:
            '{"platform":"ios","flutterVersion":"3.38.9","dartVersion":"3.10.8"}',
        screenshotRelativePath: 'screenshots/acceptance.png',
        recordingRelativePath: 'recordings/acceptance.mp4',
      );
      addTearDown(() async => _deleteDir(bundleDir));

      final screenshotPath = p.join(
        bundleDir.path,
        'screenshots',
        'acceptance.png',
      );
      await File(screenshotPath).writeAsBytes(_structuredAcceptancePngBytes);
      for (final name in <String>[
        'acceptance_baseline.png',
        'acceptance_midpoint.png',
        'acceptance_tail.png',
      ]) {
        final keyframePath = p.join(bundleDir.path, 'keyframes', name);
        await File(keyframePath).parent.create(recursive: true);
        await File(keyframePath).writeAsBytes(_structuredAcceptancePngBytes);
      }

      final service = CockpitValidateTaskService(
        artifactValidator: CockpitBundleArtifactValidator(
          processRunner: (executable, arguments) async {
            if (executable == 'ffprobe') {
              final path = arguments.last;
              if (path.endsWith('.png')) {
                return ProcessResult(
                  0,
                  0,
                  '{"streams":[{"codec_name":"png","codec_type":"video","width":240,"height":480}],"format":{"format_name":"png_pipe"}}',
                  '',
                );
              }
              return ProcessResult(
                0,
                0,
                '{"streams":[{"codec_name":"h264","codec_type":"video","width":240,"height":480,"nb_frames":"44"}],"format":{"format_name":"mov,mp4,m4a,3gp,3g2,mj2","duration":"13.455"}}',
                '',
              );
            }
            if (executable == 'ffmpeg') {
              final outputPath = arguments.last;
              await File(outputPath).parent.create(recursive: true);
              await File(outputPath).writeAsBytes(_contrastAcceptancePngBytes);
              return ProcessResult(0, 0, '', '');
            }
            throw ProcessException(
              executable,
              arguments,
              'unexpected executable',
            );
          },
        ),
        runTask: (_) async => _runTaskResult(
          classification: CockpitRunTaskClassification.completed,
          bundleDir: bundleDir,
          platform: 'ios',
          screenshotRelativePath: 'screenshots/acceptance.png',
          recordingRelativePath: 'recordings/acceptance.mp4',
          keyframes: const <Map<String, Object?>>[
            <String, Object?>{
              'ref': 'keyframes/acceptance_baseline.png',
              'label': 'baseline',
              'offsetMs': 1644,
              'source': 'stepCapture',
            },
            <String, Object?>{
              'ref': 'keyframes/acceptance_midpoint.png',
              'label': 'midpoint',
              'offsetMs': 6728,
              'source': 'syntheticCoverage',
            },
            <String, Object?>{
              'ref': 'keyframes/acceptance_tail.png',
              'label': 'acceptance',
              'offsetMs': 12238,
              'source': 'stepCapture',
              'linkedScreenshotRef': 'screenshots/acceptance.png',
            },
            <String, Object?>{
              'ref': 'keyframes/acceptance_tail.png',
              'label': 'tail_consistency',
              'offsetMs': 12855,
              'source': 'tailConsistency',
            },
          ],
          keyframeCoverage: const <String, Object?>{
            'durationMs': 13455,
            'hasEarlyCoverage': true,
            'hasMidCoverage': true,
            'hasLateCoverage': true,
            'isReady': true,
          },
          baselineEvidence: _acceptanceEvidence(
            routeName: '/inbox',
            visibleTextPreviews: const <String>['Inbox'],
            interactiveLabels: const <String>['Inbox', 'New task'],
            accessibilityLabels: const <String>['Inbox'],
          ),
          acceptanceEvidence: _acceptanceEvidence(
            routeName: '/inbox',
            visibleTextPreviews: const <String>['Inbox'],
            interactiveLabels: const <String>['Inbox', 'New task'],
            accessibilityLabels: const <String>['Inbox', 'Fresh canvas'],
          ),
          acceptanceDelta: _acceptanceDelta(
            baselineRouteName: '/inbox',
            acceptanceRouteName: '/inbox',
            routeChanged: false,
            addedAccessibilityLabels: const <String>['Fresh canvas'],
          ),
        ),
      );

      final result = await service.validate(
        CockpitValidateTaskRequest(
          runTask: _runTaskRequest(platform: 'ios'),
          validation: const CockpitValidateTaskRequirements(
            expectedClassification: CockpitRunTaskClassification.completed,
            requirePrimaryScreenshot: true,
            requirePrimaryRecording: true,
          ),
        ),
      );

      expect(result.classification, CockpitValidationClassification.completed);
      expect(result.validationFailures, isEmpty);
    },
  );

  test(
    'validate task downgrades to needs_more_work when a recording has no extracted keyframes',
    () async {
      final bundleDir = await _createBundleDir(
        name: 'cockpit_validate_task_service_missing_keyframes',
        acceptanceMarkdown: '# Acceptance\n',
        environmentJson:
            '{"platform":"android","flutterVersion":"3.38.9","dartVersion":"3.10.8"}',
        screenshotRelativePath: 'screenshots/acceptance.png',
        recordingRelativePath: 'recordings/acceptance.mp4',
      );
      addTearDown(() async => _deleteDir(bundleDir));

      final service = CockpitValidateTaskService(
        artifactValidator: CockpitBundleArtifactValidator(
          processRunner: (executable, arguments) async {
            if (executable == 'ffprobe') {
              final path = arguments.last;
              if (path.endsWith('.png')) {
                return ProcessResult(
                  0,
                  0,
                  '{"streams":[{"codec_name":"png","codec_type":"video","width":2,"height":2}],"format":{"format_name":"png_pipe"}}',
                  '',
                );
              }
              return ProcessResult(
                0,
                0,
                '{"streams":[{"codec_name":"h264","codec_type":"video","width":16,"height":16}],"format":{"format_name":"mov,mp4,m4a,3gp,3g2,mj2"}}',
                '',
              );
            }
            if (executable == 'ffmpeg') {
              final outputPath = arguments.last;
              await File(outputPath).parent.create(recursive: true);
              await File(
                outputPath,
              ).writeAsBytes(_structuredAcceptancePngBytes);
              return ProcessResult(0, 0, '', '');
            }
            throw ProcessException(
              executable,
              arguments,
              'unexpected executable',
            );
          },
        ),
        runTask: (_) async => _runTaskResult(
          classification: CockpitRunTaskClassification.completed,
          bundleDir: bundleDir,
          platform: 'android',
          screenshotRelativePath: 'screenshots/acceptance.png',
          recordingRelativePath: 'recordings/acceptance.mp4',
        ),
      );

      final result = await service.validate(
        CockpitValidateTaskRequest(
          runTask: _runTaskRequest(platform: 'android'),
          validation: const CockpitValidateTaskRequirements(
            requirePrimaryScreenshot: true,
            requirePrimaryRecording: true,
          ),
        ),
      );

      expect(
        result.classification,
        CockpitValidationClassification.needsMoreWork,
      );
      expect(
        result.validationFailures.map((failure) => failure.code),
        contains('recordingKeyframesMissing'),
      );
    },
  );

  test(
    'validate task downgrades to needs_more_work when recording keyframe coverage is insufficient',
    () async {
      final bundleDir = await _createBundleDir(
        name: 'cockpit_validate_task_service_insufficient_keyframes',
        acceptanceMarkdown: '# Acceptance\n',
        environmentJson:
            '{"platform":"ios","flutterVersion":"3.38.9","dartVersion":"3.10.8"}',
        screenshotRelativePath: 'screenshots/acceptance.png',
        recordingRelativePath: 'recordings/acceptance.mp4',
      );
      addTearDown(() async => _deleteDir(bundleDir));
      await File(p.join(bundleDir.path, 'delivery.json')).writeAsString(
        jsonEncode(<String, Object?>{
          'primaryScreenshotRef': 'screenshots/acceptance.png',
          'primaryRecordingRef': 'recordings/acceptance.mp4',
          'keyframes': <Object?>[
            <String, Object?>{
              'ref': 'keyframes/acceptance_midpoint.png',
              'label': 'midpoint',
              'offsetMs': 3200,
              'source': 'syntheticCoverage',
            },
          ],
          'keyframeCoverage': <String, Object?>{
            'durationMs': 7800,
            'hasEarlyCoverage': false,
            'hasMidCoverage': true,
            'hasLateCoverage': false,
            'isReady': false,
          },
        }),
      );
      final keyframeFile = File(
        p.join(bundleDir.path, 'keyframes', 'acceptance_midpoint.png'),
      );
      await keyframeFile.parent.create(recursive: true);
      await keyframeFile.writeAsBytes(_validPngBytes);

      final service = CockpitValidateTaskService(
        artifactValidator: CockpitBundleArtifactValidator(
          processRunner: (executable, arguments) async {
            if (executable == 'ffprobe') {
              final path = arguments.last;
              if (path.endsWith('.png')) {
                return ProcessResult(
                  0,
                  0,
                  '{"streams":[{"codec_name":"png","codec_type":"video","width":2,"height":2}],"format":{"format_name":"png_pipe"}}',
                  '',
                );
              }
              return ProcessResult(
                0,
                0,
                '{"streams":[{"codec_name":"h264","codec_type":"video","width":16,"height":16}],"format":{"format_name":"mov,mp4,m4a,3gp,3g2,mj2"}}',
                '',
              );
            }
            if (executable == 'ffmpeg') {
              final outputPath = arguments.last;
              await File(outputPath).parent.create(recursive: true);
              await File(
                outputPath,
              ).writeAsBytes(_structuredAcceptancePngBytes);
              return ProcessResult(0, 0, '', '');
            }
            throw ProcessException(
              executable,
              arguments,
              'unexpected executable',
            );
          },
        ),
        runTask: (_) async => _runTaskResult(
          classification: CockpitRunTaskClassification.completed,
          bundleDir: bundleDir,
          platform: 'ios',
          screenshotRelativePath: 'screenshots/acceptance.png',
          recordingRelativePath: 'recordings/acceptance.mp4',
          keyframes: const <Map<String, Object?>>[
            <String, Object?>{
              'ref': 'keyframes/acceptance_midpoint.png',
              'label': 'midpoint',
              'offsetMs': 3200,
              'source': 'syntheticCoverage',
            },
          ],
          keyframeCoverage: const <String, Object?>{
            'durationMs': 7800,
            'hasEarlyCoverage': false,
            'hasMidCoverage': true,
            'hasLateCoverage': false,
            'isReady': false,
          },
        ),
      );

      final result = await service.validate(
        CockpitValidateTaskRequest(
          runTask: _runTaskRequest(platform: 'ios'),
          validation: const CockpitValidateTaskRequirements(
            requirePrimaryScreenshot: true,
            requirePrimaryRecording: true,
            requireArtifactFiles: true,
          ),
        ),
      );

      expect(
        result.classification,
        CockpitValidationClassification.needsMoreWork,
      );
      expect(
        result.validationFailures.map((failure) => failure.code),
        contains('recordingCoverageInsufficient'),
      );
    },
  );

  test(
    'validate task propagates blocked_by_environment from run_task',
    () async {
      final service = CockpitValidateTaskService(
        runTask: (_) async => const CockpitRunTaskResult(
          classification: CockpitRunTaskClassification.blockedByEnvironment,
          recommendedNextStep: 'needs_relaunch',
          blockedReason: 'Session unreachable.',
        ),
      );

      final result = await service.validate(
        CockpitValidateTaskRequest(
          runTask: _runTaskRequest(platform: 'android'),
        ),
      );

      expect(
        result.classification,
        CockpitValidationClassification.blockedByEnvironment,
      );
      expect(result.recommendedNextStep, 'needs_relaunch');
      expect(result.blockedReason, 'Session unreachable.');
    },
  );

  test('validate task propagates failed_with_evidence from run_task', () async {
    final bundleDir = await _createBundleDir(
      name: 'cockpit_validate_task_service_failed_with_evidence',
      acceptanceMarkdown: '# Acceptance\n\n- Status: failed\n',
      environmentJson:
          '{"platform":"ios","flutterVersion":"3.38.9","dartVersion":"3.10.8"}',
    );
    addTearDown(() async => _deleteDir(bundleDir));

    final service = CockpitValidateTaskService(
      runTask: (_) async => _runTaskResult(
        classification: CockpitRunTaskClassification.failedWithEvidence,
        bundleDir: bundleDir,
        platform: 'ios',
        taskStatus: CockpitTaskStatus.failed,
      ),
    );

    final result = await service.validate(
      CockpitValidateTaskRequest(runTask: _runTaskRequest(platform: 'ios')),
    );

    expect(
      result.classification,
      CockpitValidationClassification.failedWithEvidence,
    );
    expect(result.recommendedNextStep, 'inspect_bundle');
  });
}

CockpitRunTaskRequest _runTaskRequest({required String platform}) {
  return CockpitRunTaskRequest(
    sessionHandle: CockpitRemoteSessionHandle(
      platform: platform,
      deviceId: platform == 'android' ? 'emulator-5554' : 'ios-simulator',
      projectDir: '/workspace/examples/cockpit_demo',
      target: 'lib/main.dart',
      appId: platform == 'android'
          ? 'dev.cockpit.cockpit_demo'
          : 'dev.cockpit.cockpitDemo',
      host: '127.0.0.1',
      hostPort: 48331,
      devicePort: 48331,
      baseUrl: 'http://127.0.0.1:48331',
      launchedAt: DateTime.utc(2026, 3, 21, 0, 0),
    ),
    script: CockpitControlScript(
      sessionId: 'validate-task-session',
      taskId: 'validate-task-id',
      platform: platform,
      commands: const <CockpitCommand>[],
      failFast: true,
    ),
    outputRoot: '/tmp/flutter_cockpit_validate_task',
  );
}

CockpitRunTaskResult _runTaskResult({
  required CockpitRunTaskClassification classification,
  required Directory bundleDir,
  required String platform,
  String? screenshotRelativePath,
  String? recordingRelativePath,
  List<String> deliveryArtifactFailureCodes = const <String>[],
  List<String> deliveryVideoFailureCodes = const <String>[],
  CockpitBundleAcceptanceEvidence? baselineEvidence,
  CockpitBundleAcceptanceEvidence? acceptanceEvidence,
  CockpitBundleAcceptanceDelta? acceptanceDelta,
  List<Map<String, Object?>> keyframes = const <Map<String, Object?>>[],
  Map<String, Object?>? keyframeCoverage,
  CockpitTaskStatus taskStatus = CockpitTaskStatus.completed,
  int runtimeEventCount = 0,
  int runtimeErrorCount = 0,
  int runtimeWarningCount = 0,
}) {
  final artifactPaths = CockpitBundleArtifactPaths(
    primaryScreenshotPath: screenshotRelativePath == null
        ? null
        : p.join(bundleDir.path, screenshotRelativePath),
    primaryRecordingPath: recordingRelativePath == null
        ? null
        : p.join(bundleDir.path, recordingRelativePath),
  );
  final manifest = CockpitRunManifest(
    sessionId: 'validate-task-session',
    taskId: 'validate-task-id',
    platform: platform,
    status: taskStatus,
    startedAt: DateTime.utc(2026, 3, 21, 0, 0),
    finishedAt: DateTime.utc(2026, 3, 21, 0, 5),
    screenshotCount: screenshotRelativePath == null ? 0 : 1,
    recordingCount: recordingRelativePath == null ? 0 : 1,
    deliveryArtifactsReady: screenshotRelativePath != null,
    deliveryVideoReady: recordingRelativePath != null,
    deliveryArtifactFailureCodes: deliveryArtifactFailureCodes,
    deliveryVideoFailureCodes: deliveryVideoFailureCodes,
    runtimeEventCount: runtimeEventCount,
    runtimeErrorCount: runtimeErrorCount,
    runtimeWarningCount: runtimeWarningCount,
  );
  final acceptanceEvidenceFailureCodes = <String>[
    if (baselineEvidence == null) 'baselineEvidenceMissing',
    if (acceptanceEvidence == null) 'acceptanceEvidenceMissing',
    if (acceptanceDelta == null) 'acceptanceDeltaMissing',
    if (baselineEvidence != null && !baselineEvidence.hasComparableSignals)
      'baselineComparableSignalsMissing',
    if (acceptanceEvidence != null && !acceptanceEvidence.hasComparableSignals)
      'acceptanceComparableSignalsMissing',
  ];
  final screenshotFailureCodes = deliveryArtifactFailureCodes.isNotEmpty ||
          manifest.deliveryArtifactsReady
      ? deliveryArtifactFailureCodes
      : <String>[
          if (screenshotRelativePath == null || screenshotRelativePath.isEmpty)
            'primaryScreenshotMissing'
          else
            'acceptanceScreenshotMissing',
        ];
  final recordingFailureCodes = deliveryVideoFailureCodes.isNotEmpty ||
          manifest.deliveryVideoReady
      ? deliveryVideoFailureCodes
      : <String>[
          if (recordingRelativePath == null || recordingRelativePath.isEmpty)
            'primaryRecordingMissing'
          else
            'acceptanceRecordingMissing',
        ];
  final gateSummary = CockpitBundleGateSummary(
    gates: <CockpitTaskGate, bool>{
      CockpitTaskGate.sessionReachable: true,
      CockpitTaskGate.baselineCollected:
          baselineEvidence != null || screenshotRelativePath != null,
      CockpitTaskGate.executionFinished: true,
      CockpitTaskGate.bundleWritten: true,
      CockpitTaskGate.screenshotReady: manifest.deliveryArtifactsReady,
      CockpitTaskGate.recordingReadyOrExplained: manifest.deliveryVideoReady,
      CockpitTaskGate.deliveryValidated:
          manifest.deliveryArtifactsReady && manifest.deliveryVideoReady,
      CockpitTaskGate.acceptanceEvidenceReadable:
          acceptanceEvidenceFailureCodes.isEmpty,
      CockpitTaskGate.finalAssertionPassed:
          taskStatus != CockpitTaskStatus.failed && runtimeErrorCount == 0,
    },
    failureCodes: <CockpitTaskGate, List<String>>{
      if (!manifest.deliveryArtifactsReady)
        CockpitTaskGate.screenshotReady: screenshotFailureCodes,
      if (!manifest.deliveryVideoReady)
        CockpitTaskGate.recordingReadyOrExplained: recordingFailureCodes,
      if (!(manifest.deliveryArtifactsReady && manifest.deliveryVideoReady))
        CockpitTaskGate.deliveryValidated: <String>[
          ...{
            ...screenshotFailureCodes,
            ...recordingFailureCodes,
          },
        ],
      if (acceptanceEvidenceFailureCodes.isNotEmpty)
        CockpitTaskGate.acceptanceEvidenceReadable:
            acceptanceEvidenceFailureCodes,
      if (runtimeErrorCount > 0 || taskStatus == CockpitTaskStatus.failed)
        CockpitTaskGate.finalAssertionPassed: <String>[
          if (runtimeErrorCount > 0) 'runtimeErrorsDetected' else 'taskFailed',
        ],
    },
  );
  final bundleSummary = CockpitReadTaskBundleSummaryResult(
    bundleDir: bundleDir.path,
    manifest: manifest,
    handoff: <String, Object?>{'status': classification.jsonValue},
    delivery: <String, Object?>{
      if (screenshotRelativePath != null)
        'primaryScreenshotRef': screenshotRelativePath,
      if (recordingRelativePath != null)
        'primaryRecordingRef': recordingRelativePath,
      if (deliveryArtifactFailureCodes.isNotEmpty ||
          deliveryVideoFailureCodes.isNotEmpty)
        'readiness': <String, Object?>{
          'artifacts': <String, Object?>{
            'ready': screenshotRelativePath != null,
            'failureCodes': deliveryArtifactFailureCodes,
          },
          'video': <String, Object?>{
            'ready': recordingRelativePath != null,
            'failureCodes': deliveryVideoFailureCodes,
          },
        },
      if (keyframes.isNotEmpty) 'keyframes': keyframes,
      if (keyframeCoverage != null) 'keyframeCoverage': keyframeCoverage,
    },
    acceptanceMarkdown: '',
    artifactPaths: artifactPaths,
    baselineEvidence: baselineEvidence,
    acceptanceEvidence: acceptanceEvidence,
    acceptanceDelta: acceptanceDelta,
    evidenceSummary: <String, Object?>{
      'status': taskStatus.name,
      'commandCount': 0,
      'screenshotCount': manifest.screenshotCount,
      'recordingCount': manifest.recordingCount,
      'failureCount': manifest.failureCount,
      'keyframeCount': keyframes.length,
      'deliveryKeyframesReady': keyframeCoverage == null
          ? false
          : keyframeCoverage['isReady'] == true,
      'runtimeEventCount': manifest.runtimeEventCount,
      'runtimeErrorCount': manifest.runtimeErrorCount,
      'runtimeWarningCount': manifest.runtimeWarningCount,
    },
    gateSummary: gateSummary,
  );

  return CockpitRunTaskResult(
    classification: classification,
    recommendedNextStep:
        classification == CockpitRunTaskClassification.completed
            ? 'delivery_ready'
            : classification == CockpitRunTaskClassification.failedWithEvidence
                ? 'inspect_bundle'
                : 'needs_relaunch',
    bundleSummary: bundleSummary,
  );
}

CockpitBundleAcceptanceEvidence _acceptanceEvidence({
  required String routeName,
  List<String> visibleTextPreviews = const <String>[],
  List<String> visibleSemanticIds = const <String>[],
  List<String> interactiveLabels = const <String>[],
  List<String> accessibilityLabels = const <String>[],
}) {
  return CockpitBundleAcceptanceEvidence(
    routeName: routeName,
    diagnosticLevel: 'investigate',
    diagnosticsArtifactPath: '/tmp/diagnostics.json',
    visibleTextPreviews: visibleTextPreviews,
    visibleSemanticIds: visibleSemanticIds,
    interactiveLabels: interactiveLabels,
    accessibilityLabels: accessibilityLabels,
    visibleTargetCount: visibleTextPreviews.length +
        visibleSemanticIds.length +
        interactiveLabels.length,
    accessibilityEntryCount: accessibilityLabels.length,
    hasAccessibilitySummary: accessibilityLabels.isNotEmpty,
    networkEntryCount: 0,
    networkFailureCount: 0,
    networkFailureSignals: const <CockpitBundleAcceptanceNetworkSignal>[],
    runtimeEntryCount: 0,
    runtimeErrorCount: 0,
    runtimeWarningCount: 0,
    runtimeErrorSignals: const <CockpitBundleAcceptanceRuntimeSignal>[],
    rebuildTotalCount: 0,
    rebuildUniqueElementCount: 0,
    rebuildHotspots: const <CockpitBundleAcceptanceRebuildHotspot>[],
  );
}

CockpitBundleAcceptanceDelta _acceptanceDelta({
  required String baselineRouteName,
  required String acceptanceRouteName,
  required bool routeChanged,
  List<String> addedVisibleTextPreviews = const <String>[],
  List<String> removedVisibleTextPreviews = const <String>[],
  List<String> addedSemanticIds = const <String>[],
  List<String> removedSemanticIds = const <String>[],
  List<String> addedInteractiveLabels = const <String>[],
  List<String> removedInteractiveLabels = const <String>[],
  List<String> addedAccessibilityLabels = const <String>[],
  List<String> removedAccessibilityLabels = const <String>[],
}) {
  return CockpitBundleAcceptanceDelta(
    baselineRouteName: baselineRouteName,
    acceptanceRouteName: acceptanceRouteName,
    routeChanged: routeChanged,
    addedVisibleTextPreviews: addedVisibleTextPreviews,
    removedVisibleTextPreviews: removedVisibleTextPreviews,
    addedSemanticIds: addedSemanticIds,
    removedSemanticIds: removedSemanticIds,
    addedInteractiveLabels: addedInteractiveLabels,
    removedInteractiveLabels: removedInteractiveLabels,
    addedAccessibilityLabels: addedAccessibilityLabels,
    removedAccessibilityLabels: removedAccessibilityLabels,
    networkFailureDeltaCount: 0,
    newNetworkFailureSignals: const <CockpitBundleAcceptanceNetworkSignal>[],
    runtimeErrorDeltaCount: 0,
    newRuntimeErrorSignals: const <CockpitBundleAcceptanceRuntimeSignal>[],
    rebuildTotalDeltaCount: 0,
    rebuildUniqueElementDeltaCount: 0,
    newRebuildHotspots: const <CockpitBundleAcceptanceRebuildHotspot>[],
  );
}

Future<Directory> _createBundleDir({
  required String name,
  required String acceptanceMarkdown,
  required String environmentJson,
  String? screenshotRelativePath,
  String? recordingRelativePath,
}) async {
  final tempDir = await Directory.systemTemp.createTemp(name);
  await File(
    p.join(tempDir.path, 'acceptance.md'),
  ).writeAsString(acceptanceMarkdown);
  await File(
    p.join(tempDir.path, 'environment.json'),
  ).writeAsString(environmentJson);
  if (screenshotRelativePath != null) {
    final screenshotFile = File(p.join(tempDir.path, screenshotRelativePath));
    await screenshotFile.parent.create(recursive: true);
    await screenshotFile.writeAsBytes(_validPngBytes);
  }
  if (recordingRelativePath != null) {
    final recordingFile = File(p.join(tempDir.path, recordingRelativePath));
    await recordingFile.parent.create(recursive: true);
    await recordingFile.writeAsBytes(_validMp4Bytes);
  }
  return tempDir;
}

Future<void> _deleteDir(Directory dir) async {
  if (dir.existsSync()) {
    await dir.delete(recursive: true);
  }
}

final List<int> _validPngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAIAAAD91JpzAAAACXBIWXMAAAABAAAAAQBPJcTWAAAADklEQVR4nGNkAAMWCAUAADgABkRoBWYAAAAASUVORK5CYII=',
);

final List<int> _validMp4Bytes = base64Decode(
  'AAAAIGZ0eXBpc29tAAACAGlzb21pc28yYXZjMW1wNDEAAAAIZnJlZQAAAuVtZGF0AAACrgYF//+q3EXpvebZSLeWLNgg2SPu73gyNjQgLSBjb3JlIDE2NSByMzIyMiBiMzU2MDVhIC0gSC4yNjQvTVBFRy00IEFWQyBjb2RlYyAtIENvcHlsZWZ0IDIwMDMtMjAyNSAtIGh0dHA6Ly93d3cudmlkZW9sYW4ub3JnL3gyNjQuaHRtbCAtIG9wdGlvbnM6IGNhYmFjPTEgcmVmPTMgZGVibG9jaz0xOjA6MCBhbmFseXNlPTB4MzoweDExMyBtZT1oZXggc3VibWU9NyBwc3k9MSBwc3lfcmQ9MS4wMDowLjAwIG1peGVkX3JlZj0xIG1lX3JhbmdlPTE2IGNocm9tYV9tZT0xIHRyZWxsaXM9MSA4eDhkY3Q9MSBjcW09MCBkZWFkem9uZT0yMSwxMSBmYXN0X3Bza2lwPTEgY2hyb21hX3FwX29mZnNldD0tMiB0aHJlYWRzPTEgbG9va2FoZWFkX3RocmVhZHM9MSBzbGljZWRfdGhyZWFkcz0wIG5yPTAgZGVjaW1hdGU9MSBpbnRlcmxhY2VkPTAgYmx1cmF5X2NvbXBhdD0wIGNvbnN0cmFpbmVkX2ludHJhPTAgYmZyYW1lcz0zIGJfcHlyYW1pZD0yIGJfYWRhcHQ9MSBiX2JpYXM9MCBkaXJlY3Q9MSB3ZWlnaHRiPTEgb3Blbl9nb3A9MCB3ZWlnaHRwPTIga2V5aW50PTI1MCBrZXlpbnRfbWluPTI1IHNjZW5lY3V0PTQwIGludHJhX3JlZnJlc2g9MCByY19sb29rYWhlYWQ9NDAgcmM9Y3JmIG1idHJlZT0xIGNyZj0yMy4wIHFjb21wPTAuNjAgcXBtaW49MCBxcG1heD02OSBxcHN0ZXA9NCBpcF9yYXRpbz0xLjQwIGFxPTE6MS4wMACAAAAAD2WIhAAz//727L4FNhTIwQAAAAhBmiJsQr/+wAAAAAgBnkF5Cv/EgQAAA1xtb292AAAAbG12aGQAAAAAAAAAAAAAAAAAAAPoAAAAeAABAAABAAAAAAAAAAAAAAAAAQAAAAAAAAAAAAAAAAAAAAEAAAAAAAAAAAAAAAAAAEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACAAACh3RyYWsAAABcdGtoZAAAAAMAAAAAAAAAAAAAAAEAAAAAAAAAeAAAAAAAAAAAAAAAAAAAAAAAAQAAAAAAAAAAAAAAAAAAAAEAAAAAAAAAAAAAAAAAAEAAAAAAEAAAABAAAAAAACRlZHRzAAAAHGVsc3QAAAAAAAAAAQAAAHgAAAQAAAEAAAAAAf9tZGlhAAAAIG1kaGQAAAAAAAAAAAAAAAAAADIAAAAIAFXEAAAAAAAtaGRscgAAAAAAAAAAdmlkZQAAAAAAAAAAAAAAAFZpZGVvSGFuZGxlcgAAAAGqbWluZgAAABR2bWhkAAAAAQAAAAAAAAAAAAAAJGRpbmYAAAAcZHJlZgAAAAAAAAABAAAADHVybCAAAAABAAABanN0YmwAAAC+c3RzZAAAAAAAAAABAAAArmF2YzEAAAAAAAAAAQAAAAAAAAAAAAAAAAAAAAAAEAAQAEgAAABIAAAAAAAAAAEVTGF2YzYyLjExLjEwMCBsaWJ4MjY0AAAAAAAAAAAAAAAY//8AAAA0YXZjQwFkAAr/4QAXZ2QACqzZXsBEAAADAAQAAAMAyDxIllgBAAZo6+PLIsD9+PgAAAAAEHBhc3AAAAABAAAAAQAAABRidHJ0AAAAAAAAvuIAAAAAAAAAGHN0dHMAAAAAAAAAAQAAAAMAAAIAAAAAFHN0c3MAAAAAAAAAAQAAAAEAAAAoY3R0cwAAAAAAAAADAAAAAQAABAAAAAABAAAGAAAAAAEAAAIAAAAAHHN0c2MAAAAAAAAAAQAAAAEAAAADAAAAAQAAACBzdHN6AAAAAAAAAAAAAAADAAACxQAAAAwAAAAMAAAAFHN0Y28AAAAAAAAAAQAAADAAAABhdWR0YQAAAFltZXRhAAAAAAAAACFoZGxyAAAAAAAAAABtZGlyYXBwbAAAAAAAAAAAAAAAACxpbHN0AAAAJKl0b28AAAAcZGF0YQAAAAEAAAAATGF2ZjYyLjMuMTAw',
);

final List<int> _structuredAcceptancePngBytes = img.encodePng(
  _buildStructuredAcceptanceImage(),
);

final List<int> _contrastAcceptancePngBytes = img.encodePng(
  _buildContrastAcceptanceImage(),
);

img.Image _buildStructuredAcceptanceImage() {
  final image = img.Image(width: 240, height: 480);
  img.fill(image, color: img.ColorRgba8(246, 240, 231, 255));
  img.fillRect(
    image,
    x1: 18,
    y1: 28,
    x2: 220,
    y2: 78,
    color: img.ColorRgba8(24, 78, 70, 255),
  );
  img.fillRect(
    image,
    x1: 18,
    y1: 120,
    x2: 220,
    y2: 126,
    color: img.ColorRgba8(216, 207, 192, 255),
  );
  img.fillRect(
    image,
    x1: 18,
    y1: 180,
    x2: 220,
    y2: 280,
    color: img.ColorRgba8(245, 240, 230, 255),
  );
  img.fillRect(
    image,
    x1: 18,
    y1: 318,
    x2: 220,
    y2: 328,
    color: img.ColorRgba8(24, 78, 70, 255),
  );
  return image;
}

img.Image _buildContrastAcceptanceImage() {
  final image = img.Image(width: 240, height: 480);
  img.fill(image, color: img.ColorRgba8(24, 24, 24, 255));
  img.fillRect(
    image,
    x1: 24,
    y1: 34,
    x2: 216,
    y2: 220,
    color: img.ColorRgba8(122, 45, 18, 255),
  );
  img.fillRect(
    image,
    x1: 24,
    y1: 260,
    x2: 216,
    y2: 430,
    color: img.ColorRgba8(245, 245, 245, 255),
  );
  img.fillRect(
    image,
    x1: 102,
    y1: 70,
    x2: 138,
    y2: 420,
    color: img.ColorRgba8(232, 180, 72, 255),
  );
  return image;
}

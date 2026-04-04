import 'package:flutter_cockpit_devtools/src/application/cockpit_bundle_artifact_paths.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_execute_remote_command_service.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_interactive_result_data.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_read_task_bundle_summary_service.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_run_task_service.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_validate_task_service.dart';
import 'package:test/test.dart';

void main() {
  test('bundle artifact paths omit absent primary artifacts', () {
    final json = CockpitBundleArtifactPaths(
      attachmentPaths: const <String>['/tmp/attachments/a.png'],
      keyframePaths: const <String>['/tmp/keyframes/a.png'],
    ).toJson();

    expect(json.containsKey('primaryScreenshotPath'), isFalse);
    expect(json.containsKey('primaryRecordingPath'), isFalse);
    expect(json['attachmentPaths'], <String>['/tmp/attachments/a.png']);
    expect(json['keyframePaths'], <String>['/tmp/keyframes/a.png']);
  });

  test('bundle evidence keyframe omits missing linked screenshot fields', () {
    const keyframe = CockpitBundleEvidenceKeyframe(
      ref: 'keyframes/acceptance_midpoint.png',
      path: '/tmp/out/keyframes/acceptance_midpoint.png',
      label: 'midpoint',
      offsetMs: 2100,
    );

    final json = keyframe.toJson();
    expect(json.containsKey('linkedScreenshotRef'), isFalse);
    expect(json.containsKey('linkedScreenshotPath'), isFalse);
  });

  test('execute remote command result omits optional null sections', () {
    final json = const CockpitExecuteRemoteCommandResult(
      command: CockpitInteractiveCommandCore(
        commandId: 'tap-inbox',
        commandType: 'tap',
        success: true,
        durationMs: 120,
        usedCaptureFallback: false,
      ),
      artifacts: <CockpitInteractiveArtifactDescriptor>[],
    ).toJson();

    expect(json.containsKey('uiSummary'), isFalse);
    expect(json.containsKey('snapshot'), isFalse);
    expect(json.containsKey('diagnostics'), isFalse);
    expect(json.containsKey('delta'), isFalse);
    expect(json.containsKey('snapshotRef'), isFalse);
    expect(json.containsKey('sessionHandle'), isFalse);
    expect(json.containsKey('effectiveSnapshotOptions'), isFalse);
  });

  test('run task and validate task results omit null optional sections', () {
    final runTaskJson = const CockpitRunTaskResult(
      classification: CockpitRunTaskClassification.completed,
      recommendedNextStep: 'deliver',
    ).toJson();
    expect(runTaskJson.containsKey('sessionHandle'), isFalse);
    expect(runTaskJson.containsKey('preflightStatus'), isFalse);
    expect(runTaskJson.containsKey('blockedReason'), isFalse);
    expect(runTaskJson.containsKey('bundleSummary'), isFalse);

    final validateTaskJson = const CockpitValidateTaskResult(
      classification: CockpitValidationClassification.completed,
      recommendedNextStep: 'deliver',
    ).toJson();
    expect(validateTaskJson.containsKey('runTaskResult'), isFalse);
    expect(validateTaskJson.containsKey('bundleSummary'), isFalse);
    expect(validateTaskJson.containsKey('blockedReason'), isFalse);
  });
}

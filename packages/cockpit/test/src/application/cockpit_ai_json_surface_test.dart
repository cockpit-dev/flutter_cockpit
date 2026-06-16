import 'package:cockpit/src/application/cockpit_bundle_artifact_paths.dart';
import 'package:cockpit/src/application/cockpit_app_handle.dart';
import 'package:cockpit/src/application/cockpit_execute_remote_command_service.dart';
import 'package:cockpit/src/application/cockpit_interactive_result_data.dart';
import 'package:cockpit/src/application/cockpit_list_apps_service.dart';
import 'package:cockpit/src/application/cockpit_read_task_bundle_summary_service.dart';
import 'package:cockpit/src/application/cockpit_run_task_service.dart';
import 'package:cockpit/src/application/cockpit_stop_app_service.dart';
import 'package:cockpit/src/development/cockpit_development_probe.dart';
import 'package:cockpit/src/development/cockpit_development_probe_delta.dart';
import 'package:cockpit/src/development/cockpit_development_session_status.dart';
import 'package:cockpit/src/application/cockpit_validate_task_service.dart';
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

  test('high-frequency app status models omit null optional fields', () {
    final appSummaryJson = CockpitAppSummary(
      appId: 'dev.example.app',
      mode: CockpitAppMode.development,
      platform: 'macos',
      deviceId: 'macos',
      projectDir: '/workspace/app',
      target: 'cockpit/main.dart',
      baseUrl: 'http://127.0.0.1:57331',
      updatedAt: DateTime.utc(2026, 4, 5),
    ).toJson();
    expect(appSummaryJson.containsKey('platformAppId'), isFalse);
    expect(appSummaryJson.containsKey('state'), isFalse);
    expect(appSummaryJson.containsKey('lastError'), isFalse);

    final developmentStatusJson = CockpitDevelopmentSessionStatus(
      developmentSessionId: 'dev-session-1',
      state: CockpitDevelopmentSessionState.ready,
      appReachable: true,
      remoteSessionReachable: true,
      reloadGeneration: 2,
      lastStatusAt: DateTime.utc(2026, 4, 5),
    ).toJson();
    expect(developmentStatusJson.containsKey('lastReloadMode'), isFalse);
    expect(developmentStatusJson.containsKey('lastReloadSucceeded'), isFalse);
    expect(developmentStatusJson.containsKey('lastError'), isFalse);

    final stopStatusJson = const CockpitAppStopStatus(
      mode: CockpitAppMode.automation,
      state: 'stopped',
      appReachable: false,
      remoteSessionReachable: false,
    ).toJson();
    expect(stopStatusJson.containsKey('lastError'), isFalse);
  });

  test('development probe models omit null optional fields', () {
    final probeJson = CockpitDevelopmentProbe(
      probeId: 'probe-1',
      sessionId: 'dev-session-1',
      reloadGeneration: 3,
      capturedAt: DateTime.utc(2026, 4, 5),
      reason: CockpitDevelopmentProbeReason.manual,
      profile: CockpitDevelopmentProbeProfile.quick,
      routeName: '/home',
    ).toJson();
    expect(probeJson.containsKey('checkpoint'), isFalse);

    final deltaJson = const CockpitDevelopmentProbeDelta(
      fromProbeId: 'probe-before',
      toProbeId: 'probe-after',
      reloadGenerationChanged: false,
      routeChanged: true,
      focusChanged: false,
      overlayChanged: false,
      visualChanged: false,
      screenshotChanged: false,
    ).toJson();
    expect(deltaJson.containsKey('changeSummary'), isFalse);
  });
}

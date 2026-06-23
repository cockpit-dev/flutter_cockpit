import '../application/cockpit_run_remote_control_script_service.dart';

Map<String, Object?> cockpitRunScriptResultPayload({
  required String commandName,
  required CockpitRunRemoteControlScriptResult result,
  required String outputRoot,
}) {
  final manifest = result.manifest;
  final bundleDir = result.bundleDir.path;
  final readSummaryCommand =
      'dart run cockpit read-task-bundle-summary --bundle-dir ${_shellQuote(bundleDir)}';
  return <String, Object?>{
    'command': commandName,
    'status': manifest.status.name,
    'recommendedNextStep': readSummaryCommand,
    'bundleDir': bundleDir,
    'sessionId': manifest.sessionId,
    'taskId': manifest.taskId,
    'platform': manifest.platform,
    'devtoolsCommand':
        'dart run cockpit devtools --history-root ${_shellQuote(outputRoot)} --scope ${_shellQuote(manifest.sessionId)}',
    'bundleSummary': <String, Object?>{
      'bundleDir': bundleDir,
      'manifest': manifest.toJson(),
      'handoff': result.handoff,
      'delivery': result.delivery,
      'artifactPaths': result.artifactPaths.toJson(),
      'evidenceSummary': <String, Object?>{
        'status': manifest.status.name,
        'commandCount': manifest.commandCount,
        'failureCount': manifest.failureCount,
        'screenshotCount': manifest.screenshotCount,
        'recordingCount': manifest.recordingCount,
        'keyframeCount': result.artifactPaths.keyframePaths.length,
        'runtimeErrorCount': manifest.runtimeErrorCount,
        'runtimeWarningCount': manifest.runtimeWarningCount,
      },
    },
  };
}

Map<String, Object?> cockpitRunScriptFailureDetails({
  required CockpitRunRemoteControlScriptResult result,
  required String outputRoot,
}) {
  final manifest = result.manifest;
  final bundleDir = result.bundleDir.path;
  return <String, Object?>{
    'status': manifest.status.name,
    'bundleDir': bundleDir,
    'sessionId': manifest.sessionId,
    'taskId': manifest.taskId,
    'platform': manifest.platform,
    if (manifest.failureSummary != null)
      'failureSummary': manifest.failureSummary,
    'recommendedNextStep':
        'dart run cockpit read-task-bundle-summary --bundle-dir ${_shellQuote(bundleDir)}',
    'devtoolsCommand':
        'dart run cockpit devtools --history-root ${_shellQuote(outputRoot)} --scope ${_shellQuote(manifest.sessionId)}',
  };
}

String _shellQuote(String value) {
  if (RegExp(r'^[A-Za-z0-9_./:=@+-]+$').hasMatch(value)) {
    return value;
  }
  return "'${value.replaceAll("'", "'\\''")}'";
}

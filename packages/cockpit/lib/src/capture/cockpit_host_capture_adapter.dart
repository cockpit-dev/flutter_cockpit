// ignore_for_file: deprecated_member_use

import 'dart:io';

import 'package:flutter_cockpit_protocol/flutter_cockpit_protocol.dart';
import 'package:path/path.dart' as p;

import '../adapters/cockpit_capture_adapter.dart';

typedef CockpitCaptureProcessStarter =
    Future<Process> Function(String executable, List<String> arguments);
typedef CockpitCaptureProcessRunner =
    Future<ProcessResult> Function(String executable, List<String> arguments);
typedef CockpitCaptureTempFileFactory = Future<File> Function(String basename);

abstract interface class CockpitHostCaptureAdapter
    implements CockpitCaptureAdapter {}

Future<File> cockpitCreateCaptureTempFile(String basename) async {
  final directory = await Directory.systemTemp.createTemp(
    'flutter_cockpit_capture_',
  );
  return File(p.join(directory.path, basename));
}

CockpitArtifactRef cockpitCaptureArtifactForRequest(
  CockpitScreenshotRequest request, {
  DateTime? now,
}) {
  return CockpitArtifactRef(
    role: 'screenshot',
    relativePath: cockpitScreenshotRelativePathFor(request, now: now),
  );
}

String cockpitCaptureFileName(String captureName) {
  final basename = cockpitSanitizeArtifactNameToken(
    captureName,
    fallback: 'capture',
  );
  return '$basename.png';
}

CockpitCommandExecution cockpitFailedCaptureExecution({
  required CockpitCommand command,
  required int durationMs,
  required String message,
  Map<String, Object?> details = const <String, Object?>{},
}) {
  return CockpitCommandExecution(
    result: CockpitCommandResult(
      success: false,
      commandId: command.commandId,
      commandType: command.commandType,
      durationMs: durationMs,
      requestedCaptureProfile: _captureProfileFor(command.screenshotRequest),
      error: CockpitCommandError.captureFailed(
        message: message,
        details: details,
      ),
    ),
  );
}

CockpitCommandExecution cockpitSuccessfulHostCaptureExecution({
  required CockpitCommand command,
  required CockpitArtifactRef artifact,
  required int durationMs,
  Map<String, Object?>? snapshot,
  required String sourceFilePath,
}) {
  return CockpitCommandExecution(
    result: CockpitCommandResult(
      success: true,
      commandId: command.commandId,
      commandType: command.commandType,
      durationMs: durationMs,
      artifacts: <CockpitArtifactRef>[artifact],
      snapshot: snapshot,
      requestedCaptureProfile: _captureProfileFor(command.screenshotRequest),
      resolvedCaptureKind: CockpitCaptureKind.nativeAcceptance,
    ),
    artifactSourcePaths: <String, String>{
      artifact.relativePath: sourceFilePath,
    },
  );
}

CockpitCaptureProfile? _captureProfileFor(CockpitScreenshotRequest? request) {
  if (request == null) {
    return null;
  }
  return request.reason == CockpitScreenshotReason.acceptance
      ? CockpitCaptureProfile.acceptance
      : CockpitCaptureProfile.diagnostic;
}

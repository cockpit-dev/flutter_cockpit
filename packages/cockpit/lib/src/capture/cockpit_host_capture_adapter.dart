// ignore_for_file: deprecated_member_use

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_cockpit_protocol/flutter_cockpit_protocol.dart';
import 'package:path/path.dart' as p;

import '../adapters/cockpit_capture_adapter.dart';
import 'cockpit_screenshot_inspector.dart';

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
      resolvedCaptureKind: CockpitCaptureKind.hostSystem,
    ),
    artifactSourcePaths: <String, String>{
      artifact.relativePath: sourceFilePath,
    },
  );
}

Future<CockpitCommandExecution> cockpitValidateHostCaptureOutput({
  required CockpitCommand command,
  required CockpitArtifactRef artifact,
  required int durationMs,
  required File outputFile,
  required String captureDescription,
  Map<String, Object?> details = const <String, Object?>{},
}) async {
  late final Uint8List bytes;
  try {
    if (!await outputFile.exists()) {
      return cockpitFailedCaptureExecution(
        command: command,
        durationMs: durationMs,
        message: '$captureDescription did not produce a PNG artifact.',
        details: <String, Object?>{...details, 'artifactStatus': 'missing'},
      );
    }
    bytes = await outputFile.readAsBytes();
  } on Object catch (error) {
    await _deleteInvalidCaptureOutput(outputFile);
    return cockpitFailedCaptureExecution(
      command: command,
      durationMs: durationMs,
      message: '$captureDescription produced an unreadable PNG artifact.',
      details: <String, Object?>{
        ...details,
        'artifactStatus': 'unreadable',
        'error': error.toString(),
      },
    );
  }

  try {
    await const CockpitImageScreenshotInspector().inspect(
      bytes,
      requireVisiblePixels:
          command.screenshotRequest?.reason ==
          CockpitScreenshotReason.acceptance,
    );
  } on CockpitScreenshotValidationException catch (error) {
    await _deleteInvalidCaptureOutput(outputFile);
    return cockpitFailedCaptureExecution(
      command: command,
      durationMs: durationMs,
      message: error.code == 'screenshotEmpty'
          ? '$captureDescription produced an empty PNG artifact.'
          : '$captureDescription produced an invalid PNG artifact.',
      details: <String, Object?>{
        ...details,
        'validationCode': error.code,
        'validationMessage': error.message,
      },
    );
  }

  return cockpitSuccessfulHostCaptureExecution(
    command: command,
    artifact: artifact,
    durationMs: durationMs,
    sourceFilePath: outputFile.path,
  );
}

Future<void> _deleteInvalidCaptureOutput(File outputFile) async {
  try {
    if (await outputFile.exists()) {
      await outputFile.delete();
    }
  } on Object {
    // Validation failure remains authoritative if cleanup also fails.
  }
}

CockpitCaptureProfile? _captureProfileFor(CockpitScreenshotRequest? request) {
  if (request == null) {
    return null;
  }
  if (request.profile case final profile?) {
    return profile;
  }
  return request.reason == CockpitScreenshotReason.acceptance
      ? CockpitCaptureProfile.acceptance
      : CockpitCaptureProfile.diagnostic;
}

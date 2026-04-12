// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:io';

import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:path/path.dart' as p;

import '../adapters/cockpit_recording_adapter.dart';

typedef CockpitRecordingProcessStarter = Future<Process> Function(
    String executable, List<String> arguments);
typedef CockpitRecordingProcessRunner = Future<ProcessResult> Function(
    String executable, List<String> arguments);
typedef CockpitRecordingTempFileFactory = Future<File> Function(
    String basename);

abstract interface class CockpitHostRecordingAdapter
    implements CockpitRecordingAdapter {}

final class CockpitHostRecordingRuntimeSession {
  const CockpitHostRecordingRuntimeSession({
    required this.process,
    required this.request,
    required this.outputFile,
    required this.stderrSubscription,
    required this.stopwatch,
  });

  final Process process;
  final CockpitRecordingRequest request;
  final File outputFile;
  final StreamSubscription<String>? stderrSubscription;
  final Stopwatch? stopwatch;
}

final Map<String, CockpitHostRecordingRuntimeSession>
    _activeHostRecordingSessions =
    <String, CockpitHostRecordingRuntimeSession>{};

CockpitHostRecordingRuntimeSession? cockpitReadActiveHostRecordingSession(
  String key,
) {
  return _activeHostRecordingSessions[key];
}

void cockpitStoreActiveHostRecordingSession(
  String key,
  CockpitHostRecordingRuntimeSession session,
) {
  _activeHostRecordingSessions[key] = session;
}

void cockpitClearActiveHostRecordingSession(String key) {
  _activeHostRecordingSessions.remove(key);
}

Future<File> cockpitCreateRecordingTempFile(String basename) async {
  final directory = await Directory.systemTemp.createTemp(
    'flutter_cockpit_recording_',
  );
  return File(p.join(directory.path, basename));
}

CockpitArtifactRef cockpitRecordingArtifactForName(String recordingName) {
  return CockpitArtifactRef(
    role: 'recording',
    relativePath: 'recordings/${cockpitRecordingFileName(recordingName)}',
  );
}

String cockpitRecordingFileName(String recordingName) {
  final sanitized = recordingName.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
  final basename = sanitized.isEmpty ? 'recording' : sanitized;
  return '$basename.mp4';
}

Future<bool> cockpitWaitForNonEmptyFile(
  File file, {
  required Duration timeout,
  Duration pollInterval = const Duration(milliseconds: 100),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (file.existsSync() && file.lengthSync() > 0) {
      return true;
    }
    await Future<void>.delayed(pollInterval);
  }
  return file.existsSync() && file.lengthSync() > 0;
}

Future<bool> cockpitWaitForStableFile(
  File file, {
  required Duration timeout,
  Duration pollInterval = const Duration(milliseconds: 100),
  Duration stableWindow = const Duration(milliseconds: 400),
}) async {
  final deadline = DateTime.now().add(timeout);
  int? lastLength;
  DateTime? stableSince;

  while (DateTime.now().isBefore(deadline)) {
    if (file.existsSync() && file.lengthSync() > 0) {
      final currentLength = file.lengthSync();
      if (lastLength == currentLength) {
        stableSince ??= DateTime.now();
        if (DateTime.now().difference(stableSince) >= stableWindow) {
          return true;
        }
      } else {
        lastLength = currentLength;
        stableSince = DateTime.now();
      }
    }
    await Future<void>.delayed(pollInterval);
  }

  if (!file.existsSync() || file.lengthSync() <= 0) {
    return false;
  }
  return lastLength == file.lengthSync();
}

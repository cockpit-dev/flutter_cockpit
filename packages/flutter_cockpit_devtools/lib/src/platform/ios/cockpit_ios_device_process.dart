import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

typedef CockpitIosDeviceProcessRunner =
    Future<ProcessResult> Function(
      String executable,
      List<String> arguments, {
      String? workingDirectory,
    });

final class CockpitIosDeviceProcessTerminator {
  CockpitIosDeviceProcessTerminator({
    CockpitIosDeviceProcessRunner processRunner = _runProcess,
    String Function()? tempDirectoryPathProvider,
  }) : _processRunner = processRunner,
       _tempDirectoryPathProvider =
           tempDirectoryPathProvider ?? (() => Directory.systemTemp.path);

  final CockpitIosDeviceProcessRunner _processRunner;
  final String Function() _tempDirectoryPathProvider;

  Future<bool> terminateApp({
    required String deviceId,
    required String bundleId,
  }) async {
    final pids = await findPids(deviceId: deviceId, bundleId: bundleId);
    if (pids.isEmpty) {
      return false;
    }

    var terminated = false;
    for (final pid in pids) {
      final result = await _processRunner('xcrun', <String>[
        'devicectl',
        'device',
        'process',
        'terminate',
        '--device',
        deviceId,
        '--pid',
        '$pid',
        '--kill',
      ]);
      if (result.exitCode == 0) {
        terminated = true;
      }
    }
    return terminated;
  }

  Future<List<int>> findPids({
    required String deviceId,
    required String bundleId,
  }) async {
    final baseDirectory = Directory(_tempDirectoryPathProvider());
    await baseDirectory.create(recursive: true);
    final outputDirectory = await baseDirectory.createTemp(
      'flutter_cockpit_ios_processes_${_safeFileComponent(deviceId)}_',
    );
    final outputFile = File(p.join(outputDirectory.path, 'processes.json'));

    try {
      final result = await _processRunner('xcrun', <String>[
        'devicectl',
        'device',
        'info',
        'processes',
        '--device',
        deviceId,
        '--json-output',
        outputFile.path,
      ]);
      if (result.exitCode != 0 || !outputFile.existsSync()) {
        return const <int>[];
      }

      final decoded = jsonDecode(await outputFile.readAsString());
      final pids = <int>{};
      _collectMatchingProcessIds(decoded, bundleId, pids);
      return pids.toList(growable: false)..sort();
    } finally {
      if (outputDirectory.existsSync()) {
        try {
          await outputDirectory.delete(recursive: true);
        } on Object {
          // Best-effort cleanup for temp process listings.
        }
      }
    }
  }

  void _collectMatchingProcessIds(
    Object? node,
    String bundleId,
    Set<int> pids,
  ) {
    if (node is Map<Object?, Object?>) {
      final pid = _extractPid(node);
      if (pid != null && _containsBundleId(node, bundleId)) {
        pids.add(pid);
      }
      for (final value in node.values) {
        _collectMatchingProcessIds(value, bundleId, pids);
      }
      return;
    }
    if (node is List<Object?>) {
      for (final entry in node) {
        _collectMatchingProcessIds(entry, bundleId, pids);
      }
    }
  }

  int? _extractPid(Map<Object?, Object?> json) {
    for (final entry in json.entries) {
      final key = '${entry.key}'.toLowerCase();
      if (key != 'pid' && key != 'processidentifier') {
        continue;
      }
      final value = entry.value;
      if (value is int) {
        return value;
      }
      if (value is String) {
        return int.tryParse(value.trim());
      }
    }
    return null;
  }

  bool _containsBundleId(Object? node, String bundleId) {
    if (node is Map<Object?, Object?>) {
      for (final entry in node.entries) {
        final key = '${entry.key}'.toLowerCase();
        final value = entry.value;
        if ((key == 'bundleidentifier' ||
                key == 'bundleid' ||
                key == 'identifier') &&
            value is String &&
            value.trim() == bundleId) {
          return true;
        }
        if (_containsBundleId(value, bundleId)) {
          return true;
        }
      }
      return false;
    }
    if (node is List<Object?>) {
      for (final entry in node) {
        if (_containsBundleId(entry, bundleId)) {
          return true;
        }
      }
      return false;
    }
    return node is String && node.trim() == bundleId;
  }

  static Future<ProcessResult> _runProcess(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  }) {
    return Process.run(
      executable,
      arguments,
      workingDirectory: workingDirectory,
    );
  }
}

String _safeFileComponent(String value) {
  return value.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
}

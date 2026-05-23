import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

typedef CockpitIosDeviceConnectionProcessRunner =
    Future<ProcessResult> Function(
      String executable,
      List<String> arguments, {
      String? workingDirectory,
    });

bool cockpitLooksLikeIosSimulatorDeviceId(String deviceId) {
  final normalized = deviceId.trim();
  return RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  ).hasMatch(normalized);
}

final class CockpitIosDeviceConnection {
  const CockpitIosDeviceConnection({
    required this.isPhysical,
    this.tunnelIpAddress,
  });

  final bool isPhysical;
  final String? tunnelIpAddress;

  bool get hasReachableTunnel =>
      isPhysical &&
      tunnelIpAddress != null &&
      tunnelIpAddress!.trim().isNotEmpty;

  factory CockpitIosDeviceConnection.fromDevicectlJson(
    Map<String, Object?> json,
  ) {
    final connectionProperties =
        json['connectionProperties'] as Map<Object?, Object?>?;
    final hardwareProperties =
        json['hardwareProperties'] as Map<Object?, Object?>?;
    final reality = '${hardwareProperties?['reality'] ?? ''}'.trim();
    final tunnelIpAddress = '${connectionProperties?['tunnelIPAddress'] ?? ''}'
        .trim();
    return CockpitIosDeviceConnection(
      isPhysical: reality == 'physical',
      tunnelIpAddress: tunnelIpAddress.isEmpty ? null : tunnelIpAddress,
    );
  }
}

final class CockpitIosDeviceConnectionProbe {
  CockpitIosDeviceConnectionProbe({
    CockpitIosDeviceConnectionProcessRunner processRunner = _runProcess,
    String Function()? tempDirectoryPathProvider,
  }) : _processRunner = processRunner,
       _tempDirectoryPathProvider =
           tempDirectoryPathProvider ?? (() => Directory.systemTemp.path);

  final CockpitIosDeviceConnectionProcessRunner _processRunner;
  final String Function() _tempDirectoryPathProvider;

  Future<CockpitIosDeviceConnection?> probe(String deviceId) async {
    final baseDirectory = Directory(_tempDirectoryPathProvider());
    await baseDirectory.create(recursive: true);
    final outputDirectory = await baseDirectory.createTemp(
      'flutter_cockpit_ios_device_${_safeFileComponent(deviceId)}_',
    );
    final outputFile = File(p.join(outputDirectory.path, 'device.json'));
    try {
      final result = await _processRunner('xcrun', <String>[
        'devicectl',
        'device',
        'info',
        'details',
        '--device',
        deviceId,
        '--json-output',
        outputFile.path,
      ]);
      if (result.exitCode != 0 || !outputFile.existsSync()) {
        return null;
      }

      final decoded = jsonDecode(await outputFile.readAsString());
      if (decoded is! Map<Object?, Object?>) {
        return null;
      }
      final resultJson = decoded['result'];
      if (resultJson is! Map<Object?, Object?>) {
        return null;
      }
      return CockpitIosDeviceConnection.fromDevicectlJson(
        Map<String, Object?>.from(resultJson),
      );
    } finally {
      if (outputDirectory.existsSync()) {
        try {
          await outputDirectory.delete(recursive: true);
        } on Object {
          // Best-effort cleanup for temp device detail probes.
        }
      }
    }
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

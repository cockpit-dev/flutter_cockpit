import 'dart:convert';

import '../infrastructure/cockpit_process_manager.dart';
import '../infrastructure/cockpit_sdk_environment.dart';
import 'cockpit_application_service_exception.dart';

final class CockpitLaunchTarget {
  const CockpitLaunchTarget({
    required this.id,
    required this.name,
    required this.platformType,
    required this.emulator,
    required this.ephemeral,
    this.sdk,
  });

  final String id;
  final String name;
  final String platformType;
  final bool emulator;
  final bool ephemeral;
  final String? sdk;

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'name': name,
        'platformType': platformType,
        'emulator': emulator,
        'ephemeral': ephemeral,
        'sdk': sdk,
      };
}

final class CockpitListLaunchTargetsResult {
  const CockpitListLaunchTargetsResult({required this.targets});

  final List<CockpitLaunchTarget> targets;

  Map<String, Object?> toJson() => <String, Object?>{
        'targets':
            targets.map((target) => target.toJson()).toList(growable: false),
      };
}

final class CockpitListLaunchTargetsService {
  CockpitListLaunchTargetsService({
    CockpitProcessManager? processManager,
    CockpitSdkEnvironment? sdkEnvironment,
  })  : _processManager = processManager ?? const LocalCockpitProcessManager(),
        _sdkEnvironment = sdkEnvironment ?? const CockpitSdkEnvironment();

  final CockpitProcessManager _processManager;
  final CockpitSdkEnvironment _sdkEnvironment;

  Future<CockpitListLaunchTargetsResult> list() async {
    final result = await _processManager.run(
      _sdkEnvironment.flutterExecutable,
      const <String>['devices', '--machine'],
    );
    if (result.exitCode != 0) {
      throw CockpitApplicationServiceException(
        code: 'listLaunchTargetsFailed',
        message: 'Unable to list Flutter launch targets.',
        details: <String, Object?>{
          'exitCode': result.exitCode,
          'stdout': '${result.stdout}',
          'stderr': '${result.stderr}',
        },
      );
    }

    final decoded = jsonDecode('${result.stdout}');
    if (decoded is! List<Object?>) {
      throw const CockpitApplicationServiceException(
        code: 'invalidLaunchTargetsOutput',
        message: 'Flutter devices output was not a JSON list.',
      );
    }

    final targets = decoded
        .whereType<Map<Object?, Object?>>()
        .map((item) => Map<String, Object?>.from(item))
        .map(
          (item) => CockpitLaunchTarget(
            id: item['id'] as String? ?? '',
            name: item['name'] as String? ?? '',
            platformType: item['platformType'] as String? ?? '',
            emulator: item['emulator'] as bool? ?? false,
            ephemeral: item['ephemeral'] as bool? ?? false,
            sdk: item['sdk'] as String?,
          ),
        )
        .where((target) => target.id.isNotEmpty && target.name.isNotEmpty)
        .toList(growable: false);

    return CockpitListLaunchTargetsResult(
      targets: List<CockpitLaunchTarget>.unmodifiable(targets),
    );
  }
}

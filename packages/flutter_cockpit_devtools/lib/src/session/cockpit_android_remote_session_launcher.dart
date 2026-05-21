import 'dart:async';
// ignore_for_file: deprecated_member_use

import 'dart:convert';
import 'dart:io';

import '../remote/cockpit_android_port_forwarder.dart';
import 'cockpit_remote_session_handle.dart';
import 'cockpit_remote_session_launch_options.dart';
import 'cockpit_remote_session_launcher.dart';
import 'cockpit_session_path.dart';
import 'package:path/path.dart' as p;

typedef CockpitWorkingDirectoryProcessRunner = Future<ProcessResult> Function(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
});

typedef CockpitAndroidBuildArtifactResolver
    = Future<CockpitAndroidBuildArtifact> Function({
  required String projectDir,
  required String buildDirectory,
  String? flavor,
});

final class CockpitAndroidBuildArtifact {
  const CockpitAndroidBuildArtifact({
    required this.applicationId,
    required this.apkPath,
  });

  final String applicationId;
  final String apkPath;
}

final class CockpitAndroidRemoteSessionLauncher
    implements CockpitRemoteSessionLauncher {
  CockpitAndroidRemoteSessionLauncher({
    CockpitWorkingDirectoryProcessRunner processRunner = _runProcess,
    CockpitAndroidPortForwarder portForwarder =
        const CockpitAndroidPortForwarder(),
    CockpitAndroidBuildArtifactResolver buildArtifactResolver =
        _resolveAndroidBuildArtifact,
    CockpitRemoteSessionStatusReader statusReader =
        cockpitReadRemoteSessionStatus,
    CockpitFlutterVersionReader flutterVersionReader =
        cockpitReadActiveFlutterVersion,
    DateTime Function()? now,
  })  : _processRunner = processRunner,
        _portForwarder = portForwarder,
        _buildArtifactResolver = buildArtifactResolver,
        _statusReader = statusReader,
        _flutterVersionReader = flutterVersionReader,
        _now = now ?? DateTime.now;

  final CockpitWorkingDirectoryProcessRunner _processRunner;
  final CockpitAndroidPortForwarder _portForwarder;
  final CockpitAndroidBuildArtifactResolver _buildArtifactResolver;
  final CockpitRemoteSessionStatusReader _statusReader;
  final CockpitFlutterVersionReader _flutterVersionReader;
  final DateTime Function() _now;

  @override
  Future<CockpitRemoteSessionHandle> launch(
    CockpitRemoteSessionLaunchOptions options,
  ) async {
    if (options.platform != 'android') {
      throw StateError(
        'CockpitAndroidRemoteSessionLauncher only supports android options.',
      );
    }

    final deadline = _now().add(options.launchTimeout);
    final flutterVersion =
        options.flutterVersion ?? await _flutterVersionReader();
    final flutterExecutable =
        options.flutterExecutable ?? cockpitFlutterExecutable();
    await _runRequired(
      flutterExecutable,
      <String>[
        'build',
        'apk',
        '--debug',
        '--target',
        options.target,
        if (options.flavor case final flavor?
            when flavor.isNotEmpty) ...<String>['--flavor', flavor],
        '--dart-define=FLUTTER_PILOT_REMOTE_ENABLED=true',
        '--dart-define=FLUTTER_PILOT_REMOTE_HOST=127.0.0.1',
        '--dart-define=FLUTTER_PILOT_REMOTE_PORT=${options.sessionPort}',
        '--dart-define=FLUTTER_PILOT_FLUTTER_VERSION=$flutterVersion',
      ],
      workingDirectory: options.projectDir,
      timeout: _remaining(deadline),
    );

    final pathContext = cockpitSessionPathContext(options.projectDir);
    final buildDirectory = pathContext.join(options.projectDir, 'build');
    final buildArtifact = await _buildArtifactResolver(
      projectDir: options.projectDir,
      buildDirectory: buildDirectory,
      flavor: options.flavor,
    ).timeout(
      _remaining(deadline),
      onTimeout: () => throw TimeoutException(
        'Resolving Android build artifacts timed out.',
        _remaining(deadline),
      ),
    );

    await _runRequired(
        'adb',
        <String>[
          '-s',
          options.deviceId,
          'install',
          '-r',
          buildArtifact.apkPath,
        ],
        timeout: _remaining(deadline));

    await _runRequired(
        'adb',
        <String>[
          '-s',
          options.deviceId,
          'shell',
          'monkey',
          '-p',
          buildArtifact.applicationId,
          '-c',
          'android.intent.category.LAUNCHER',
          '1',
        ],
        timeout: _remaining(deadline));

    final hostPort = await _portForwarder
        .ensureForwarded(
          deviceId: options.deviceId,
          preferredHostPort: options.sessionPort,
          devicePort: options.sessionPort,
        )
        .timeout(
          _remaining(deadline),
          onTimeout: () => throw TimeoutException(
            'Android port forwarding timed out.',
            _remaining(deadline),
          ),
        );
    final baseUri = Uri.parse('http://127.0.0.1:$hostPort');
    final status = await cockpitWaitForRemoteSessionReady(
      baseUri: baseUri,
      timeout: _remaining(deadline),
      statusReader: _statusReader,
    );

    return CockpitRemoteSessionHandle.fromRemoteStatus(
      projectDir: options.projectDir,
      target: options.target,
      deviceId: options.deviceId,
      appId: buildArtifact.applicationId,
      host: '127.0.0.1',
      hostPort: hostPort,
      devicePort: options.sessionPort,
      status: status,
      launchedAt: _now(),
    );
  }

  Future<void> _runRequired(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    required Duration timeout,
  }) async {
    final result = await _processRunner(
      executable,
      arguments,
      workingDirectory: workingDirectory,
    ).timeout(
      timeout,
      onTimeout: () => throw TimeoutException(
        '$executable ${arguments.join(' ')} timed out.',
        timeout,
      ),
    );
    if (result.exitCode != 0) {
      throw StateError(
        '$executable ${arguments.join(' ')} failed: ${result.stderr ?? result.stdout}',
      );
    }
  }

  Duration _remaining(DateTime deadline) {
    final remaining = deadline.difference(_now());
    if (remaining <= Duration.zero) {
      throw TimeoutException(
        'Android remote session launch timed out before the next stage could start.',
      );
    }
    return remaining;
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

  static Future<CockpitAndroidBuildArtifact> _resolveAndroidBuildArtifact({
    required String projectDir,
    required String buildDirectory,
    String? flavor,
  }) async {
    final pathContext = cockpitSessionPathContext(projectDir);
    final outputRoot =
        Directory(pathContext.join(buildDirectory, 'app', 'outputs'));
    final metadataCandidates = <_AndroidBuildMetadataCandidate>[];
    if (outputRoot.existsSync()) {
      for (final entity in outputRoot.listSync(recursive: true)) {
        if (entity is! File ||
            pathContext.basename(entity.path) != 'output-metadata.json') {
          continue;
        }
        final candidate = await _readAndroidBuildMetadataCandidate(
          file: entity,
          flavor: flavor,
          pathContext: pathContext,
        );
        if (candidate != null) {
          metadataCandidates.add(candidate);
        }
      }
    }
    if (metadataCandidates.isNotEmpty) {
      metadataCandidates.sort(
        (left, right) {
          if (left.score != right.score) {
            return right.score.compareTo(left.score);
          }
          return right.modifiedAt.compareTo(left.modifiedAt);
        },
      );
      final resolved = metadataCandidates.first;
      return CockpitAndroidBuildArtifact(
        applicationId: resolved.applicationId,
        apkPath: resolved.apkPath,
      );
    }

    final flutterApkDirectory = Directory(
      pathContext.join(buildDirectory, 'app', 'outputs', 'flutter-apk'),
    );
    final apkFiles = flutterApkDirectory.existsSync()
        ? flutterApkDirectory
            .listSync()
            .whereType<File>()
            .map((file) => file.path)
            .where((path) => path.toLowerCase().endsWith('.apk'))
            .toList(growable: false)
        : const <String>[];
    final resolvedApkPath = _pickBestApkPath(
      apkPaths: apkFiles,
      flavor: flavor,
    );
    if (resolvedApkPath != null) {
      return CockpitAndroidBuildArtifact(
        applicationId: await _resolveAndroidApplicationIdFromGradle(
          projectDir: projectDir,
        ),
        apkPath: resolvedApkPath,
      );
    }

    throw StateError(
      'Unable to resolve an Android debug APK from $buildDirectory.',
    );
  }

  static Future<_AndroidBuildMetadataCandidate?>
      _readAndroidBuildMetadataCandidate({
    required File file,
    required String? flavor,
    required p.Context pathContext,
  }) async {
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<Object?, Object?>) {
      return null;
    }
    final json = Map<String, Object?>.from(decoded);
    final applicationId = json['applicationId'] as String?;
    final elements = json['elements'] as List<Object?>?;
    if (applicationId == null || elements == null || elements.isEmpty) {
      return null;
    }
    _AndroidBuildMetadataCandidate? bestCandidate;
    final variantName = json['variantName'] as String?;
    for (final element in elements) {
      if (element is! Map<Object?, Object?>) {
        continue;
      }
      final outputFile = element['outputFile'] as String?;
      if (outputFile == null || outputFile.isEmpty) {
        continue;
      }
      final apkPath = pathContext.isAbsolute(outputFile)
          ? outputFile
          : pathContext
              .normalize(pathContext.join(file.parent.path, outputFile));
      final apkFile = File(apkPath);
      if (!apkFile.existsSync()) {
        continue;
      }
      final candidate = _AndroidBuildMetadataCandidate(
        applicationId: applicationId,
        apkPath: apkPath,
        score: _scoreAndroidArtifactCandidate(
          flavor: flavor,
          variantName: variantName,
          path: apkPath,
        ),
        modifiedAt: apkFile.statSync().modified,
      );
      if (bestCandidate == null ||
          candidate.score > bestCandidate.score ||
          (candidate.score == bestCandidate.score &&
              candidate.modifiedAt.isAfter(bestCandidate.modifiedAt))) {
        bestCandidate = candidate;
      }
    }
    return bestCandidate;
  }

  static int _scoreAndroidArtifactCandidate({
    required String? flavor,
    required String? variantName,
    required String path,
  }) {
    final normalizedPath = path.toLowerCase();
    final normalizedVariant = variantName?.toLowerCase() ?? '';
    var score = 0;
    if (normalizedPath.endsWith('.apk')) {
      score += 10;
    }
    if (normalizedPath.contains('debug') ||
        normalizedVariant.contains('debug')) {
      score += 10;
    }
    if (flavor case final selectedFlavor? when selectedFlavor.isNotEmpty) {
      final normalizedFlavor = selectedFlavor.toLowerCase();
      if (normalizedPath.contains(normalizedFlavor) ||
          normalizedVariant.contains(normalizedFlavor)) {
        score += 50;
      }
    }
    return score;
  }

  static String? _pickBestApkPath({
    required List<String> apkPaths,
    required String? flavor,
  }) {
    if (apkPaths.isEmpty) {
      return null;
    }
    final scored = apkPaths
        .map(
          (path) => MapEntry(
            path,
            _scoreAndroidArtifactCandidate(
              flavor: flavor,
              variantName: null,
              path: path,
            ),
          ),
        )
        .toList(growable: false)
      ..sort((left, right) => right.value.compareTo(left.value));
    return scored.first.key;
  }

  static Future<String> _resolveAndroidApplicationIdFromGradle({
    required String projectDir,
  }) async {
    final pathContext = cockpitSessionPathContext(projectDir);
    final candidates = <String>[
      pathContext.join(projectDir, 'android', 'app', 'build.gradle.kts'),
      pathContext.join(projectDir, 'android', 'app', 'build.gradle'),
    ];

    for (final candidate in candidates) {
      final file = File(candidate);
      if (!file.existsSync()) {
        continue;
      }

      final content = await file.readAsString();
      final match = RegExp(
        r'applicationId\s*=\s*"([^"]+)"|applicationId\s+"([^"]+)"',
      ).firstMatch(content);
      if (match != null) {
        return match.group(1) ?? match.group(2)!;
      }
    }

    throw StateError(
      'Unable to resolve Android applicationId from $projectDir/android/app/build.gradle(.kts).',
    );
  }

  static Future<String?> resolveApplicationId({
    required String projectDir,
  }) async {
    final applicationId = await _resolveAndroidApplicationIdFromGradle(
      projectDir: projectDir,
    );
    final normalized = applicationId.trim();
    return normalized.isEmpty ? null : normalized;
  }
}

final class _AndroidBuildMetadataCandidate {
  const _AndroidBuildMetadataCandidate({
    required this.applicationId,
    required this.apkPath,
    required this.score,
    required this.modifiedAt,
  });

  final String applicationId;
  final String apkPath;
  final int score;
  final DateTime modifiedAt;
}

import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;

import 'src/cockpit_demo_platform_verifier.dart';

Future<void> main(List<String> arguments) async {
  final defaultProjectDir = cockpitDemoDefaultProjectDir(
    currentDirectory: Directory.current.path,
    scriptPath: _tryResolveScriptPath(),
  );
  final parser = ArgParser()
    ..addMultiOption(
      'platform',
      allowed: cockpitDemoSupportedVerificationPlatforms,
      defaultsTo: cockpitDemoDefaultVerificationPlatforms,
      help: 'Platforms to verify: android, ios, linux, macos, web, windows.',
    )
    ..addOption(
      'project-dir',
      defaultsTo: defaultProjectDir,
      help:
          'cockpit_demo project directory. Defaults to the example that contains this script.',
    )
    ..addOption(
      'target',
      help: 'Optional Flutter entrypoint passed through to launch-app.',
    )
    ..addOption(
      'output-root',
      defaultsTo: '.dart_tool/cockpit_platforms',
      help: 'Directory where app handles and platform summaries are written.',
    )
    ..addOption(
      'android-emulator-id',
      defaultsTo: 'Pixel_9_Pro',
      help: 'Android emulator ID used when no emulator is already booted.',
    )
    ..addOption(
      'session-port-base',
      defaultsTo: '58331',
      help: 'Base app-side cockpit port. Each platform increments from this.',
    )
    ..addOption(
      'launch-timeout-seconds',
      defaultsTo: '180',
      help: 'Launch timeout per platform.',
    )
    ..addOption(
      'device-timeout-seconds',
      defaultsTo: '420',
      help: 'Bootstrap timeout for iOS simulator and Android emulator.',
    )
    ..addFlag(
      'allow-web-host-recording-prerequisite-failure',
      negatable: false,
      help:
          'Allow local web verification to continue when host-side browser recording is blocked by desktop capture prerequisites.',
    )
    ..addFlag(
      'exhaustive-system-control',
      negatable: false,
      help:
          'Exercise every available platform system control action (not just the core subset) against the live app.',
    )
    ..addFlag(
      'fail-fast',
      negatable: false,
      help: 'Stop after the first platform failure.',
    )
    ..addOption(
      'output',
      help:
          'Optional file path where the full JSON verification result is written.',
    )
    ..addOption(
      'output-format',
      allowed: const <String>['json'],
      defaultsTo: 'json',
      help:
          'File output format for --output. verify_platforms emits JSON only.',
    )
    ..addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Show usage information.',
    );

  late final ArgResults parsed;
  try {
    parsed = parser.parse(arguments);
  } on FormatException catch (error) {
    stderr.writeln('Error: ${error.message}');
    stderr.writeln(parser.usage);
    exit(await _finishVerifierRun(64));
  }

  if (parsed['help'] as bool) {
    stdout.writeln(
      'Verify cockpit_demo development loops on supported desktop, web, and simulator targets.',
    );
    stdout.writeln();
    stdout.writeln(parser.usage);
    exit(await _finishVerifierRun(0));
  }

  final request = CockpitDemoPlatformVerificationRequest(
    projectDir: p.normalize(parsed['project-dir'] as String),
    platforms: (parsed['platform'] as List<String>).toList(growable: false),
    target: _readOptionalString(parsed, 'target'),
    outputRoot: p.normalize(parsed['output-root'] as String),
    sessionPortBase: int.parse(parsed['session-port-base'] as String),
    launchTimeout: Duration(
      seconds: int.parse(parsed['launch-timeout-seconds'] as String),
    ),
    deviceTimeout: Duration(
      seconds: int.parse(parsed['device-timeout-seconds'] as String),
    ),
    androidEmulatorId: parsed['android-emulator-id'] as String,
    allowWebHostRecordingPrerequisiteFailure:
        parsed['allow-web-host-recording-prerequisite-failure'] as bool,
    exhaustiveSystemControl: parsed['exhaustive-system-control'] as bool,
    failFast: parsed['fail-fast'] as bool,
    progressSink: (event) => stderr.writeln(event.toAiLine()),
  );

  final verifier = CockpitDemoPlatformVerifier();
  final result = await verifier.verify(request);
  final jsonText = const JsonEncoder.withIndent('  ').convert(result.toJson());

  final outputPath = _readOptionalString(parsed, 'output');
  if (outputPath != null) {
    final file = File(outputPath);
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonText);
    stdout.writeln('output=${file.path}');
  } else {
    stdout.writeln(jsonText);
  }
  exit(await _finishVerifierRun(result.success ? 0 : 1));
}

Future<int> _finishVerifierRun(int code) async {
  await stdout.flush();
  await stderr.flush();
  return code;
}

String? _readOptionalString(ArgResults parsed, String name) {
  final value = parsed[name] as String?;
  if (value == null || value.isEmpty) {
    return null;
  }
  return value;
}

String? _tryResolveScriptPath() {
  final script = Platform.script;
  if (script.scheme != 'file') {
    return null;
  }
  return script.toFilePath();
}

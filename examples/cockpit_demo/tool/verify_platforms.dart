import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;

import 'src/cockpit_demo_platform_verifier.dart';

Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addMultiOption(
      'platform',
      allowed: cockpitDemoSupportedVerificationPlatforms,
      defaultsTo: cockpitDemoDefaultVerificationPlatforms,
      help: 'Platforms to verify: android, ios, linux, macos, windows.',
    )
    ..addOption(
      'project-dir',
      defaultsTo: Directory.current.path,
      help: 'cockpit_demo project directory.',
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
      'fail-fast',
      negatable: false,
      help: 'Stop after the first platform failure.',
    )
    ..addOption(
      'output-json',
      help: 'Optional file path where the full verification result is written.',
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
    exitCode = 64;
    return;
  }

  if (parsed['help'] as bool) {
    stdout.writeln(
      'Verify cockpit_demo development loops on macOS, iOS simulator, and Android emulator.',
    );
    stdout.writeln();
    stdout.writeln(parser.usage);
    return;
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
    failFast: parsed['fail-fast'] as bool,
  );

  final verifier = CockpitDemoPlatformVerifier();
  final result = await verifier.verify(request);
  final jsonText = const JsonEncoder.withIndent('  ').convert(result.toJson());

  final outputJson = _readOptionalString(parsed, 'output-json');
  if (outputJson != null) {
    final file = File(outputJson);
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonText);
  }

  stdout.writeln(jsonText);
  exitCode = result.success ? 0 : 1;
}

String? _readOptionalString(ArgResults parsed, String name) {
  final value = parsed[name] as String?;
  if (value == null || value.isEmpty) {
    return null;
  }
  return value;
}

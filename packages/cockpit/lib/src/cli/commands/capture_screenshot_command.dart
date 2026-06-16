import 'dart:convert';
import 'dart:io';

import 'package:flutter_cockpit/flutter_cockpit.dart';

import '../../application/cockpit_capture_screenshot_service.dart';
import '../cockpit_cli_help.dart';
import '../cockpit_command_runner.dart';
import '../cockpit_interactive_cli_support.dart';

typedef CaptureScreenshotFunction =
    Future<CockpitCaptureScreenshotResult> Function(
      CockpitCaptureScreenshotRequest request,
    );

final class CaptureScreenshotCommand extends CockpitCliCommand {
  CaptureScreenshotCommand({
    CockpitCaptureScreenshotService? service,
    CaptureScreenshotFunction? capture,
    StringSink? stdoutSink,
  }) : _capture =
           capture ?? (service ?? CockpitCaptureScreenshotService()).capture,
       _stdoutSink = stdoutSink ?? stdout {
    cockpitAddAppArgs(argParser);
    argParser
      ..addOption(
        'name',
        defaultsTo: 'screenshot',
        help:
            'Human-readable screenshot name. The artifact path still includes a sortable timestamp.',
      )
      ..addOption(
        'reason',
        allowed: CockpitScreenshotReason.values
            .map((reason) => reason.jsonValue)
            .toList(growable: false),
        defaultsTo: CockpitScreenshotReason.acceptance.jsonValue,
        help:
            'Screenshot purpose: baseline, before_action, after_action, assertion_failure, or acceptance.',
      )
      ..addFlag(
        'include-snapshot',
        defaultsTo: false,
        help:
            'Embed a semantic snapshot inside the screenshot artifact when the screenshot alone is insufficient.',
      )
      ..addFlag(
        'attach-to-step',
        defaultsTo: true,
        negatable: true,
        help:
            'Attach the screenshot to the command result as step evidence. Disable only for ad-hoc diagnostics.',
      );
    cockpitAddProfileArg(argParser);
    cockpitAddCommandTimeoutArg(argParser);
  }

  final CaptureScreenshotFunction _capture;
  final StringSink _stdoutSink;

  @override
  String get name => 'capture-screenshot';

  @override
  String get description =>
      'Capture one named screenshot from a running app without hand-writing command JSON.';

  @override
  String get summary => 'Capture a screenshot from the app.';

  @override
  String get category => CockpitCliCategory.coreLoop;

  @override
  String get helpWhen =>
      'Use before a visible UI completion claim, or when a screenshot is the next missing fact. Prefer this over external screenshot tools.';

  @override
  String get helpNeeds =>
      'A running app reference. By default the command reuses .dart_tool/flutter_cockpit/latest_app.json and captures acceptance evidence named "screenshot".';

  @override
  String get helpShape =>
      'capture-screenshot --name <proof-name> --reason acceptance --profile inspect. Add --include-snapshot only when semantic state must travel with the image.';

  @override
  String get helpExample =>
      'cockpit capture-screenshot --name acceptance --profile inspect';

  @override
  String get helpWrites =>
      'A command result with screenshot artifact refs/downloads and a small post-capture UI layer according to --profile.';

  @override
  Future<int> run() async {
    cockpitRequireAppReference(argResults, usage);
    final result = await _capture(
      CockpitCaptureScreenshotRequest(
        baseUri: cockpitReadOptionalBaseUri(argResults),
        appHandlePath: cockpitResolveAppHandlePath(argResults),
        androidDeviceId: argResults?['android-device-id'] as String?,
        iosDeviceId: argResults?['ios-device-id'] as String?,
        name: argResults?['name'] as String? ?? 'screenshot',
        reason: CockpitScreenshotReason.fromJson(argResults?['reason']),
        includeSnapshot: argResults?['include-snapshot'] as bool? ?? false,
        attachToStep: argResults?['attach-to-step'] as bool? ?? true,
        resultProfile: cockpitReadResultProfile(argResults),
        defaultCommandTimeout: Duration(
          milliseconds:
              cockpitReadOptionalPositiveInt(argResults, 'timeout-ms', usage) ??
              30000,
        ),
      ),
    );
    await cockpitWriteJsonPayload(
      payload: const JsonEncoder.withIndent('  ').convert(result.toJson()),
      argResults: argResults,
      stdoutSink: _stdoutSink,
    );
    return cockpitSuccessExitCode;
  }
}

import 'dart:io';

import 'package:test/test.dart';

void main() {
  final root = Directory.current.absolute.path;

  test('flutter-cockpit skill teaches lowest-cost public surface usage', () {
    final skill = File(
      '$root/skills/flutter-cockpit/SKILL.md',
    ).readAsStringSync();
    final contract = File(
      '$root/docs/contracts/flutter-cockpit-skill-contract.md',
    ).readAsStringSync();
    final cliReference = File(
      '$root/skills/flutter-cockpit/examples/cli-command-reference.md',
    ).readAsStringSync();
    final rapidLoop = File(
      '$root/skills/flutter-cockpit/examples/rapid-dev-loop.md',
    ).readAsStringSync();

    expect(skill, contains('First-Use Guardrails'));
    expect(skill, contains('Default Loops'));
    expect(skill, contains('app-first'));
    expect(skill, contains('help <command>'));
    expect(
        skill, contains('MCP `launch_app` and `launch_target` mirror the CLI'));
    expect(skill, contains('.dart_tool/flutter_cockpit/latest_app.json'));
    expect(skill, contains('after `launch-app` in the same workspace'));
    expect(skill, contains('--flavor <name>'));
    expect(
      skill,
      contains('auto-normalizes to `desktopApp` and `browserPage`'),
    );
    expect(
      skill,
      contains('do not guess `web`, and stay on `mode: development`'),
    );
    expect(skill, contains('jq'));
    expect(skill, contains('grep-package-uris'));
    expect(skill, contains('captureScreenshot'));
    expect(skill, contains('artifact refs or output paths'));
    expect(skill, contains('Do not blindly replay a non-idempotent batch'));
    expect(skill, contains('re-read minimal route or state before retrying'));
    expect(skill, contains('Prefer `run-batch` for route-crossing flows'));
    expect(contract, contains('non-idempotent batch'));
    expect(contract, contains('route-aware recovery'));
    expect(cliReference, contains('--output-json'));
    expect(cliReference, contains('--flavor'));
    expect(cliReference, contains('jq'));
    expect(cliReference, contains('grep-package-uris'));
    expect(
      cliReference,
      contains('automation launch is not a supported browser path'),
    );
    expect(
      cliReference,
      contains('auto-normalizes the default `flutterApp` target kind'),
    );
    expect(cliReference, contains('scrollUntilVisible'));
    expect(cliReference, contains('enterText'));
    expect(cliReference, contains('lastReloadSucceeded'));
    expect(cliReference, contains('start-recording'));
    expect(cliReference, contains('--app-json /tmp/flutter_cockpit/app.json'));
    expect(rapidLoop, contains('jq'));
    expect(rapidLoop, contains('app.json'));
    expect(rapidLoop, contains('grep-package-uris'));
    expect(rapidLoop, contains('textPreviews'));
    expect(rapidLoop, contains('remoteUnavailable'));
    expect(rapidLoop, contains('smallest remaining step'));
    expect(rapidLoop, contains('Do not parallelize'));
  });
}

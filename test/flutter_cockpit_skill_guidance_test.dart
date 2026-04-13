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

    expect(skill, contains('lowest-token public surface'));
    expect(skill, contains('jq'));
    expect(skill, contains('pipe'));
    expect(skill, contains('grep_package_uris'));
    expect(skill, contains('Do not parallelize'));
    expect(skill, contains('probes between internal scroll segments'));
    expect(skill, contains('do not assume the route or scroll position reset'));
    expect(skill, contains('opposite direction once'));
    expect(skill, contains('stable section heading'));
    expect(skill, contains('selection banners, snackbars, or bottom sheets'));
    expect(skill, contains('summary counts and `textPreviews`'));
    expect(skill, contains('do not blindly replay a non-idempotent batch'));
    expect(skill, contains('re-read minimal route or state before retrying'));
    expect(skill, contains('route-aware recovery'));
    expect(contract, contains('non-idempotent batch'));
    expect(contract, contains('route-aware recovery'));
    expect(cliReference, contains('--output-json'));
    expect(cliReference, contains('jq'));
    expect(cliReference, contains('grep-package-uris'));
    expect(cliReference, contains('scrollUntilVisible'));
    expect(cliReference, contains('enterText'));
    expect(cliReference, contains('lastReloadSucceeded'));
    expect(cliReference, contains('bottom sheet appears'));
    expect(rapidLoop, contains('jq'));
    expect(rapidLoop, contains('app.json'));
    expect(rapidLoop, contains('grep-package-uris'));
    expect(rapidLoop, contains('viewportFraction'));
    expect(rapidLoop, contains('reverse: true'));
    expect(rapidLoop, contains('textPreviews'));
    expect(rapidLoop, contains('stable section heading'));
    expect(rapidLoop, contains('list shifted'));
    expect(rapidLoop, contains('remoteUnavailable'));
    expect(rapidLoop, contains('smallest remaining step'));
    expect(rapidLoop, contains('Do not parallelize'));
  });
}

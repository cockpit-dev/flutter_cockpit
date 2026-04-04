import 'dart:io';

import 'package:test/test.dart';

void main() {
  final root = Directory.current.absolute.path;

  test('flutter-cockpit skill teaches lowest-cost public surface usage', () {
    final skill = File(
      '$root/skills/flutter-cockpit/SKILL.md',
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
    expect(skill, contains('Do not parallelize'));
    expect(skill, contains('probes between internal scroll segments'));
    expect(skill, contains('stable section heading'));
    expect(cliReference, contains('--output-json'));
    expect(cliReference, contains('jq'));
    expect(cliReference, contains('scrollUntilVisible'));
    expect(rapidLoop, contains('jq'));
    expect(rapidLoop, contains('app.json'));
    expect(rapidLoop, contains('viewportFraction'));
    expect(rapidLoop, contains('stable section heading'));
    expect(rapidLoop, contains('Do not parallelize'));
  });
}

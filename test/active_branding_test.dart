import 'dart:io';

import 'package:test/test.dart';

void main() {
  final root = Directory.current.path;

  test('root README and goals use flutter_cockpit branding', () {
    final readme = File('$root/README.md').readAsStringSync();
    final goals = File('$root/GOALS.md').readAsStringSync();

    expect(readme, contains('# flutter_cockpit'));
    expect(readme, contains('packages/flutter_cockpit'));
    expect(readme, contains('skills/flutter-cockpit'));
    expect(readme, isNot(contains('packages/flutter_pilot`')));
    expect(readme, isNot(contains('skills/flutter-pilot')));

    expect(goals, contains('# flutter_cockpit Goals'));
    expect(goals, contains('packages/flutter_cockpit'));
    expect(goals, contains('packages/flutter_cockpit_devtools'));
    expect(goals, isNot(contains('packages/flutter_pilot')));
    expect(goals, isNot(contains('packages/flutter_pilot_devtools')));
  });

  test('active skill assets use flutter_cockpit branding and paths', () {
    final skillDir = Directory('$root/skills/flutter-cockpit');
    final legacySkillDir = Directory('$root/skills/flutter-pilot');
    final skill = File(
      '$root/skills/flutter-cockpit/SKILL.md',
    ).readAsStringSync();
    final contract = File(
      '$root/docs/contracts/flutter-cockpit-skill-contract.md',
    ).readAsStringSync();

    expect(skillDir.existsSync(), isTrue);
    expect(legacySkillDir.existsSync(), isFalse);
    expect(skill, contains('name: flutter-cockpit'));
    expect(skill, contains('# Flutter Cockpit'));
    expect(skill, isNot(contains('name: flutter-pilot')));
    expect(contract, contains('# Flutter Cockpit Skill Contract'));
    expect(contract, isNot(contains('`flutter-pilot` skill')));
  });

  test('active package trees do not keep legacy flutter_pilot filenames', () {
    final packageRoots = <Directory>[
      Directory('$root/packages/flutter_cockpit'),
      Directory('$root/packages/flutter_cockpit_devtools'),
    ];

    final legacyPaths = packageRoots
        .expand((directory) => directory.listSync(recursive: true))
        .whereType<FileSystemEntity>()
        .map((entity) => entity.path)
        .where(
          (path) =>
              path.contains('flutter_pilot') || path.contains('flutter-pilot'),
        )
        .toList(growable: false);

    expect(legacyPaths, isEmpty);
  });
}

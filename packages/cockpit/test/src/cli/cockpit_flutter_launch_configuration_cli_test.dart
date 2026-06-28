import 'package:args/args.dart';
import 'package:cockpit/src/cli/cockpit_flutter_launch_configuration_cli.dart';
import 'package:test/test.dart';

void main() {
  test('launch configuration CLI preserves comma-containing values', () {
    final parser = ArgParser();
    cockpitAddFlutterLaunchConfigurationOptions(parser);

    final results = parser.parse(<String>[
      '--dart-define',
      'FEATURES=chat,payments,search',
      '--dart-define-from-file',
      'config/dev,local.json',
      '--flutter-arg',
      '--enable-experiment records,patterns',
      '--env',
      'BOOTSTRAP_JSON={"features":["chat","pay"]}',
    ]);

    final configuration = cockpitReadFlutterLaunchConfiguration(
      results,
      parser.usage,
    );

    expect(configuration.dartDefines, <String>[
      'FEATURES=chat,payments,search',
    ]);
    expect(configuration.dartDefineFromFiles, <String>[
      'config/dev,local.json',
    ]);
    expect(configuration.flutterArgs, <String>[
      '--enable-experiment',
      'records,patterns',
    ]);
    expect(configuration.environment, <String, String>{
      'BOOTSTRAP_JSON': '{"features":["chat","pay"]}',
    });
  });

  test('launch configuration CLI parses quoted raw Flutter arg strings', () {
    final parser = ArgParser();
    cockpitAddFlutterLaunchConfigurationOptions(parser);

    final results = parser.parse(<String>[
      '--flutter-arg',
      '--build-name "AI Build, QA"',
      '--flutter-arg',
      "--dart-entrypoint-args '--tenant acme --seed demo,data'",
    ]);

    final configuration = cockpitReadFlutterLaunchConfiguration(
      results,
      parser.usage,
    );

    expect(configuration.flutterArgs, <String>[
      '--build-name',
      'AI Build, QA',
      '--dart-entrypoint-args',
      '--tenant acme --seed demo,data',
    ]);
  });
}

import 'package:cockpit/cockpit.dart';
import 'package:test/test.dart';

void main() {
  test('exports TaskRunBundleWriter', () {
    expect(TaskRunBundleWriter, isNotNull);
  });

  test('exports CockpitMcpServer', () {
    expect(CockpitMcpServer, isNotNull);
  });

  test('exports AI-first app services and models', () {
    expect(CockpitLaunchAppService, isNotNull);
    expect(CockpitFlutterLaunchConfiguration, isNotNull);
    expect(CockpitListAppsService, isNotNull);
    expect(CockpitReadAppService, isNotNull);
    expect(CockpitInspectUiService, isNotNull);
    expect(CockpitReadLogsService, isNotNull);
    expect(CockpitAppHandle, isNotNull);
  });

  test('exports launch configuration helpers and args types', () {
    final parser = ArgParser();
    cockpitAddFlutterLaunchConfigurationOptions(parser);
    final results = parser.parse(<String>[
      '--dart-define',
      'FOO=bar',
      '--flutter-arg',
      '--enable-experiment records',
      '--env',
      'FEATURE_FLAG=enabled',
    ]);

    expect(results, isA<ArgResults>());
    final config = cockpitReadFlutterLaunchConfiguration(results, parser.usage);
    expect(config.dartDefines, <String>['FOO=bar']);
    expect(config.flutterArgs, <String>['--enable-experiment', 'records']);
    expect(config.environment, <String, String>{'FEATURE_FLAG': 'enabled'});
    expect(
      cockpitFlutterLaunchConfigurationMcpProperties,
      contains('dartDefines'),
    );
    expect(
      cockpitReadMcpFlutterLaunchConfiguration(<String, Object?>{
        'dartDefines': <Object?>['API_URL=https://example.test'],
      }).dartDefines,
      <String>['API_URL=https://example.test'],
    );
  });

  test('exports workflow and contract models used by delivery tooling', () {
    expect(CockpitControlScript, isNotNull);
    expect(CockpitWorkflowStep, isNotNull);
    expect(CockpitReadWorkspaceContractsService, isNotNull);
  });
}

import 'package:flutter_cockpit_devtools/flutter_cockpit_devtools.dart';
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
    expect(CockpitListAppsService, isNotNull);
    expect(CockpitReadAppService, isNotNull);
    expect(CockpitInspectUiService, isNotNull);
    expect(CockpitReadLogsService, isNotNull);
    expect(CockpitAppHandle, isNotNull);
  });
}

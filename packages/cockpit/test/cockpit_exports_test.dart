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
    expect(CockpitListAppsService, isNotNull);
    expect(CockpitReadAppService, isNotNull);
    expect(CockpitInspectUiService, isNotNull);
    expect(CockpitReadLogsService, isNotNull);
    expect(CockpitAppHandle, isNotNull);
  });

  test('exports workflow and contract models used by delivery tooling', () {
    expect(CockpitControlScript, isNotNull);
    expect(CockpitWorkflowStep, isNotNull);
    expect(CockpitReadWorkspaceContractsService, isNotNull);
  });
}

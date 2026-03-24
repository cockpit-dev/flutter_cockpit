import 'package:flutter_cockpit_devtools/flutter_cockpit_devtools.dart';
import 'package:test/test.dart';

void main() {
  test('exports TaskRunBundleWriter', () {
    expect(TaskRunBundleWriter, isNotNull);
  });

  test('exports CockpitMcpServer', () {
    expect(CockpitMcpServer, isNotNull);
  });

  test('exports development session services and models', () {
    expect(CockpitLaunchDevelopmentSessionService, isNotNull);
    expect(CockpitCollectDevelopmentProbeService, isNotNull);
    expect(CockpitDevelopmentProbe, isNotNull);
    expect(CockpitDevelopmentSessionHandle, isNotNull);
  });
}

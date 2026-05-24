import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('MCP surface verifier waits for settings target readiness', () {
    final packageRelativeScript = File('tool/verify_mcp_surface.dart');
    final repoRelativeScript = File(
      'packages/flutter_cockpit_devtools/tool/verify_mcp_surface.dart',
    );
    final scriptFile = packageRelativeScript.existsSync()
        ? packageRelativeScript
        : repoRelativeScript;
    final script = scriptFile.readAsStringSync();

    final openSettings = script.indexOf("appReport['open_settings']");
    final waitSettings = script.indexOf('final waitIdleAfterSettings');
    final inspectSettings = script.indexOf("appReport['inspect_ui_settings']");
    final scrollSyncCheck = script.indexOf('final scrollSyncCheckResult');
    final tapSyncCheck = script.indexOf("appReport['tap_sync_check']");

    expect(openSettings, isNonNegative);
    expect(waitSettings, greaterThan(openSettings));
    expect(inspectSettings, greaterThan(waitSettings));
    expect(scrollSyncCheck, greaterThan(inspectSettings));
    expect(tapSyncCheck, greaterThan(scrollSyncCheck));
    expect(
      script.substring(waitSettings, inspectSettings),
      allOf(
        contains("'run_command'"),
        contains("'commandId': 'wait-settings-targets'"),
        contains("'commandType': 'waitFor'"),
        contains("'routeName': '/settings'"),
        isNot(contains("'requireVisibleTargets'")),
      ),
    );
    expect(
      script.substring(scrollSyncCheck, tapSyncCheck),
      allOf(
        contains("'run_command'"),
        contains("'commandId': 'scroll-sync-check'"),
        contains("'commandType': 'scrollUntilVisible'"),
        contains("'text': 'Run check'"),
        contains("'revealAlignment': 'center'"),
      ),
    );
  });
}

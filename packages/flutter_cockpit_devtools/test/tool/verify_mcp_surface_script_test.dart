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
    final waitRunCheck = script.indexOf('final waitRunCheckTarget');
    final inspectSettings = script.indexOf("appReport['inspect_ui_settings']");
    final scrollSyncCheck = script.indexOf("appReport['scroll_sync_check']");

    expect(openSettings, isNonNegative);
    expect(waitSettings, greaterThan(openSettings));
    expect(waitRunCheck, greaterThan(waitSettings));
    expect(inspectSettings, greaterThan(waitRunCheck));
    expect(scrollSyncCheck, greaterThan(inspectSettings));
    expect(
      script.substring(waitSettings, waitRunCheck),
      allOf(
        contains("'run_command'"),
        contains("'commandId': 'wait-settings-targets'"),
        contains("'commandType': 'waitFor'"),
        contains("'routeName': '/settings'"),
        isNot(contains("'requireVisibleTargets'")),
      ),
    );
    expect(
      script.substring(waitRunCheck, inspectSettings),
      allOf(
        contains("'run_command'"),
        contains("'commandId': 'wait-settings-run-check-target'"),
        contains("'commandType': 'waitFor'"),
        contains("'text': 'Run check'"),
      ),
    );
  });
}

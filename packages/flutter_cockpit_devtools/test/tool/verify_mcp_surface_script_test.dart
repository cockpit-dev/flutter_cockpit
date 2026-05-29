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
      script.substring(openSettings, waitSettings),
      allOf(
        contains("'commandId': 'open-settings'"),
        contains("'commandType': 'tap'"),
        contains("'expectedRouteName': '/settings'"),
        contains("'routeTimeoutMs': 3000"),
      ),
    );
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
    final scrollSyncCheckBlock = script.substring(
      scrollSyncCheck,
      tapSyncCheck,
    );
    expect(
      scrollSyncCheckBlock,
      allOf(
        contains("'run_command'"),
        contains("'commandId': 'scroll-sync-check'"),
        contains("'commandType': 'scrollUntilVisible'"),
        contains("'text': 'Run check'"),
        contains("'revealAlignment': 'center'"),
        contains("'type': 'ListView'"),
      ),
    );
    expect(scrollSyncCheckBlock, contains("'route': '/settings'"));
    expect(
      scrollSyncCheckBlock,
      isNot(contains("'path': 'scaffold.body/list_view")),
    );
    final scrollDebugLog = script.indexOf('final scrollDebugLogResult');
    final tapDebugLog = script.indexOf("appReport['tap_debug_log']");
    expect(scrollDebugLog, greaterThan(tapSyncCheck));
    expect(tapDebugLog, greaterThan(scrollDebugLog));
    final scrollDebugLogBlock = script.substring(scrollDebugLog, tapDebugLog);
    expect(
      scrollDebugLogBlock,
      allOf(
        contains("'commandId': 'scroll-debug-log'"),
        contains("'commandType': 'scrollUntilVisible'"),
        contains("'text': 'Emit debug log'"),
        contains("'type': 'ListView'"),
      ),
    );
    expect(scrollDebugLogBlock, contains("'route': '/settings'"));
    expect(
      scrollDebugLogBlock,
      isNot(contains("'path': 'scaffold.body/list_view")),
    );
  });

  test('MCP surface verifier reuses the current Dart executable', () {
    final packageRelativeScript = File('tool/verify_mcp_surface.dart');
    final repoRelativeScript = File(
      'packages/flutter_cockpit_devtools/tool/verify_mcp_surface.dart',
    );
    final scriptFile = packageRelativeScript.existsSync()
        ? packageRelativeScript
        : repoRelativeScript;
    final script = scriptFile.readAsStringSync();

    expect(script, contains('Platform.resolvedExecutable'));
    expect(script, isNot(contains("Process.start('dart'")));
  });
}

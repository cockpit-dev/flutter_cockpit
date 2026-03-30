import 'package:flutter_cockpit_devtools/src/application/cockpit_query_remote_session_service.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_run_task_service.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_validate_task_service.dart';
import 'package:flutter_cockpit_devtools/src/mcp/core/cockpit_mcp_feature_category.dart';
import 'package:flutter_cockpit_devtools/src/mcp/tools/cockpit_query_remote_session_tool.dart';
import 'package:flutter_cockpit_devtools/src/mcp/tools/cockpit_run_task_tool.dart';
import 'package:flutter_cockpit_devtools/src/mcp/tools/cockpit_validate_task_tool.dart';
import 'package:test/test.dart';

void main() {
  test('run_task exposes execution metadata and preserves descriptor shape',
      () {
    final tool = CockpitRunTaskTool(
      runTask: (_) async => throw UnimplementedError(),
    );

    expect(tool.definition.name, 'run_task');
    expect(
      tool.definition.categories,
      <CockpitMcpFeatureCategory>[
        CockpitMcpFeatureCategory.execution,
        CockpitMcpFeatureCategory.delivery,
      ],
    );
    expect(tool.definition.annotations.longRunning, isTrue);
    expect(tool.definition.annotations.producesBundleEvidence, isTrue);
    expect(tool.definition.enabledByDefault, isTrue);
    expect(tool.toDescriptor()['name'], 'run_task');
    expect(tool.toDescriptor()['inputSchema'], tool.definition.inputSchema);
  });

  test('validate_task exposes delivery metadata', () {
    final tool = CockpitValidateTaskTool(
      validateTask: (_) async => throw UnimplementedError(),
    );

    expect(tool.definition.name, 'validate_task');
    expect(tool.definition.categories, <CockpitMcpFeatureCategory>[
      CockpitMcpFeatureCategory.delivery,
    ]);
    expect(tool.definition.annotations.longRunning, isTrue);
    expect(tool.definition.annotations.producesBundleEvidence, isTrue);
    expect(tool.definition.annotations.readOnly, isFalse);
  });

  test('query_remote_session is read-only and session-scoped', () {
    final tool = CockpitQueryRemoteSessionTool(
      query: (_) async => throw UnimplementedError(),
    );

    expect(tool.definition.name, 'query_remote_session');
    expect(tool.definition.categories, <CockpitMcpFeatureCategory>[
      CockpitMcpFeatureCategory.sessionManagement,
      CockpitMcpFeatureCategory.inspection,
    ]);
    expect(tool.definition.annotations.readOnly, isTrue);
    expect(tool.definition.annotations.requiresSession, isTrue);
    expect(tool.definition.annotations.longRunning, isFalse);
  });
}

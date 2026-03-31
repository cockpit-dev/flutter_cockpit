import 'package:flutter_cockpit_devtools/src/mcp/core/cockpit_mcp_feature_category.dart';
import 'package:flutter_cockpit_devtools/src/mcp/core/cockpit_mcp_roots_tracker.dart';
import 'package:flutter_cockpit_devtools/src/mcp/tools/cockpit_analyze_files_tool.dart';
import 'package:flutter_cockpit_devtools/src/mcp/tools/cockpit_create_project_tool.dart';
import 'package:flutter_cockpit_devtools/src/mcp/tools/cockpit_execute_remote_command_tool.dart';
import 'package:flutter_cockpit_devtools/src/mcp/tools/cockpit_lsp_tool.dart';
import 'package:flutter_cockpit_devtools/src/mcp/tools/cockpit_pub_tool.dart';
import 'package:flutter_cockpit_devtools/src/mcp/tools/cockpit_pub_dev_search_tool.dart';
import 'package:flutter_cockpit_devtools/src/mcp/tools/cockpit_query_remote_session_tool.dart';
import 'package:flutter_cockpit_devtools/src/mcp/tools/cockpit_read_remote_status_tool.dart';
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

  test('pub_dev_search is read-only dependency intelligence', () {
    final tool = CockpitPubDevSearchTool(
      search: (_) async => throw UnimplementedError(),
    );

    expect(tool.definition.name, 'pub_dev_search');
    expect(tool.definition.categories, <CockpitMcpFeatureCategory>[
      CockpitMcpFeatureCategory.workspace,
      CockpitMcpFeatureCategory.dependencyIntelligence,
    ]);
    expect(tool.definition.annotations.readOnly, isTrue);
  });

  test('create_project is long-running project scaffolding', () {
    final tool = CockpitCreateProjectTool(
      rootsTracker: CockpitMcpRootsTracker(forceFallback: true),
      create: (_) async => throw UnimplementedError(),
    );

    expect(tool.definition.name, 'create_project');
    expect(tool.definition.categories, <CockpitMcpFeatureCategory>[
      CockpitMcpFeatureCategory.workspace,
      CockpitMcpFeatureCategory.projectScaffolding,
    ]);
    expect(tool.definition.annotations.longRunning, isTrue);
    expect(tool.definition.annotations.readOnly, isFalse);
  });

  test('pub is writable dependency intelligence', () {
    final tool = CockpitPubTool(
      rootsTracker: CockpitMcpRootsTracker(forceFallback: true),
      run: (_) async => throw UnimplementedError(),
    );

    expect(tool.definition.name, 'pub');
    expect(tool.definition.categories, <CockpitMcpFeatureCategory>[
      CockpitMcpFeatureCategory.workspace,
      CockpitMcpFeatureCategory.dependencyIntelligence,
    ]);
    expect(tool.definition.annotations.readOnly, isFalse);
    expect(tool.definition.annotations.longRunning, isTrue);
  });

  test('analyze_files is read-only focused analysis', () {
    final tool = CockpitAnalyzeFilesTool(
      rootsTracker: CockpitMcpRootsTracker(forceFallback: true),
      analyze: (_) async => throw UnimplementedError(),
    );

    expect(tool.definition.name, 'analyze_files');
    expect(tool.definition.categories, <CockpitMcpFeatureCategory>[
      CockpitMcpFeatureCategory.workspace,
      CockpitMcpFeatureCategory.workspaceQuality,
      CockpitMcpFeatureCategory.codeIntelligence,
    ]);
    expect(tool.definition.annotations.readOnly, isTrue);
  });

  test('lsp is read-only code intelligence', () {
    final tool = CockpitLspTool(
      rootsTracker: CockpitMcpRootsTracker(forceFallback: true),
      invoke: (_) async => throw UnimplementedError(),
    );

    expect(tool.definition.name, 'lsp');
    expect(tool.definition.categories, <CockpitMcpFeatureCategory>[
      CockpitMcpFeatureCategory.workspace,
      CockpitMcpFeatureCategory.codeIntelligence,
    ]);
    expect(tool.definition.annotations.readOnly, isTrue);
    expect(tool.definition.annotations.longRunning, isFalse);
  });

  test('execute_remote_command is session-scoped execution', () {
    final tool = CockpitExecuteRemoteCommandTool(
      execute: (_) async => throw UnimplementedError(),
    );

    expect(tool.definition.name, 'execute_remote_command');
    expect(tool.definition.categories, <CockpitMcpFeatureCategory>[
      CockpitMcpFeatureCategory.execution,
      CockpitMcpFeatureCategory.inspection,
    ]);
    expect(tool.definition.annotations.readOnly, isFalse);
    expect(tool.definition.annotations.requiresSession, isTrue);
  });

  test('read_remote_status is read-only inspection', () {
    final tool = CockpitReadRemoteStatusTool(
      read: (_) async => throw UnimplementedError(),
    );

    expect(tool.definition.name, 'read_remote_status');
    expect(tool.definition.categories, <CockpitMcpFeatureCategory>[
      CockpitMcpFeatureCategory.sessionManagement,
      CockpitMcpFeatureCategory.inspection,
    ]);
    expect(tool.definition.annotations.readOnly, isTrue);
    expect(tool.definition.annotations.requiresSession, isTrue);
  });
}

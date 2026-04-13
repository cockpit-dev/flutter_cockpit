import 'package:flutter_cockpit_devtools/src/mcp/verification/cockpit_sync_lab_real_verification.dart';
import 'package:test/test.dart';

void main() {
  test('sync lab artifact SQL only targets verifier-created tasks', () {
    final countSql = buildSyncLabVerifierArtifactCountSql();
    final cleanupSql = buildSyncLabVerifierArtifactCleanupSql();

    expect(countSql, contains("title like 'MCP sync conflict %'"));
    expect(
      countSql,
      contains(
        "notes = 'Created by MCP real verifier to exercise sync conflict recovery.'",
      ),
    );
    expect(cleanupSql, contains("delete from task_sync_state"));
    expect(cleanupSql, contains("delete from tasks"));
    expect(cleanupSql, contains("title like 'MCP sync conflict %'"));
    expect(
      cleanupSql,
      contains(
        "notes = 'Created by MCP real verifier to exercise sync conflict recovery.'",
      ),
    );
  });

  test('buildSyncLabCreateTaskBatch creates a route-aware editor flow', () {
    final commands = buildSyncLabCreateTaskBatch(
      taskTitle: 'MCP sync conflict 42',
    );

    expect(commands, hasLength(5));
    expect(commands[0]['commandId'], 'verify-open-editor');
    expect(commands[0]['commandType'], 'tap');
    expect(
      commands[0]['locator'],
      <String, Object?>{
        'text': 'New task',
        'ancestor': <String, Object?>{'route': '/inbox'},
      },
    );
    expect(commands[1]['commandId'], 'verify-enter-task-title');
    expect(commands[1]['commandType'], 'enterText');
    expect(
      commands[1]['locator'],
      <String, Object?>{
        'text': 'Task title',
        'ancestor': <String, Object?>{'route': '/editor'},
      },
    );
    expect(
      commands[1]['parameters'],
      <String, Object?>{'text': 'MCP sync conflict 42'},
    );
    expect(commands[2]['commandId'], 'verify-focus-task-notes');
    expect(
      commands[2]['locator'],
      <String, Object?>{
        'text': 'Notes',
        'ancestor': <String, Object?>{'route': '/editor'},
      },
    );
    expect(commands[3]['commandId'], 'verify-enter-task-notes');
    expect(
      commands[3]['locator'],
      <String, Object?>{
        'text': 'Notes',
        'type': 'TextField',
        'ancestor': <String, Object?>{'route': '/editor'},
      },
    );
    expect(commands[4]['commandId'], 'verify-save-task');
    expect(
      commands[4]['locator'],
      <String, Object?>{
        'text': 'Save task',
        'ancestor': <String, Object?>{'route': '/editor'},
      },
    );
  });

  test('buildSyncLabConflictSyncBatch reaches the queued sync action', () {
    final commands = buildSyncLabConflictSyncBatch();

    expect(
      commands.map((command) => command['commandId']).toList(growable: false),
      <String>[
        'verify-open-sync-settings',
        'verify-scroll-run-queued-sync',
        'verify-run-queued-sync',
        'verify-wait-for-conflicted-sync-state',
        'verify-close-settings',
      ],
    );
    expect(
      commands[0]['locator'],
      <String, Object?>{
        'tooltip': 'Settings',
        'ancestor': <String, Object?>{'route': '/inbox'},
      },
    );
    expect(commands[1]['commandType'], 'scrollUntilVisible');
    expect(
      commands[1]['locator'],
      <String, Object?>{
        'text': 'Run queued sync',
        'route': '/settings',
        'ancestor': <String, Object?>{'route': '/settings'},
      },
    );
    expect(
      commands[1]['parameters'],
      <String, Object?>{
        'maxScrolls': 10,
        'viewportFraction': 0.82,
        'continuous': true,
        'durationPerStepMs': 220,
        'revealAlignment': 'center',
        'scrollableLocator': <String, Object?>{
          'type': 'ListView',
          'path': 'scaffold.body/list_view.slivers/0',
          'route': '/settings',
        },
      },
    );
    expect(
      commands[2]['locator'],
      <String, Object?>{
        'text': 'Run queued sync',
        'ancestor': <String, Object?>{'route': '/settings'},
      },
    );
    expect(commands[3]['commandType'], 'waitFor');
    expect(
      commands[3]['parameters'],
      <String, Object?>{
        'text': 'Conflicts detected',
        'timeoutMs': 20000,
      },
    );
  });

  test('buildSyncLabOpenConflictBatch walks into the conflict screen', () {
    final commands = buildSyncLabOpenConflictBatch(
      taskTitle: 'MCP sync conflict 42',
    );

    expect(
      commands.map((command) => command['commandId']).toList(growable: false),
      <String>[
        'verify-search-created-task',
        'verify-wait-for-created-task-search-results',
        'verify-open-created-task',
      ],
    );
    expect(commands[0]['commandType'], 'enterText');
    expect(
      commands[0]['locator'],
      <String, Object?>{
        'text': 'Search title or notes',
        'ancestor': <String, Object?>{'route': '/inbox'},
      },
    );
    expect(
      commands[0]['parameters'],
      <String, Object?>{
        'text': 'MCP sync conflict 42',
      },
    );
    expect(commands[1]['commandType'], 'waitFor');
    expect(commands[1]['timeoutMs'], 12000);
    expect(
      commands[1]['parameters'],
      <String, Object?>{
        'text': 'MCP sync conflict 42',
      },
    );
    expect(
      commands[2]['locator'],
      <String, Object?>{
        'semanticId': 'Open task MCP sync conflict 42',
        'ancestor': <String, Object?>{'route': '/inbox'},
      },
    );
  });

  test('buildSyncLabOpenConflictResolutionCommand targets the detail CTA', () {
    final command = buildSyncLabOpenConflictResolutionCommand();

    expect(command['commandId'], 'verify-open-conflict-resolution');
    expect(command['commandType'], 'tap');
    expect(
      command['locator'],
      <String, Object?>{
        'text': 'Resolve conflict',
        'ancestor': <String, Object?>{'route': '/detail'},
      },
    );
  });

  test('buildSyncLabRecoverySyncBatch retries sync after keep-local resolution',
      () {
    final commands = buildSyncLabRecoverySyncBatch();

    expect(
      commands.map((command) => command['commandId']).toList(growable: false),
      <String>[
        'verify-return-from-detail',
        'verify-open-sync-settings',
        'verify-scroll-run-queued-sync',
        'verify-run-queued-sync',
        'verify-wait-for-synced-state',
        'verify-close-settings',
      ],
    );
    expect(commands[0]['commandType'], 'tap');
    expect(
      commands[0]['locator'],
      <String, Object?>{
        'tooltip': 'Back',
        'ancestor': <String, Object?>{'route': '/detail'},
      },
    );
    expect(
      commands[2]['locator'],
      <String, Object?>{
        'text': 'Run queued sync',
        'route': '/settings',
        'ancestor': <String, Object?>{'route': '/settings'},
      },
    );
    expect(
      commands[2]['parameters'],
      <String, Object?>{
        'maxScrolls': 10,
        'viewportFraction': 0.82,
        'continuous': true,
        'durationPerStepMs': 220,
        'revealAlignment': 'center',
        'scrollableLocator': <String, Object?>{
          'type': 'ListView',
          'path': 'scaffold.body/list_view.slivers/0',
          'route': '/settings',
        },
      },
    );
    expect(
      commands[3]['locator'],
      <String, Object?>{
        'text': 'Run queued sync',
        'ancestor': <String, Object?>{'route': '/settings'},
      },
    );
    expect(commands[4]['commandType'], 'waitFor');
    expect(
      commands[4]['parameters'],
      <String, Object?>{
        'text': 'Sync complete',
        'timeoutMs': 20000,
      },
    );
  });

  test('buildSyncLabRecoveryVerificationBatch verifies the task becomes synced',
      () {
    final commands = buildSyncLabRecoveryVerificationBatch(
      taskTitle: 'MCP sync conflict 42',
    );

    expect(
      commands.map((command) => command['commandId']).toList(growable: false),
      <String>[
        'verify-search-created-task-after-recovery',
        'verify-wait-for-created-task-search-results-after-recovery',
        'verify-open-created-task-after-recovery',
        'verify-assert-task-synced',
      ],
    );
    expect(commands[0]['commandType'], 'enterText');
    expect(
      commands[0]['locator'],
      <String, Object?>{
        'text': 'Search title or notes',
        'ancestor': <String, Object?>{'route': '/inbox'},
      },
    );
    expect(
      commands[0]['parameters'],
      <String, Object?>{
        'text': 'MCP sync conflict 42',
      },
    );
    expect(commands[1]['commandType'], 'waitFor');
    expect(commands[1]['timeoutMs'], 12000);
    expect(
      commands[1]['parameters'],
      <String, Object?>{
        'text': 'MCP sync conflict 42',
      },
    );
    expect(
      commands[2]['locator'],
      <String, Object?>{
        'semanticId': 'Open task MCP sync conflict 42',
        'ancestor': <String, Object?>{'route': '/inbox'},
      },
    );
    expect(commands[3]['commandType'], 'assertText');
    expect(
      commands[3]['parameters'],
      <String, Object?>{'text': 'Sync synced'},
    );
  });
}

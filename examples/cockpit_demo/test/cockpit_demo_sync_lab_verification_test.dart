import 'package:flutter_test/flutter_test.dart';

import '../tool/src/cockpit_demo_sync_lab_verification.dart';

void main() {
  test('sync lab artifact SQL only targets verifier-created tasks', () {
    final countSql = buildSyncLabVerifierArtifactCountSql();
    final cleanupSql = buildSyncLabVerifierArtifactCleanupSql();

    expect(countSql, contains("title like 'Cockpit demo sync conflict %'"));
    expect(
      countSql,
      contains(
        "notes = 'Created by cockpit_demo verifier to exercise sync conflict recovery.'",
      ),
    );
    expect(cleanupSql, contains("delete from task_sync_state"));
    expect(cleanupSql, contains("delete from tasks"));
    expect(cleanupSql, contains("title like 'Cockpit demo sync conflict %'"));
    expect(
      cleanupSql,
      contains(
        "notes = 'Created by cockpit_demo verifier to exercise sync conflict recovery.'",
      ),
    );
  });

  test('buildSyncLabCreateTaskBatch creates a route-aware editor flow', () {
    final commands = buildSyncLabCreateTaskBatch(
      taskTitle: 'Cockpit demo sync conflict 42',
    );

    expect(commands, hasLength(9));
    expect(commands[0]['commandId'], 'verify-open-editor');
    expect(commands[0]['commandType'], 'tap');
    expect(commands[0]['locator'], <String, Object?>{
      'key': 'open-task-editor-action',
      'text': 'New task',
      'type': 'TextButton',
      'route': '/inbox',
      'ancestor': <String, Object?>{'route': '/inbox'},
      'fallbacks': <Map<String, Object?>>[
        <String, Object?>{
          'text': 'Create task',
          'type': 'FilledButton',
          'route': '/inbox',
          'ancestor': <String, Object?>{'route': '/inbox'},
        },
        <String, Object?>{
          'text': 'New task',
          'ancestor': <String, Object?>{'route': '/inbox'},
        },
      ],
    });
    expect(commands[1]['commandId'], 'verify-wait-for-editor-route');
    expect(commands[1]['commandType'], 'waitFor');
    expect(commands[1]['timeoutMs'], 12000);
    expect(commands[1]['parameters'], <String, Object?>{
      'routeName': '/editor',
    });
    expect(commands[2]['commandId'], 'verify-wait-for-editor-title-target');
    expect(commands[2]['commandType'], 'waitFor');
    expect(commands[2]['timeoutMs'], 12000);
    expect(commands[2]['parameters'], <String, Object?>{'text': 'Task title'});
    expect(commands[3]['commandId'], 'verify-enter-task-title');
    expect(commands[3]['commandType'], 'enterText');
    expect(commands[3]['locator'], <String, Object?>{
      'text': 'Task title',
      'ancestor': <String, Object?>{'route': '/editor'},
    });
    expect(commands[3]['parameters'], <String, Object?>{
      'text': 'Cockpit demo sync conflict 42',
    });
    expect(commands[4]['commandId'], 'verify-reveal-task-notes');
    expect(commands[4]['commandType'], 'scrollUntilVisible');
    expect(commands[4]['locator'], <String, Object?>{
      'text': 'Notes',
      'route': '/editor',
      'ancestor': <String, Object?>{'route': '/editor'},
    });
    expect(commands[4]['parameters'], <String, Object?>{
      'maxScrolls': 6,
      'viewportFraction': 0.72,
      'continuous': true,
      'durationPerStepMs': 180,
      'revealAlignment': 'center',
    });
    expect(commands[5]['commandId'], 'verify-focus-task-notes');
    expect(commands[5]['locator'], <String, Object?>{
      'text': 'Notes',
      'ancestor': <String, Object?>{'route': '/editor'},
    });
    expect(commands[6]['commandId'], 'verify-enter-task-notes');
    expect(commands[6]['locator'], <String, Object?>{
      'text': 'Notes',
      'type': 'TextField',
      'ancestor': <String, Object?>{'route': '/editor'},
    });
    expect(commands[7]['commandId'], 'verify-save-task');
    expect(commands[7]['locator'], <String, Object?>{
      'text': 'Save task',
      'ancestor': <String, Object?>{'route': '/editor'},
    });
    expect(commands[8]['commandId'], 'verify-wait-for-inbox-route-after-save');
    expect(commands[8]['commandType'], 'waitFor');
    expect(commands[8]['timeoutMs'], 12000);
    expect(commands[8]['parameters'], <String, Object?>{'routeName': '/inbox'});
  });

  test('route transitions wait for the first interactive target', () {
    final commands = buildSyncLabCreateTaskBatch(
      taskTitle: 'Cockpit demo sync conflict 42',
    );

    expect(commands[1]['parameters'], <String, Object?>{
      'routeName': '/editor',
    });
    expect(commands[2]['commandType'], 'waitFor');
    expect(commands[2]['parameters'], <String, Object?>{'text': 'Task title'});
    expect(commands[3]['commandType'], 'enterText');
    expect(commands[3]['locator'], <String, Object?>{
      'text': 'Task title',
      'ancestor': <String, Object?>{'route': '/editor'},
    });
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
    expect(commands[0]['locator'], <String, Object?>{
      'tooltip': 'Settings',
      'ancestor': <String, Object?>{'route': '/inbox'},
    });
    expect(commands[1]['commandType'], 'scrollUntilVisible');
    expect(commands[1]['locator'], <String, Object?>{
      'text': 'Run queued sync',
      'route': '/settings',
      'ancestor': <String, Object?>{'route': '/settings'},
    });
    expect(commands[1]['parameters'], <String, Object?>{
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
    });
    expect(commands[2]['locator'], <String, Object?>{
      'text': 'Run queued sync',
      'ancestor': <String, Object?>{'route': '/settings'},
    });
    expect(commands[3]['commandType'], 'waitFor');
    expect(commands[3]['parameters'], <String, Object?>{
      'text': 'Conflicts detected',
      'timeoutMs': 20000,
    });
  });

  test('buildSyncLabOpenConflictBatch walks into the conflict screen', () {
    final commands = buildSyncLabOpenConflictBatch(
      taskTitle: 'Cockpit demo sync conflict 42',
    );

    expect(
      commands.map((command) => command['commandId']).toList(growable: false),
      <String>[
        'verify-search-created-task',
        'verify-wait-for-created-task-search-results',
        'verify-open-created-task',
        'verify-wait-for-detail-route',
      ],
    );
    expect(commands[0]['commandType'], 'enterText');
    expect(commands[0]['locator'], <String, Object?>{
      'text': 'Search title or notes',
      'ancestor': <String, Object?>{'route': '/inbox'},
    });
    expect(commands[0]['parameters'], <String, Object?>{
      'text': 'Cockpit demo sync conflict 42',
    });
    expect(commands[1]['commandType'], 'waitFor');
    expect(commands[1]['timeoutMs'], 12000);
    expect(commands[1]['parameters'], <String, Object?>{
      'text': 'Cockpit demo sync conflict 42',
    });
    expect(commands[2]['locator'], <String, Object?>{
      'text': 'Open',
      'type': 'TextButton',
      'ancestor': <String, Object?>{'route': '/inbox'},
    });
    expect(commands[3]['commandType'], 'waitFor');
    expect(commands[3]['timeoutMs'], 12000);
    expect(commands[3]['parameters'], <String, Object?>{
      'routeName': '/detail',
    });
  });

  test('buildSyncLabOpenConflictResolutionCommand targets the detail CTA', () {
    final command = buildSyncLabOpenConflictResolutionCommand();

    expect(command['commandId'], 'verify-open-conflict-resolution');
    expect(command['commandType'], 'tap');
    expect(command['locator'], <String, Object?>{
      'text': 'Resolve conflict',
      'ancestor': <String, Object?>{'route': '/detail'},
    });
  });

  test(
    'buildSyncLabRevealConflictResolutionCommand reveals the detail CTA',
    () {
      final command = buildSyncLabRevealConflictResolutionCommand();

      expect(command['commandId'], 'verify-reveal-conflict-resolution');
      expect(command['commandType'], 'scrollUntilVisible');
      expect(command['locator'], <String, Object?>{
        'text': 'Resolve conflict',
        'route': '/detail',
        'ancestor': <String, Object?>{'route': '/detail'},
      });
    },
  );

  test(
    'buildSyncLabRecoverySyncBatch retries sync after keep-local resolution',
    () {
      final commands = buildSyncLabRecoverySyncBatch();

      expect(
        commands.map((command) => command['commandId']).toList(growable: false),
        <String>[
          'verify-wait-for-detail-route-after-conflict-resolution',
          'verify-return-from-detail',
          'verify-open-sync-settings',
          'verify-scroll-run-queued-sync',
          'verify-run-queued-sync',
          'verify-wait-for-synced-state',
          'verify-close-settings',
        ],
      );
      expect(commands[0]['commandType'], 'waitFor');
      expect(commands[0]['timeoutMs'], 12000);
      expect(commands[0]['parameters'], <String, Object?>{
        'routeName': '/detail',
      });
      expect(commands[1]['commandType'], 'tap');
      expect(commands[1]['locator'], <String, Object?>{
        'tooltip': 'Back',
        'ancestor': <String, Object?>{'route': '/detail'},
      });
      expect(commands[3]['locator'], <String, Object?>{
        'text': 'Run queued sync',
        'route': '/settings',
        'ancestor': <String, Object?>{'route': '/settings'},
      });
      expect(commands[3]['parameters'], <String, Object?>{
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
      });
      expect(commands[4]['locator'], <String, Object?>{
        'text': 'Run queued sync',
        'ancestor': <String, Object?>{'route': '/settings'},
      });
      expect(commands[5]['commandType'], 'waitFor');
      expect(commands[5]['parameters'], <String, Object?>{
        'text': 'Sync complete',
        'timeoutMs': 20000,
      });
    },
  );

  test(
    'buildSyncLabRecoveryVerificationBatch verifies the task becomes synced',
    () {
      final commands = buildSyncLabRecoveryVerificationBatch(
        taskTitle: 'Cockpit demo sync conflict 42',
      );

      expect(
        commands.map((command) => command['commandId']).toList(growable: false),
        <String>[
          'verify-search-created-task-after-recovery',
          'verify-wait-for-created-task-search-results-after-recovery',
          'verify-open-created-task-after-recovery',
          'verify-wait-for-detail-route-after-recovery',
          'verify-assert-task-synced',
        ],
      );
      expect(commands[0]['commandType'], 'enterText');
      expect(commands[0]['locator'], <String, Object?>{
        'text': 'Search title or notes',
        'ancestor': <String, Object?>{'route': '/inbox'},
      });
      expect(commands[0]['parameters'], <String, Object?>{
        'text': 'Cockpit demo sync conflict 42',
      });
      expect(commands[1]['commandType'], 'waitFor');
      expect(commands[1]['timeoutMs'], 12000);
      expect(commands[1]['parameters'], <String, Object?>{
        'text': 'Cockpit demo sync conflict 42',
      });
      expect(commands[2]['locator'], <String, Object?>{
        'text': 'Open',
        'type': 'TextButton',
        'ancestor': <String, Object?>{'route': '/inbox'},
      });
      expect(commands[3]['commandType'], 'waitFor');
      expect(commands[3]['timeoutMs'], 12000);
      expect(commands[3]['parameters'], <String, Object?>{
        'routeName': '/detail',
      });
      expect(commands[4]['commandType'], 'assertText');
      expect(commands[4]['parameters'], <String, Object?>{
        'text': 'Sync synced',
      });
    },
  );

  test(
    'buildSyncLabRevealKeepLocalResolutionCommand reveals keep local CTA',
    () {
      final command = buildSyncLabRevealKeepLocalResolutionCommand();

      expect(command['commandId'], 'verify-reveal-keep-local-resolution');
      expect(command['commandType'], 'scrollUntilVisible');
      expect(command['locator'], <String, Object?>{
        'text': 'Keep local',
        'route': '/sync-conflict',
        'ancestor': <String, Object?>{'route': '/sync-conflict'},
      });
    },
  );
}

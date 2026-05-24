const String syncLabVerifierTaskTitlePrefix = 'Cockpit demo sync conflict ';
const String syncLabVerifierTaskNotes =
    'Created by cockpit_demo verifier to exercise sync conflict recovery.';

String buildSyncLabVerifierArtifactCountSql() {
  return 'select count(*) from tasks where ${_syncLabVerifierWhereClause()};';
}

String buildSyncLabVerifierArtifactCleanupSql() {
  return '''
begin;
delete from task_sync_state
where task_id in (
  select id from tasks
  where ${_syncLabVerifierWhereClause()}
);
delete from tasks
where ${_syncLabVerifierWhereClause()};
commit;
''';
}

List<Map<String, Object?>> buildSyncLabCreateTaskBatch({
  required String taskTitle,
  String notes = syncLabVerifierTaskNotes,
}) {
  return <Map<String, Object?>>[
    <String, Object?>{
      'commandId': 'verify-open-editor',
      'commandType': 'tap',
      'locator': <String, Object?>{
        'text': 'New task',
        'ancestor': <String, Object?>{'route': '/inbox'},
      },
    },
    _waitForRouteCommand(
      commandId: 'verify-wait-for-editor-route',
      routeName: '/editor',
    ),
    <String, Object?>{
      'commandId': 'verify-enter-task-title',
      'commandType': 'enterText',
      'locator': <String, Object?>{
        'text': 'Task title',
        'ancestor': <String, Object?>{'route': '/editor'},
      },
      'parameters': <String, Object?>{'text': taskTitle},
    },
    <String, Object?>{
      'commandId': 'verify-reveal-task-notes',
      'commandType': 'scrollUntilVisible',
      'locator': <String, Object?>{
        'text': 'Notes',
        'route': '/editor',
        'ancestor': <String, Object?>{'route': '/editor'},
      },
      'parameters': <String, Object?>{
        'maxScrolls': 6,
        'viewportFraction': 0.72,
        'continuous': true,
        'durationPerStepMs': 180,
        'revealAlignment': 'center',
      },
    },
    <String, Object?>{
      'commandId': 'verify-focus-task-notes',
      'commandType': 'tap',
      'locator': <String, Object?>{
        'text': 'Notes',
        'ancestor': <String, Object?>{'route': '/editor'},
      },
    },
    <String, Object?>{
      'commandId': 'verify-enter-task-notes',
      'commandType': 'enterText',
      'locator': <String, Object?>{
        'text': 'Notes',
        'type': 'TextField',
        'ancestor': <String, Object?>{'route': '/editor'},
      },
      'parameters': <String, Object?>{'text': notes},
    },
    <String, Object?>{
      'commandId': 'verify-save-task',
      'commandType': 'tap',
      'locator': <String, Object?>{
        'text': 'Save task',
        'ancestor': <String, Object?>{'route': '/editor'},
      },
    },
    _waitForRouteCommand(
      commandId: 'verify-wait-for-inbox-route-after-save',
      routeName: '/inbox',
    ),
  ];
}

List<Map<String, Object?>> buildSyncLabConflictSyncBatch() {
  return <Map<String, Object?>>[
    <String, Object?>{
      'commandId': 'verify-open-sync-settings',
      'commandType': 'tap',
      'locator': <String, Object?>{
        'tooltip': 'Settings',
        'ancestor': <String, Object?>{'route': '/inbox'},
      },
    },
    _scrollRunQueuedSyncCommand(),
    <String, Object?>{
      'commandId': 'verify-run-queued-sync',
      'commandType': 'tap',
      'locator': <String, Object?>{
        'text': 'Run queued sync',
        'ancestor': <String, Object?>{'route': '/settings'},
      },
    },
    _waitForSyncStateCommand(
      commandId: 'verify-wait-for-conflicted-sync-state',
      text: 'Conflicts detected',
    ),
    <String, Object?>{
      'commandId': 'verify-close-settings',
      'commandType': 'tap',
      'locator': <String, Object?>{
        'tooltip': 'Back',
        'ancestor': <String, Object?>{'route': '/settings'},
      },
    },
  ];
}

List<Map<String, Object?>> buildSyncLabOpenConflictBatch({
  required String taskTitle,
}) {
  return <Map<String, Object?>>[
    _searchForTaskCommand(
      commandId: 'verify-search-created-task',
      taskTitle: taskTitle,
    ),
    _waitForTaskSearchResultCommand(
      commandId: 'verify-wait-for-created-task-search-results',
      taskTitle: taskTitle,
    ),
    <String, Object?>{
      'commandId': 'verify-open-created-task',
      'commandType': 'tap',
      'locator': <String, Object?>{
        'text': 'Open',
        'type': 'TextButton',
        'ancestor': <String, Object?>{'route': '/inbox'},
      },
    },
    _waitForRouteCommand(
      commandId: 'verify-wait-for-detail-route',
      routeName: '/detail',
    ),
  ];
}

Map<String, Object?> buildSyncLabOpenConflictResolutionCommand() {
  return <String, Object?>{
    'commandId': 'verify-open-conflict-resolution',
    'commandType': 'tap',
    'locator': <String, Object?>{
      'text': 'Resolve conflict',
      'ancestor': <String, Object?>{'route': '/detail'},
    },
  };
}

Map<String, Object?> buildSyncLabRevealConflictResolutionCommand() {
  return _revealBelowFoldCommand(
    commandId: 'verify-reveal-conflict-resolution',
    text: 'Resolve conflict',
    route: '/detail',
  );
}

Map<String, Object?> buildSyncLabKeepLocalResolutionCommand() {
  return <String, Object?>{
    'commandId': 'verify-keep-local-resolution',
    'commandType': 'tap',
    'locator': <String, Object?>{
      'text': 'Keep local',
      'ancestor': <String, Object?>{'route': '/sync-conflict'},
    },
  };
}

Map<String, Object?> buildSyncLabRevealKeepLocalResolutionCommand() {
  return _revealBelowFoldCommand(
    commandId: 'verify-reveal-keep-local-resolution',
    text: 'Keep local',
    route: '/sync-conflict',
  );
}

List<Map<String, Object?>> buildSyncLabRecoverySyncBatch() {
  return <Map<String, Object?>>[
    <String, Object?>{
      'commandId': 'verify-return-from-detail',
      'commandType': 'tap',
      'locator': <String, Object?>{
        'tooltip': 'Back',
        'ancestor': <String, Object?>{'route': '/detail'},
      },
    },
    <String, Object?>{
      'commandId': 'verify-open-sync-settings',
      'commandType': 'tap',
      'locator': <String, Object?>{
        'tooltip': 'Settings',
        'ancestor': <String, Object?>{'route': '/inbox'},
      },
    },
    _scrollRunQueuedSyncCommand(),
    <String, Object?>{
      'commandId': 'verify-run-queued-sync',
      'commandType': 'tap',
      'locator': <String, Object?>{
        'text': 'Run queued sync',
        'ancestor': <String, Object?>{'route': '/settings'},
      },
    },
    _waitForSyncStateCommand(
      commandId: 'verify-wait-for-synced-state',
      text: 'Sync complete',
    ),
    <String, Object?>{
      'commandId': 'verify-close-settings',
      'commandType': 'tap',
      'locator': <String, Object?>{
        'tooltip': 'Back',
        'ancestor': <String, Object?>{'route': '/settings'},
      },
    },
  ];
}

List<Map<String, Object?>> buildSyncLabRecoveryVerificationBatch({
  required String taskTitle,
}) {
  return <Map<String, Object?>>[
    _searchForTaskCommand(
      commandId: 'verify-search-created-task-after-recovery',
      taskTitle: taskTitle,
    ),
    _waitForTaskSearchResultCommand(
      commandId: 'verify-wait-for-created-task-search-results-after-recovery',
      taskTitle: taskTitle,
    ),
    <String, Object?>{
      'commandId': 'verify-open-created-task-after-recovery',
      'commandType': 'tap',
      'locator': <String, Object?>{
        'text': 'Open',
        'type': 'TextButton',
        'ancestor': <String, Object?>{'route': '/inbox'},
      },
    },
    _waitForRouteCommand(
      commandId: 'verify-wait-for-detail-route-after-recovery',
      routeName: '/detail',
    ),
    <String, Object?>{
      'commandId': 'verify-assert-task-synced',
      'commandType': 'assertText',
      'parameters': <String, Object?>{'text': 'Sync synced'},
    },
  ];
}

Map<String, Object?> _searchForTaskCommand({
  required String commandId,
  required String taskTitle,
}) {
  return <String, Object?>{
    'commandId': commandId,
    'commandType': 'enterText',
    'locator': <String, Object?>{
      'text': 'Search title or notes',
      'ancestor': <String, Object?>{'route': '/inbox'},
    },
    'parameters': <String, Object?>{'text': taskTitle},
  };
}

Map<String, Object?> _revealBelowFoldCommand({
  required String commandId,
  required String text,
  required String route,
}) {
  return <String, Object?>{
    'commandId': commandId,
    'commandType': 'scrollUntilVisible',
    'locator': <String, Object?>{
      'text': text,
      'route': route,
      'ancestor': <String, Object?>{'route': route},
    },
    'parameters': <String, Object?>{
      'maxScrolls': 6,
      'viewportFraction': 0.72,
      'continuous': true,
      'durationPerStepMs': 180,
      'revealAlignment': 'center',
    },
  };
}

Map<String, Object?> _waitForTaskSearchResultCommand({
  required String commandId,
  required String taskTitle,
}) {
  return <String, Object?>{
    'commandId': commandId,
    'commandType': 'waitFor',
    'timeoutMs': 12000,
    'parameters': <String, Object?>{'text': taskTitle},
  };
}

Map<String, Object?> _waitForSyncStateCommand({
  required String commandId,
  required String text,
}) {
  return <String, Object?>{
    'commandId': commandId,
    'commandType': 'waitFor',
    'parameters': <String, Object?>{'text': text, 'timeoutMs': 20000},
  };
}

Map<String, Object?> _waitForRouteCommand({
  required String commandId,
  required String routeName,
}) {
  return <String, Object?>{
    'commandId': commandId,
    'commandType': 'waitFor',
    'timeoutMs': 12000,
    'parameters': <String, Object?>{
      'routeName': routeName,
      'requireVisibleTargets': true,
    },
  };
}

String _syncLabVerifierWhereClause() {
  final escapedPrefix = syncLabVerifierTaskTitlePrefix.replaceAll("'", "''");
  final escapedNotes = syncLabVerifierTaskNotes.replaceAll("'", "''");
  return "title like '$escapedPrefix%' and notes = '$escapedNotes'";
}

Map<String, Object?> _scrollRunQueuedSyncCommand() {
  return <String, Object?>{
    'commandId': 'verify-scroll-run-queued-sync',
    'commandType': 'scrollUntilVisible',
    'locator': <String, Object?>{
      'text': 'Run queued sync',
      'route': '/settings',
      'ancestor': <String, Object?>{'route': '/settings'},
    },
    'parameters': <String, Object?>{
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
  };
}

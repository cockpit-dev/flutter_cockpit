import 'dart:convert';
import 'dart:io';

import 'package:cockpit/cockpit.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('CockpitLiveRunStore', () {
    test('creates readable microsecond-precision run ids', () {
      expect(
        cockpitCreateLiveRunId(
          'checkout/proof',
          now: DateTime.utc(2026, 6, 19, 7, 0, 3, 4, 5),
        ),
        '20260619T070003004005Z_checkout-proof',
      );
    });

    test(
      'persists live state, run index, and monotonic redacted events',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'cockpit_live_store_test',
        );
        addTearDown(() async {
          if (tempDir.existsSync()) {
            await tempDir.delete(recursive: true);
          }
        });

        final clock = _TickingClock(<DateTime>[
          DateTime.utc(2026, 6, 19, 7),
          DateTime.utc(2026, 6, 19, 7, 0, 1),
          DateTime.utc(2026, 6, 19, 7, 0, 2),
          DateTime.utc(2026, 6, 19, 7, 0, 3),
        ]);
        final store = CockpitLiveRunStore(
          historyRoot: tempDir.path,
          runId: 'checkout/proof',
          displayName: 'Checkout proof',
          clock: clock,
          recentEventLimit: 2,
        );

        await store.initialize(
          sessionId: 'session-1',
          taskId: 'task-1',
          platform: 'macos',
        );
        final first = await store.appendEvent(
          type: 'run_started',
          status: 'running',
          details: const <String, Object?>{'Authorization': 'Bearer abc'},
        );
        final second = await store.appendEvent(
          type: 'workflow_step_started',
          status: 'running',
          stage: 'control',
          workflowStepId: 'open-settings',
          workflowStepType: 'command',
          description: 'Open settings before changing sync behavior.',
          commandId: 'tap-settings',
          commandType: 'tap',
        );
        final third = await store.appendEvent(
          type: 'artifact_captured',
          status: 'running',
          artifactRefs: const <Map<String, Object?>>[
            <String, Object?>{
              'role': 'screenshot',
              'relativePath': 'screenshots/20260619T070003000000Z_step.png',
            },
          ],
        );

        expect(first.seq, 1);
        expect(second.seq, 2);
        expect(third.seq, 3);
        expect(store.recentEvents.map((event) => event.seq), <int>[2, 3]);
        expect(
          p.isWithin(p.join(tempDir.path, 'runs'), store.runDirectory.path),
          isTrue,
        );
        expect(store.runDirectory.path, isNot(contains('..')));

        final eventLines = File(
          p.join(store.liveDirectory.path, 'events.ndjson'),
        ).readAsLinesSync();
        expect(eventLines, hasLength(3));
        final firstEvent = jsonDecode(eventLines.first) as Map<String, Object?>;
        expect(firstEvent['seq'], 1);
        expect(firstEvent['runId'], 'checkout/proof');
        expect(
          (firstEvent['details']! as Map<String, Object?>)['Authorization'],
          CockpitSensitiveDataRedactor.redactedValue,
        );

        final stateJson =
            jsonDecode(
                  File(
                    p.join(store.liveDirectory.path, 'live_state.json'),
                  ).readAsStringSync(),
                )
                as Map<String, Object?>;
        expect(stateJson['runId'], 'checkout/proof');
        expect(stateJson['status'], 'running');
        expect(stateJson['platform'], 'macos');
        expect(stateJson['updatedAt'], '2026-06-19T07:00:03.000Z');
        expect((stateJson['counts']! as Map<String, Object?>)['eventCount'], 3);
        expect(
          (stateJson['currentStep']! as Map<String, Object?>)['description'],
          'Open settings before changing sync behavior.',
        );
        expect(stateJson['recentArtifacts'], hasLength(1));

        final indexJson =
            jsonDecode(
                  File(p.join(tempDir.path, 'index.json')).readAsStringSync(),
                )
                as Map<String, Object?>;
        expect(indexJson['schemaVersion'], 1);
        expect(indexJson['runCount'], 1);
        expect(
          (indexJson['runs']! as List<Object?>).single,
          containsPair('runId', 'checkout/proof'),
        );
      },
    );

    test(
      'writes live_state atomically and rejects escaped run paths',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'cockpit_live_store_path_test',
        );
        addTearDown(() async {
          if (tempDir.existsSync()) {
            await tempDir.delete(recursive: true);
          }
        });

        final store = CockpitLiveRunStore(
          historyRoot: tempDir.path,
          runId: '../../escape',
          clock: _FixedClock(DateTime.utc(2026, 6, 19, 8)),
        );

        await store.initialize(platform: 'linux');
        await store.updateState(
          (state) => state.copyWith(
            stage: 'capture',
            recommendedNextStep: 'Inspect the screenshot before claiming done.',
          ),
        );

        final stateFile = File(
          p.join(store.liveDirectory.path, 'live_state.json'),
        );
        expect(stateFile.existsSync(), isTrue);
        final stateJson =
            jsonDecode(stateFile.readAsStringSync()) as Map<String, Object?>;
        expect(stateJson['stage'], 'capture');
        expect(
          stateJson['recommendedNextStep'],
          'Inspect the screenshot before claiming done.',
        );
        expect(
          store.liveDirectory
              .listSync()
              .where((entity) => p.basename(entity.path).contains('.tmp'))
              .toList(),
          isEmpty,
        );

        expect(
          () => store.resolveRunPath('../outside.txt'),
          throwsA(isA<CockpitLiveRunPathException>()),
        );
        expect(
          () => store.resolveRunPath(p.join(tempDir.path, 'outside.txt')),
          throwsA(isA<CockpitLiveRunPathException>()),
        );
        expect(
          p.isWithin(p.join(tempDir.path, 'runs'), store.runDirectory.path),
          isTrue,
        );
        expect(store.runDirectory.path, isNot(contains('..')));
      },
    );

    test('writes scoped history indexes for isolated work sessions', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_live_store_scope_test',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final older = CockpitLiveRunStore(
        historyRoot: tempDir.path,
        runId: 'run-old',
        displayName: 'Old task',
        clock: _FixedClock(DateTime.utc(2026, 6, 19, 10)),
      );
      await older.initialize(
        sessionId: 'session-old',
        taskId: 'task-old',
        platform: 'macos',
      );

      final newer = CockpitLiveRunStore(
        historyRoot: tempDir.path,
        runId: 'run-new',
        displayName: 'New task',
        clock: _FixedClock(DateTime.utc(2026, 6, 19, 11)),
      );
      await newer.initialize(
        sessionId: 'session-new',
        taskId: 'task-new',
        platform: 'android',
      );

      final indexJson =
          jsonDecode(
                File(p.join(tempDir.path, 'index.json')).readAsStringSync(),
              )
              as Map<String, Object?>;
      expect(indexJson['runCount'], 2);
      expect(indexJson['scopeCount'], 2);
      expect(indexJson['currentScopeId'], 'session-new');

      final runs = (indexJson['runs']! as List<Object?>)
          .cast<Map<String, Object?>>();
      expect(runs.first, containsPair('runId', 'run-new'));
      expect(runs.first, containsPair('scopeId', 'session-new'));
      expect(runs.first, containsPair('scopeKind', 'session'));
      expect(runs.first, containsPair('scopeLabel', 'task-new'));

      final scopes = (indexJson['scopes']! as List<Object?>)
          .cast<Map<String, Object?>>();
      expect(scopes.map((scope) => scope['scopeId']), <String>[
        'session-new',
        'session-old',
      ]);
      expect(scopes.first, containsPair('latestRunId', 'run-new'));
      expect(scopes.first, containsPair('runCount', 1));

      final scopesIndex =
          jsonDecode(
                File(
                  p.join(tempDir.path, 'scopes', 'index.json'),
                ).readAsStringSync(),
              )
              as Map<String, Object?>;
      expect(scopesIndex['currentScopeId'], 'session-new');
      expect(scopesIndex['scopeCount'], 2);

      final newScopeDir = scopes.first['scopeDir']! as String;
      final scopedIndex =
          jsonDecode(
                File(
                  p.join(tempDir.path, newScopeDir, 'index.json'),
                ).readAsStringSync(),
              )
              as Map<String, Object?>;
      expect(scopedIndex['scopeId'], 'session-new');
      expect(scopedIndex['runCount'], 1);
      expect(
        (scopedIndex['runs']! as List<Object?>).single,
        containsPair('runId', 'run-new'),
      );
    });

    test(
      'groups repeated workflow runs by stable session scope while keeping run history',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'cockpit_live_store_session_history_test',
        );
        addTearDown(() async {
          if (tempDir.existsSync()) {
            await tempDir.delete(recursive: true);
          }
        });

        final first = CockpitLiveRunStore(
          historyRoot: tempDir.path,
          runId: 'checkout-run-1',
          displayName: 'Checkout attempt 1',
          clock: _FixedClock(DateTime.utc(2026, 6, 19, 13)),
        );
        await first.initialize(
          sessionId: 'checkout-work',
          taskId: 'checkout-proof',
          platform: 'macos',
        );

        final second = CockpitLiveRunStore(
          historyRoot: tempDir.path,
          runId: 'checkout-run-2',
          displayName: 'Checkout attempt 2',
          clock: _FixedClock(DateTime.utc(2026, 6, 19, 13, 5)),
        );
        await second.initialize(
          sessionId: 'checkout-work',
          taskId: 'checkout-proof',
          platform: 'macos',
        );

        final third = CockpitLiveRunStore(
          historyRoot: tempDir.path,
          runId: 'settings-run-1',
          displayName: 'Settings attempt 1',
          clock: _FixedClock(DateTime.utc(2026, 6, 19, 13, 10)),
        );
        await third.initialize(
          sessionId: 'settings-work',
          taskId: 'settings-proof',
          platform: 'android',
        );

        final indexJson =
            jsonDecode(
                  File(p.join(tempDir.path, 'index.json')).readAsStringSync(),
                )
                as Map<String, Object?>;
        expect(indexJson['runCount'], 3);
        expect(indexJson['scopeCount'], 2);
        expect(indexJson['currentScopeId'], 'settings-work');

        final scopes = (indexJson['scopes']! as List<Object?>)
            .cast<Map<String, Object?>>();
        final checkoutScope = scopes.singleWhere(
          (scope) => scope['scopeId'] == 'checkout-work',
        );
        expect(checkoutScope['runCount'], 2);
        expect(checkoutScope['latestRunId'], 'checkout-run-2');
        expect(checkoutScope['scopeLabel'], 'checkout-proof');

        final checkoutIndex =
            jsonDecode(
                  File(
                    p.join(
                      tempDir.path,
                      checkoutScope['scopeDir']! as String,
                      'index.json',
                    ),
                  ).readAsStringSync(),
                )
                as Map<String, Object?>;
        expect(checkoutIndex['runCount'], 2);
        expect(
          (checkoutIndex['runs']! as List<Object?>)
              .cast<Map<String, Object?>>()
              .map((run) => run['runId']),
          <String>['checkout-run-2', 'checkout-run-1'],
        );
      },
    );

    test(
      'uses collision-resistant readable directories for long ids',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'cockpit_live_store_long_id_test',
        );
        addTearDown(() async {
          if (tempDir.existsSync()) {
            await tempDir.delete(recursive: true);
          }
        });

        final commonPrefix = 'a' * 120;
        final first = CockpitLiveRunStore(
          historyRoot: tempDir.path,
          runId: '${commonPrefix}one',
          clock: _FixedClock(DateTime.utc(2026, 6, 19, 14)),
        );
        await first.initialize(
          sessionId: '${commonPrefix}one',
          platform: 'macos',
        );

        final second = CockpitLiveRunStore(
          historyRoot: tempDir.path,
          runId: '${commonPrefix}two',
          clock: _FixedClock(DateTime.utc(2026, 6, 19, 14, 1)),
        );
        await second.initialize(
          sessionId: '${commonPrefix}two',
          platform: 'macos',
        );

        expect(first.runDirectory.path, isNot(second.runDirectory.path));
        expect(p.basename(first.runDirectory.path), hasLength(96));
        expect(p.basename(second.runDirectory.path), hasLength(96));

        final indexJson =
            jsonDecode(
                  File(p.join(tempDir.path, 'index.json')).readAsStringSync(),
                )
                as Map<String, Object?>;
        final scopes = (indexJson['scopes']! as List<Object?>)
            .cast<Map<String, Object?>>();
        expect(scopes.map((scope) => scope['scopeDir']).toSet(), hasLength(2));
        for (final scope in scopes) {
          final scopeDir = scope['scopeDir']! as String;
          expect(
            File(p.join(tempDir.path, scopeDir, 'index.json')).existsSync(),
            isTrue,
          );
        }
      },
    );

    test(
      'uses collision-resistant directories when short ids sanitize alike',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'cockpit_live_store_short_id_collision_test',
        );
        addTearDown(() async {
          if (tempDir.existsSync()) {
            await tempDir.delete(recursive: true);
          }
        });

        final first = CockpitLiveRunStore(
          historyRoot: tempDir.path,
          runId: 'checkout/flow',
          clock: _FixedClock(DateTime.utc(2026, 6, 19, 15)),
        );
        await first.initialize(
          sessionId: 'checkout/flow',
          taskId: 'checkout',
          platform: 'macos',
        );

        final second = CockpitLiveRunStore(
          historyRoot: tempDir.path,
          runId: 'checkout-flow',
          clock: _FixedClock(DateTime.utc(2026, 6, 19, 15, 1)),
        );
        await second.initialize(
          sessionId: 'checkout-flow',
          taskId: 'checkout',
          platform: 'macos',
        );

        expect(first.runDirectory.path, isNot(second.runDirectory.path));

        final indexJson =
            jsonDecode(
                  File(p.join(tempDir.path, 'index.json')).readAsStringSync(),
                )
                as Map<String, Object?>;
        final scopes = (indexJson['scopes']! as List<Object?>)
            .cast<Map<String, Object?>>();
        expect(scopes.map((scope) => scope['scopeId']).toSet(), {
          'checkout/flow',
          'checkout-flow',
        });
        expect(scopes.map((scope) => scope['scopeDir']).toSet(), hasLength(2));
        for (final scope in scopes) {
          expect(
            File(
              p.join(tempDir.path, scope['scopeDir']! as String, 'index.json'),
            ).existsSync(),
            isTrue,
          );
        }
      },
    );

    test(
      'serializes shared history index writes across concurrent runs',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'cockpit_live_store_concurrent_scope_test',
        );
        addTearDown(() async {
          if (tempDir.existsSync()) {
            await tempDir.delete(recursive: true);
          }
        });

        await Future.wait(
          List<Future<void>>.generate(8, (index) async {
            final store = CockpitLiveRunStore(
              historyRoot: tempDir.path,
              runId: 'run-$index',
              displayName: 'Task $index',
              clock: _FixedClock(DateTime.utc(2026, 6, 19, 12, index)),
            );
            await store.initialize(
              sessionId: 'session-$index',
              taskId: 'task-$index',
              platform: index.isEven ? 'android' : 'macos',
            );
            await store.appendEvent(
              type: 'run_started',
              status: 'running',
              stage: 'setup',
            );
          }),
        );

        final indexJson =
            jsonDecode(
                  File(p.join(tempDir.path, 'index.json')).readAsStringSync(),
                )
                as Map<String, Object?>;
        expect(indexJson['runCount'], 8);
        expect(indexJson['scopeCount'], 8);
        final runs = (indexJson['runs']! as List<Object?>)
            .cast<Map<String, Object?>>();
        expect(runs.map((run) => run['runId']).toSet(), {
          for (var index = 0; index < 8; index += 1) 'run-$index',
        });

        final scopesIndex =
            jsonDecode(
                  File(
                    p.join(tempDir.path, 'scopes', 'index.json'),
                  ).readAsStringSync(),
                )
                as Map<String, Object?>;
        expect(scopesIndex['scopeCount'], 8);
        final scopes = (scopesIndex['scopes']! as List<Object?>)
            .cast<Map<String, Object?>>();
        expect(scopes.map((scope) => scope['scopeId']).toSet(), {
          for (var index = 0; index < 8; index += 1) 'session-$index',
        });
      },
    );

    test(
      'normalizes legacy run entries when rewriting history indexes',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'cockpit_live_store_legacy_scope_test',
        );
        addTearDown(() async {
          if (tempDir.existsSync()) {
            await tempDir.delete(recursive: true);
          }
        });
        File(p.join(tempDir.path, 'index.json')).writeAsStringSync(
          jsonEncode(<String, Object?>{
            'schemaVersion': 1,
            'updatedAt': '2026-06-19T09:00:00.000Z',
            'runCount': 1,
            'runs': <Object?>[
              <String, Object?>{
                'runId': 'legacy-run',
                'status': 'completed',
                'updatedAt': '2026-06-19T09:00:00.000Z',
                'runDir': 'runs/legacy-run',
                'liveDir': 'runs/legacy-run/live',
                'sessionId': 'legacy-session',
                'taskId': 'legacy-task',
                'platform': 'ios',
              },
            ],
          }),
        );

        final store = CockpitLiveRunStore(
          historyRoot: tempDir.path,
          runId: 'new-run',
          clock: _FixedClock(DateTime.utc(2026, 6, 19, 10)),
        );
        await store.initialize(
          sessionId: 'new-session',
          taskId: 'new-task',
          platform: 'macos',
        );

        final indexJson =
            jsonDecode(
                  File(p.join(tempDir.path, 'index.json')).readAsStringSync(),
                )
                as Map<String, Object?>;
        final runs = (indexJson['runs']! as List<Object?>)
            .cast<Map<String, Object?>>();
        final legacyRun = runs.singleWhere(
          (run) => run['runId'] == 'legacy-run',
        );
        expect(legacyRun, containsPair('scopeId', 'legacy-session'));
        expect(legacyRun, containsPair('scopeKind', 'session'));
        expect(legacyRun, containsPair('scopeLabel', 'legacy-task'));

        final legacyScope =
            jsonDecode(
                  File(
                    p.join(
                      tempDir.path,
                      'scopes',
                      'legacy-session',
                      'index.json',
                    ),
                  ).readAsStringSync(),
                )
                as Map<String, Object?>;
        expect(legacyScope['runCount'], 1);
        expect(
          (legacyScope['runs']! as List<Object?>).single,
          containsPair('runId', 'legacy-run'),
        );
      },
    );

    test('keeps run status active for failed workflow step events', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_live_store_step_status_test',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final store = CockpitLiveRunStore(
        historyRoot: tempDir.path,
        runId: 'step-status',
        clock: _TickingClock(<DateTime>[
          DateTime.utc(2026, 6, 19, 9),
          DateTime.utc(2026, 6, 19, 9, 0, 1),
          DateTime.utc(2026, 6, 19, 9, 0, 2),
        ]),
      );

      await store.initialize(platform: 'macos');
      await store.appendEvent(
        type: 'workflow_step_completed',
        status: 'failed',
        stage: 'control',
        workflowStepId: 'tap-settings',
        workflowStepType: 'command',
        error: const <String, Object?>{'message': 'Settings was not visible.'},
      );

      expect(store.state!.status, 'running');
      expect(store.state!.finishedAt, isNull);
      expect(store.state!.counts['errorCount'], 1);
      expect(store.state!.lastError, containsPair('message', isNotEmpty));

      await store.appendEvent(
        type: 'run_finished',
        status: 'failed',
        stage: 'finish',
        error: const <String, Object?>{'message': 'Task failed.'},
      );

      expect(store.state!.status, 'failed');
      expect(store.state!.finishedAt, DateTime.utc(2026, 6, 19, 9, 0, 2));
    });
  });
}

final class _FixedClock implements CockpitClock {
  const _FixedClock(this.value);

  final DateTime value;

  @override
  DateTime now() => value;
}

final class _TickingClock implements CockpitClock {
  _TickingClock(this._values);

  final List<DateTime> _values;
  var _index = 0;

  @override
  DateTime now() {
    if (_index >= _values.length) {
      return _values.last;
    }
    return _values[_index++].toUtc();
  }
}

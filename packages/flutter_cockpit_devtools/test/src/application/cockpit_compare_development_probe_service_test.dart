import 'dart:convert';
import 'dart:io';

import 'package:flutter_cockpit_devtools/src/application/cockpit_compare_development_probe_service.dart';
import 'package:flutter_cockpit_devtools/src/development/cockpit_development_probe_delta.dart';
import 'package:flutter_cockpit_devtools/src/development/cockpit_development_probe.dart';
import 'package:flutter_cockpit_devtools/src/development/cockpit_development_session_status.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('development session status round-trips all operational states', () {
    for (final state in CockpitDevelopmentSessionState.values) {
      final status = CockpitDevelopmentSessionStatus(
        developmentSessionId: 'dev-session-1',
        state: state,
        appReachable: state == CockpitDevelopmentSessionState.ready,
        remoteSessionReachable: state == CockpitDevelopmentSessionState.ready,
        reloadGeneration: 4,
        lastReloadMode: CockpitDevelopmentReloadMode.hotReload,
        lastReloadSucceeded: state != CockpitDevelopmentSessionState.failed,
        lastError: state == CockpitDevelopmentSessionState.failed
            ? 'machine process exited'
            : null,
        lastStatusAt: DateTime.utc(2026, 3, 23, 2),
      );

      expect(
        CockpitDevelopmentSessionStatus.fromJson(status.toJson()).toJson(),
        status.toJson(),
      );
    }
  });

  test('development probe delta round-trips through json', () {
    final delta = CockpitDevelopmentProbeDelta(
      fromProbeId: 'probe-1',
      toProbeId: 'probe-2',
      reloadGenerationChanged: true,
      routeChanged: false,
      addedVisibleText: const ['Updated heading'],
      removedVisibleText: const ['Old heading'],
      addedSemanticIds: const ['settings-theme-toggle'],
      removedSemanticIds: const ['settings-old-toggle'],
      addedInteractiveLabels: const ['Save'],
      removedInteractiveLabels: const ['Apply'],
      addedVisualSignals: const ['Text|Save|24,80,120x28|#FFFFFF|24.0|w700'],
      removedVisualSignals: const ['Text|Save|20,80,120x28|#FFFFFF|20.0|w600'],
      focusChanged: true,
      overlayChanged: false,
      visualChanged: true,
      screenshotChanged: true,
      newNetworkFailures: const ['/sync failed'],
      newRuntimeErrors: const ['RenderFlex overflowed'],
      newRebuildHotspots: const ['TaskListItem x8'],
      changeSummary: 'UI text updated and one new runtime error appeared.',
    );

    expect(
      CockpitDevelopmentProbeDelta.fromJson(delta.toJson()).toJson(),
      delta.toJson(),
    );
  });

  test(
    'compare produces route, semantic, network, runtime, and rebuild deltas',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_compare_development_probe',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final fromProbe = CockpitDevelopmentProbe(
        probeId: 'probe-before',
        sessionId: 'dev-session-1',
        reloadGeneration: 1,
        capturedAt: DateTime.utc(2026, 3, 23, 1, 0),
        reason: CockpitDevelopmentProbeReason.manual,
        checkpoint: 'before_edit',
        profile: CockpitDevelopmentProbeProfile.interactive,
        routeName: '/inbox',
        ui: const <String, Object?>{
          'visibleTextPreviews': <String>['Inbox', 'Search'],
          'visibleSemanticIds': <String>['search-field'],
          'interactiveLabels': <String>['Search', 'Create'],
          'focusedTargetLabel': 'Search',
          'overlayLabels': <String>[],
        },
        network: const <String, Object?>{
          'failureSignals': <String>['GET /sync -> 500 timeout'],
        },
        runtime: const <String, Object?>{'errorSignals': <String>[]},
        rebuild: const <String, Object?>{
          'hotspots': <String>['task-list'],
        },
      );
      final toProbe = CockpitDevelopmentProbe(
        probeId: 'probe-after',
        sessionId: 'dev-session-1',
        reloadGeneration: 2,
        capturedAt: DateTime.utc(2026, 3, 23, 1, 5),
        reason: CockpitDevelopmentProbeReason.postReload,
        checkpoint: 'after_reload',
        profile: CockpitDevelopmentProbeProfile.diagnostic,
        routeName: '/settings',
        ui: const <String, Object?>{
          'visibleTextPreviews': <String>['Settings', 'Theme'],
          'visibleSemanticIds': <String>[
            'settings-theme-toggle',
            'settings-save-button',
          ],
          'interactiveLabels': <String>['Theme', 'Save'],
          'focusedTargetLabel': 'Theme',
          'overlayLabels': <String>['Theme dialog'],
        },
        network: const <String, Object?>{
          'failureSignals': <String>[
            'GET /sync -> 500 timeout',
            'POST /settings/save -> 500 server error',
          ],
        },
        runtime: const <String, Object?>{
          'errorSignals': <String>['flutter_error:error:RenderFlex overflowed'],
        },
        rebuild: const <String, Object?>{
          'hotspots': <String>['task-list', 'settings.theme'],
        },
      );

      final fromFile = File(p.join(tempDir.path, 'before_probe.json'));
      final toFile = File(p.join(tempDir.path, 'after_probe.json'));
      await fromFile.writeAsString(jsonEncode(fromProbe.toJson()));
      await toFile.writeAsString(jsonEncode(toProbe.toJson()));

      final service = const CockpitCompareDevelopmentProbeService();
      final result = await service.compare(
        CockpitCompareDevelopmentProbeRequest(
          fromProbePath: fromFile.path,
          toProbePath: toFile.path,
        ),
      );

      expect(result.delta.fromProbeId, 'probe-before');
      expect(result.delta.toProbeId, 'probe-after');
      expect(result.delta.reloadGenerationChanged, isTrue);
      expect(result.delta.routeChanged, isTrue);
      expect(
        result.delta.addedVisibleText,
        orderedEquals(const <String>['Settings', 'Theme']),
      );
      expect(
        result.delta.removedVisibleText,
        orderedEquals(const <String>['Inbox', 'Search']),
      );
      expect(
        result.delta.addedSemanticIds,
        orderedEquals(const <String>[
          'settings-theme-toggle',
          'settings-save-button',
        ]),
      );
      expect(
        result.delta.removedSemanticIds,
        orderedEquals(const <String>['search-field']),
      );
      expect(
        result.delta.addedInteractiveLabels,
        orderedEquals(const <String>['Theme', 'Save']),
      );
      expect(
        result.delta.removedInteractiveLabels,
        orderedEquals(const <String>['Search', 'Create']),
      );
      expect(result.delta.focusChanged, isTrue);
      expect(result.delta.overlayChanged, isTrue);
      expect(
        result.delta.newNetworkFailures,
        orderedEquals(const <String>[
          'POST /settings/save -> 500 server error',
        ]),
      );
      expect(
        result.delta.newRuntimeErrors,
        orderedEquals(const <String>[
          'flutter_error:error:RenderFlex overflowed',
        ]),
      );
      expect(
        result.delta.newRebuildHotspots,
        orderedEquals(const <String>['settings.theme']),
      );
      expect(
        result.delta.changeSummary,
        allOf(contains('route'), contains('visible text'), contains('runtime')),
      );
    },
  );

  test('compare accepts collect-development-probe wrapper payloads', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'cockpit_compare_development_probe_wrapped',
    );
    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    final fromProbe = CockpitDevelopmentProbe(
      probeId: 'probe-before',
      sessionId: 'dev-session-1',
      reloadGeneration: 0,
      capturedAt: DateTime.utc(2026, 3, 23, 2, 0),
      reason: CockpitDevelopmentProbeReason.manual,
      profile: CockpitDevelopmentProbeProfile.quick,
      routeName: '/inbox',
      ui: const <String, Object?>{
        'visibleTextPreviews': <String>['Inbox'],
        'visibleSemanticIds': <String>[],
        'interactiveLabels': <String>['Inbox'],
      },
    );
    final toProbe = CockpitDevelopmentProbe(
      probeId: 'probe-after',
      sessionId: 'dev-session-1',
      reloadGeneration: 1,
      capturedAt: DateTime.utc(2026, 3, 23, 2, 1),
      reason: CockpitDevelopmentProbeReason.postReload,
      profile: CockpitDevelopmentProbeProfile.interactive,
      routeName: '/today',
      ui: const <String, Object?>{
        'visibleTextPreviews': <String>['Today'],
        'visibleSemanticIds': <String>[],
        'interactiveLabels': <String>['Today'],
      },
    );

    final fromFile = File(p.join(tempDir.path, 'before_probe.json'));
    final toFile = File(p.join(tempDir.path, 'after_probe.json'));
    await fromFile.writeAsString(
      jsonEncode(<String, Object?>{'probe': fromProbe.toJson()}),
    );
    await toFile.writeAsString(
      jsonEncode(<String, Object?>{'probe': toProbe.toJson()}),
    );

    final result = await const CockpitCompareDevelopmentProbeService().compare(
      CockpitCompareDevelopmentProbeRequest(
        fromProbePath: fromFile.path,
        toProbePath: toFile.path,
      ),
    );

    expect(result.fromProbe.probeId, 'probe-before');
    expect(result.toProbe.probeId, 'probe-after');
    expect(result.delta.routeChanged, isTrue);
  });

  test(
    'compare reports visual-only changes even when text and semantics match',
    () async {
      final fromProbe = CockpitDevelopmentProbe(
        probeId: 'probe-before-visual',
        sessionId: 'dev-session-1',
        reloadGeneration: 1,
        capturedAt: DateTime.utc(2026, 3, 23, 3, 0),
        reason: CockpitDevelopmentProbeReason.manual,
        profile: CockpitDevelopmentProbeProfile.interactive,
        routeName: '/detail',
        ui: const <String, Object?>{
          'visibleTextPreviews': <String>['Release readiness audit'],
          'visibleSemanticIds': <String>['detail-title'],
          'interactiveLabels': <String>['Back'],
          'visualSignals': <String>[
            'Text|Release readiness audit|24.0,88.0,220.0x28.0|#FFFEF3C7|24.0|w700',
          ],
        },
        artifacts: const <String, Object?>{
          'screenshotPath': '/tmp/before.png',
          'screenshotDigest': 'fnv1a64:before',
        },
      );
      final toProbe = CockpitDevelopmentProbe(
        probeId: 'probe-after-visual',
        sessionId: 'dev-session-1',
        reloadGeneration: 2,
        capturedAt: DateTime.utc(2026, 3, 23, 3, 1),
        reason: CockpitDevelopmentProbeReason.postReload,
        profile: CockpitDevelopmentProbeProfile.interactive,
        routeName: '/detail',
        ui: const <String, Object?>{
          'visibleTextPreviews': <String>['Release readiness audit'],
          'visibleSemanticIds': <String>['detail-title'],
          'interactiveLabels': <String>['Back'],
          'visualSignals': <String>[
            'Text|Release readiness audit|20.0,88.0,220.0x28.0|#FFFEF3C7|20.0|w600',
          ],
        },
        artifacts: const <String, Object?>{
          'screenshotPath': '/tmp/after.png',
          'screenshotDigest': 'fnv1a64:after',
        },
      );

      final result =
          await const CockpitCompareDevelopmentProbeService().compare(
        CockpitCompareDevelopmentProbeRequest(
          fromProbe: fromProbe,
          toProbe: toProbe,
        ),
      );

      expect(result.delta.routeChanged, isFalse);
      expect(result.delta.visualChanged, isTrue);
      expect(result.delta.screenshotChanged, isTrue);
      expect(
        result.delta.addedVisualSignals,
        orderedEquals(const <String>[
          'Text|Release readiness audit|20.0,88.0,220.0x28.0|#FFFEF3C7|20.0|w600',
        ]),
      );
      expect(
        result.delta.removedVisualSignals,
        orderedEquals(const <String>[
          'Text|Release readiness audit|24.0,88.0,220.0x28.0|#FFFEF3C7|24.0|w700',
        ]),
      );
      expect(result.delta.changeSummary, contains('visual'));
    },
  );
}

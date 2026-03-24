import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('registers visible targets with metadata and supported commands', () {
    final registry = CockpitTargetRegistry(routeName: '/checkout');

    registry.register(
      const CockpitTarget(
        registrationId: 'submit-1',
        cockpitId: 'submit_button',
        semanticId: 'checkout_submit',
        text: 'Submit order',
        routeName: '/checkout',
        supportedCommands: {
          CockpitCommandType.tap,
          CockpitCommandType.assertVisible,
        },
      ),
    );

    expect(registry.visibleTargets, hasLength(1));
    expect(registry.visibleTargets.single.cockpitId, 'submit_button');
    expect(
      registry.visibleTargets.single.supportedCommands,
      containsAll(<CockpitCommandType>[
        CockpitCommandType.tap,
        CockpitCommandType.assertVisible,
      ]),
    );
  });

  test('resolves targets by locator priority and fallback order', () {
    final registry = CockpitTargetRegistry(routeName: '/checkout');

    registry.register(
      const CockpitTarget(
        registrationId: 'semantic-match',
        semanticId: 'checkout_submit',
        text: 'Submit order',
        routeName: '/checkout',
        supportedCommands: {CockpitCommandType.tap},
      ),
    );
    registry.register(
      const CockpitTarget(
        registrationId: 'text-match',
        text: 'Submit order',
        routeName: '/checkout',
        supportedCommands: {CockpitCommandType.tap},
      ),
    );

    final resolution = registry.resolve(
      const CockpitLocator(
        kind: CockpitLocatorKind.cockpitId,
        value: 'missing_button',
        fallbacks: [
          CockpitLocator(
            kind: CockpitLocatorKind.semanticId,
            value: 'checkout_submit',
          ),
          CockpitLocator(kind: CockpitLocatorKind.text, value: 'Submit order'),
        ],
      ),
    );

    expect(resolution.isSuccess, isTrue);
    expect(resolution.target?.registrationId, 'semantic-match');
    expect(
      resolution.locatorResolution,
      const CockpitLocatorResolution(
        matchedKind: CockpitLocatorKind.semanticId,
        matchedValue: 'checkout_submit',
      ),
    );
  });

  test(
    'reports ambiguity when a fallback locator matches multiple targets',
    () {
      final registry = CockpitTargetRegistry(routeName: '/checkout');

      registry.register(
        const CockpitTarget(
          registrationId: 'primary',
          text: 'Continue',
          routeName: '/checkout',
          supportedCommands: {CockpitCommandType.tap},
        ),
      );
      registry.register(
        const CockpitTarget(
          registrationId: 'secondary',
          text: 'Continue',
          routeName: '/checkout',
          supportedCommands: {CockpitCommandType.tap},
        ),
      );

      final resolution = registry.resolve(
        const CockpitLocator(
          kind: CockpitLocatorKind.cockpitId,
          value: 'missing_button',
          fallbacks: [
            CockpitLocator(kind: CockpitLocatorKind.text, value: 'Continue'),
          ],
        ),
      );

      expect(resolution.isSuccess, isFalse);
      expect(resolution.error?.code, CockpitCommandError.ambiguousTargetCode);
      expect(
        resolution.matches.map((target) => target.registrationId),
        containsAll(<String>['primary', 'secondary']),
      );
    },
  );

  test('resolves targets by native widget key', () {
    final registry = CockpitTargetRegistry(routeName: '/inbox');

    registry.register(
      const CockpitTarget(
        registrationId: 'task-row-42',
        keyValue: 'task-item:42',
        text: 'Review docs',
        routeName: '/inbox',
        supportedCommands: {CockpitCommandType.tap},
      ),
    );

    final resolution = registry.resolve(
      const CockpitLocator(kind: CockpitLocatorKind.key, value: 'task-item:42'),
    );

    expect(resolution.isSuccess, isTrue);
    expect(resolution.target?.registrationId, 'task-row-42');
    expect(
      resolution.locatorResolution,
      const CockpitLocatorResolution(
        matchedKind: CockpitLocatorKind.key,
        matchedValue: 'task-item:42',
      ),
    );
  });

  test('caps live snapshots and prioritizes actionable keyed targets', () {
    final registry = CockpitTargetRegistry(routeName: '/inbox');

    for (var index = 0;
        index < CockpitTargetRegistry.liveSnapshotTargetLimit + 32;
        index += 1) {
      registry.register(
        CockpitTarget(
          registrationId: 'target-$index',
          keyValue: index < 4 ? 'key-$index' : null,
          text: 'Target $index',
          routeName: '/inbox',
          supportedCommands: index < 4
              ? const {CockpitCommandType.tap}
              : const <CockpitCommandType>{},
        ),
      );
    }

    final snapshot = registry.snapshot();

    expect(
      snapshot.visibleTargets,
      hasLength(CockpitTargetRegistry.liveSnapshotTargetLimit),
    );
    expect(snapshot.truncated, isTrue);
    expect(snapshot.summary?.visibleTargetCount, greaterThan(120));
    expect(
      snapshot.visibleTargets.take(4).map((target) => target.keyValue),
      <String?>['key-0', 'key-1', 'key-2', 'key-3'],
    );
  });

  test('prefers a unique actionable keyed match over passive duplicates', () {
    final registry = CockpitTargetRegistry(routeName: '/inbox');

    registry.register(
      const CockpitTarget(
        registrationId: 'open-action',
        semanticId: 'Open task Gesture alpha',
        keyValue: 'task-open-123',
        text: 'Gesture alpha',
        routeName: '/inbox',
        supportedCommands: {CockpitCommandType.tap},
      ),
    );
    registry.register(
      const CockpitTarget(
        registrationId: 'open-passive-text',
        semanticId: 'Open task Gesture alpha',
        text: 'Gesture alpha',
        routeName: '/inbox',
      ),
    );

    final resolution = registry.resolve(
      const CockpitLocator(
        kind: CockpitLocatorKind.semanticId,
        value: 'Open task Gesture alpha',
      ),
    );

    expect(resolution.isSuccess, isTrue);
    expect(resolution.target?.registrationId, 'open-action');
  });
}

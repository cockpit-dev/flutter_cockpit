import 'package:flutter/material.dart';
import 'package:flutter_cockpit/flutter_cockpit_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('rebuild diagnostics are disabled by default', (tester) async {
    final surfaceKey = GlobalKey<CockpitSurfaceState>();

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: CockpitSurface(
          key: surfaceKey,
          routeName: '/diagnostics',
          child: const _CounterHarness(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final live = surfaceKey.currentState!.snapshot();
    final investigate = surfaceKey.currentState!.snapshot(
      options: const CockpitSnapshotOptions.investigate(),
    );

    expect(live.rebuild, isNull);
    expect(investigate.rebuild, isNull);
  });

  testWidgets('rebuild diagnostics are included only in rich snapshots', (
    tester,
  ) async {
    final surfaceKey = GlobalKey<CockpitSurfaceState>();
    final tracker = CockpitRebuildTracker(
      routeNameProvider: () => '/diagnostics',
    );
    addTearDown(tracker.dispose);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: CockpitSurface(
          key: surfaceKey,
          routeName: '/diagnostics',
          rebuildTracker: tracker,
          child: const _CounterHarness(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Increment'));
    await tester.pump();
    await tester.tap(find.text('Increment'));
    await tester.pump();

    final live = surfaceKey.currentState!.snapshot();
    final investigate = surfaceKey.currentState!.snapshot(
      options: const CockpitSnapshotOptions.investigate(),
    );

    expect(live.rebuild, isNull);
    expect(investigate.rebuild, isNotNull);
    expect(investigate.rebuild!.totalRebuildCount, greaterThan(0));
    expect(investigate.rebuild!.entries, isNotEmpty);
    expect(investigate.summary?.rebuildSummaryIncluded, isTrue);
  });

  testWidgets('rebuild diagnostics stay bounded by snapshot options', (
    tester,
  ) async {
    final surfaceKey = GlobalKey<CockpitSurfaceState>();
    final tracker = CockpitRebuildTracker(
      routeNameProvider: () => '/diagnostics',
    );
    addTearDown(tracker.dispose);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: CockpitSurface(
          key: surfaceKey,
          routeName: '/diagnostics',
          rebuildTracker: tracker,
          child: const _CounterHarness(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (var index = 0; index < 4; index += 1) {
      await tester.tap(find.text('Increment'));
      await tester.pump();
    }

    final snapshot = surfaceKey.currentState!.snapshot(
      options: const CockpitSnapshotOptions(
        profile: CockpitSnapshotProfile.investigate,
        includeRebuildActivity: true,
        maxRebuildEntries: 1,
      ),
    );

    expect(snapshot.rebuild, isNotNull);
    expect(snapshot.rebuild!.entries.length, lessThanOrEqualTo(1));
    expect(snapshot.rebuild!.truncated, isTrue);
  });
}

final class _CounterHarness extends StatefulWidget {
  const _CounterHarness();

  @override
  State<_CounterHarness> createState() => _CounterHarnessState();
}

final class _CounterHarnessState extends State<_CounterHarness> {
  int _count = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text('Count $_count'),
        TextButton(
          onPressed: () {
            setState(() {
              _count += 1;
            });
          },
          child: const Text('Increment'),
        ),
      ],
    );
  }
}

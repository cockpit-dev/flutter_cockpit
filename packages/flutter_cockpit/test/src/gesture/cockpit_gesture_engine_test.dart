import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_cockpit/flutter_cockpit_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('tap clamps edge-aligned targets back into the viewport', (
    tester,
  ) async {
    var tapCount = 0;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Material(
          child: SizedBox(
            width: 320,
            height: 240,
            child: Stack(
              children: <Widget>[
                Positioned(
                  left: 24,
                  bottom: -1,
                  child: GestureDetector(
                    key: const ValueKey<String>('edge-tap-target'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => tapCount += 1,
                    child: const SizedBox(width: 132, height: 48),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final target = _targetFor(tester, 'edge-tap-target');
    final engine = CockpitGestureEngine(delay: tester.pump);

    await engine.perform(CockpitGestureAction.tap(target: target));
    await tester.pumpAndSettle();

    expect(tapCount, 1);
  });

  testWidgets('longPress dispatches a real long-press gesture', (tester) async {
    var longPressCount = 0;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: GestureDetector(
            key: const ValueKey<String>('long-press-target'),
            behavior: HitTestBehavior.opaque,
            onLongPress: () => longPressCount += 1,
            child: const SizedBox(width: 140, height: 140),
          ),
        ),
      ),
    );
    await tester.pump();

    final target = _targetFor(tester, 'long-press-target');
    final engine = CockpitGestureEngine(delay: tester.pump);

    await engine.perform(
      CockpitGestureAction.longPress(
        target: target,
        duration: const Duration(milliseconds: 650),
      ),
    );
    await tester.pumpAndSettle();

    expect(longPressCount, 1);
  });

  testWidgets('doubleTap dispatches a real double-tap gesture', (tester) async {
    var doubleTapCount = 0;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: GestureDetector(
            key: const ValueKey<String>('double-tap-target'),
            behavior: HitTestBehavior.opaque,
            onDoubleTap: () => doubleTapCount += 1,
            child: const SizedBox(width: 140, height: 140),
          ),
        ),
      ),
    );
    await tester.pump();

    final target = _targetFor(tester, 'double-tap-target');
    final engine = CockpitGestureEngine(delay: tester.pump);

    await engine.perform(CockpitGestureAction.doubleTap(target: target));
    await tester.pumpAndSettle();

    expect(doubleTapCount, 1);
  });

  testWidgets('tap can target the top-right anchor of a larger shell', (
    tester,
  ) async {
    var tapCount = 0;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Material(
          child: Center(
            child: SizedBox(
              key: const ValueKey<String>('card-shell'),
              width: 220,
              height: 140,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  const ColoredBox(color: Color(0xFF101414)),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => tapCount += 1,
                      child: const SizedBox(width: 44, height: 44),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final shell = _targetFor(tester, 'card-shell');
    final engine = CockpitGestureEngine(delay: tester.pump);

    await engine.perform(
      CockpitGestureAction.tap(
        target: shell,
        anchor: CockpitGestureAnchor.topRight,
      ),
    );
    await tester.pumpAndSettle();

    expect(tapCount, 1);
  });

  testWidgets('drag dispatches a real pan gesture', (tester) async {
    var totalDx = 0.0;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: GestureDetector(
            key: const ValueKey<String>('drag-target'),
            behavior: HitTestBehavior.opaque,
            onPanUpdate: (details) {
              totalDx += details.delta.dx;
            },
            child: const SizedBox(width: 140, height: 140),
          ),
        ),
      ),
    );
    await tester.pump();

    final target = _targetFor(tester, 'drag-target');
    final engine = CockpitGestureEngine(delay: tester.pump);

    await engine.perform(
      CockpitGestureAction.drag(
        target: target,
        delta: const Offset(96, 0),
        duration: const Duration(milliseconds: 220),
      ),
    );
    await tester.pumpAndSettle();

    expect(totalDx, greaterThan(40));
  });

  testWidgets('gesture profiles adjust drag sampling density', (tester) async {
    final fastDurations = <Duration>[];
    final preciseDurations = <Duration>[];

    Future<void> pumpAndRecord(
      List<Duration> durations, [
      Duration? duration,
    ]) async {
      final resolved = duration ?? Duration.zero;
      durations.add(resolved);
      await tester.pump(resolved);
    }

    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            key: ValueKey<String>('profile-target'),
            width: 160,
            height: 160,
          ),
        ),
      ),
    );
    await tester.pump();

    final target = _targetFor(tester, 'profile-target');
    final fastEngine = CockpitGestureEngine(
      delay: ([duration]) => pumpAndRecord(fastDurations, duration),
    );
    final preciseEngine = CockpitGestureEngine(
      delay: ([duration]) => pumpAndRecord(preciseDurations, duration),
    );

    await fastEngine.perform(
      CockpitGestureAction.drag(
        target: target,
        delta: const Offset(140, 0),
        duration: const Duration(milliseconds: 240),
        profile: CockpitGestureProfile.fast,
      ),
    );
    await preciseEngine.perform(
      CockpitGestureAction.drag(
        target: target,
        delta: const Offset(140, 0),
        duration: const Duration(milliseconds: 240),
        profile: CockpitGestureProfile.precise,
      ),
    );

    final fastMoveTicks =
        fastDurations.where((it) => it > Duration.zero).length;
    final preciseMoveTicks =
        preciseDurations.where((it) => it > Duration.zero).length;

    expect(preciseMoveTicks, greaterThan(fastMoveTicks));
  });

  testWidgets('gesture sampling can be overridden with frameIntervalMs', (
    tester,
  ) async {
    final sampledDurations = <Duration>[];

    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            key: ValueKey<String>('frame-interval-target'),
            width: 160,
            height: 160,
          ),
        ),
      ),
    );
    await tester.pump();

    final target = _targetFor(tester, 'frame-interval-target');
    final engine = CockpitGestureEngine(
      delay: ([duration]) async {
        final resolved = duration ?? Duration.zero;
        sampledDurations.add(resolved);
        await tester.pump(resolved);
      },
    );

    await engine.perform(
      CockpitGestureAction.drag(
        target: target,
        delta: const Offset(120, 0),
        duration: const Duration(milliseconds: 200),
        frameInterval: const Duration(milliseconds: 25),
      ),
    );

    final moveTicks = sampledDurations.where((it) => it > Duration.zero).length;
    expect(moveTicks, inInclusiveRange(7, 9));
  });

  testWidgets('drag can honor a long-press hold before movement', (
    tester,
  ) async {
    var longPressMoveCount = 0;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: GestureDetector(
            key: const ValueKey<String>('held-drag-target'),
            behavior: HitTestBehavior.opaque,
            onLongPressMoveUpdate: (_) {
              longPressMoveCount += 1;
            },
            child: const SizedBox(width: 160, height: 160),
          ),
        ),
      ),
    );
    await tester.pump();

    final target = _targetFor(tester, 'held-drag-target');
    final engine = CockpitGestureEngine(delay: tester.pump);

    await engine.perform(
      CockpitGestureAction.drag(
        target: target,
        delta: const Offset(120, 0),
        holdDuration: kLongPressTimeout + const Duration(milliseconds: 40),
        duration: const Duration(milliseconds: 220),
      ),
    );
    await tester.pumpAndSettle();

    expect(longPressMoveCount, greaterThan(0));
  });

  testWidgets('swipe can dismiss a production-style card', (tester) async {
    var dismissed = false;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Material(
          child: StatefulBuilder(
            builder: (context, setState) {
              return dismissed
                  ? const SizedBox.shrink()
                  : Dismissible(
                      key: const ValueKey<String>('swipe-target'),
                      onDismissed: (_) {
                        setState(() {
                          dismissed = true;
                        });
                      },
                      child: const SizedBox(width: 220, height: 120),
                    );
            },
          ),
        ),
      ),
    );
    await tester.pump();

    final target = _targetFor(tester, 'swipe-target');
    final engine = CockpitGestureEngine(delay: tester.pump);

    await engine.perform(
      CockpitGestureAction.swipe(
        target: target,
        direction: AxisDirection.right,
      ),
    );
    await tester.pumpAndSettle();

    expect(dismissed, isTrue);
  });

  testWidgets('fling dispatches a momentum-style drag gesture', (tester) async {
    var dragEndCount = 0;
    Velocity? latestVelocity;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: GestureDetector(
            key: const ValueKey<String>('fling-target'),
            behavior: HitTestBehavior.opaque,
            onPanEnd: (details) {
              dragEndCount += 1;
              latestVelocity = details.velocity;
            },
            child: const SizedBox(width: 180, height: 180),
          ),
        ),
      ),
    );
    await tester.pump();

    final target = _targetFor(tester, 'fling-target');
    final engine = CockpitGestureEngine(delay: tester.pump);

    await engine.perform(
      CockpitGestureAction.fling(
        target: target,
        delta: const Offset(0, -220),
        duration: const Duration(milliseconds: 88),
      ),
    );
    await tester.pumpAndSettle();

    expect(dragEndCount, 1);
    expect(latestVelocity, isNotNull);
  });

  testWidgets('pinchZoom dispatches a scale gesture', (tester) async {
    var latestScale = 1.0;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: GestureDetector(
            key: const ValueKey<String>('pinch-target'),
            behavior: HitTestBehavior.opaque,
            onScaleUpdate: (details) {
              latestScale = details.scale;
            },
            child: const SizedBox(width: 220, height: 220),
          ),
        ),
      ),
    );
    await tester.pump();

    final target = _targetFor(tester, 'pinch-target');
    final engine = CockpitGestureEngine(delay: tester.pump);

    await engine.perform(
      CockpitGestureAction.pinchZoom(target: target, scale: 1.8, startSpan: 56),
    );
    await tester.pumpAndSettle();

    expect(latestScale, greaterThan(1.2));
  });

  testWidgets('rotate dispatches a rotation-aware scale gesture', (
    tester,
  ) async {
    var latestRotation = 0.0;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: GestureDetector(
            key: const ValueKey<String>('rotate-target'),
            behavior: HitTestBehavior.opaque,
            onScaleUpdate: (details) {
              latestRotation = details.rotation;
            },
            child: const SizedBox(width: 220, height: 220),
          ),
        ),
      ),
    );
    await tester.pump();

    final target = _targetFor(tester, 'rotate-target');
    final engine = CockpitGestureEngine(delay: tester.pump);

    await engine.perform(
      CockpitGestureAction.rotate(
        target: target,
        rotation: 0.42,
        startSpan: 72,
      ),
    );
    await tester.pumpAndSettle();

    expect(latestRotation.abs(), greaterThan(0.12));
  });

  testWidgets('panZoom dispatches trackpad pan-zoom events', (tester) async {
    var updateCount = 0;
    double latestScale = 1.0;
    double latestRotation = 0.0;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerPanZoomUpdate: (event) {
              updateCount += 1;
              latestScale = event.scale;
              latestRotation = event.rotation;
            },
            child: const SizedBox(
              key: ValueKey<String>('panzoom-target'),
              width: 220,
              height: 220,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final target = _targetFor(tester, 'panzoom-target');
    final engine = CockpitGestureEngine(delay: tester.pump);

    await engine.perform(
      CockpitGestureAction.panZoom(
        target: target,
        delta: const Offset(18, -26),
        scale: 1.18,
        rotation: 0.24,
      ),
    );
    await tester.pumpAndSettle();

    expect(updateCount, greaterThan(0));
    expect(latestScale, greaterThan(1.0));
    expect(latestRotation, greaterThan(0.0));
  });

  testWidgets('multiTouch dispatches explicit pointer tracks', (tester) async {
    var latestScale = 1.0;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: GestureDetector(
            key: const ValueKey<String>('multitouch-target'),
            behavior: HitTestBehavior.opaque,
            onScaleUpdate: (details) {
              latestScale = details.scale;
            },
            child: const SizedBox(width: 220, height: 220),
          ),
        ),
      ),
    );
    await tester.pump();

    final target = _targetFor(tester, 'multitouch-target');
    final engine = CockpitGestureEngine(delay: tester.pump);

    await engine.perform(
      CockpitGestureAction.multiTouch(
        target: target,
        sequence: const CockpitMultiTouchSequence(
          steps: <CockpitMultiTouchStep>[
            CockpitMultiTouchStep(
              pointer: 1,
              phase: CockpitMultiTouchPhase.down,
              atMs: 0,
              dx: -24,
              dy: 0,
            ),
            CockpitMultiTouchStep(
              pointer: 2,
              phase: CockpitMultiTouchPhase.down,
              atMs: 0,
              dx: 24,
              dy: 0,
            ),
            CockpitMultiTouchStep(
              pointer: 1,
              phase: CockpitMultiTouchPhase.move,
              atMs: 120,
              dx: -72,
              dy: 0,
            ),
            CockpitMultiTouchStep(
              pointer: 2,
              phase: CockpitMultiTouchPhase.move,
              atMs: 120,
              dx: 72,
              dy: 0,
            ),
            CockpitMultiTouchStep(
              pointer: 1,
              phase: CockpitMultiTouchPhase.up,
              atMs: 220,
              dx: -72,
              dy: 0,
            ),
            CockpitMultiTouchStep(
              pointer: 2,
              phase: CockpitMultiTouchPhase.up,
              atMs: 220,
              dx: 72,
              dy: 0,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(latestScale, greaterThan(1.4));
  });
}

CockpitTarget _targetFor(WidgetTester tester, String keyValue) {
  final finder = find.byKey(ValueKey<String>(keyValue));
  final element = tester.element(finder);

  return CockpitTarget(
    registrationId: keyValue,
    keyValue: keyValue,
    routeName: '/',
    diagnosticNodeProvider: () => element,
  );
}

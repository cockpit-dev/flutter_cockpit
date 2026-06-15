import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cockpit_demo/src/ui/screens/command_lab_screen.dart';

Future<void> _pumpLab(WidgetTester tester) async {
  await tester.pumpWidget(const MaterialApp(home: CommandLabScreen()));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('gesture pad records tap, double tap, and long press', (
    tester,
  ) async {
    await _pumpLab(tester);

    await tester.tap(find.byKey(const Key('lab-gesture-detector')));
    // Double-tap disambiguation delays the single-tap callback.
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('gesture:tap'), findsOneWidget);

    await tester.tap(find.byKey(const Key('lab-gesture-detector')));
    await tester.pump(kDoubleTapMinTime);
    await tester.tap(find.byKey(const Key('lab-gesture-detector')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('gesture:doubleTap'), findsOneWidget);

    await tester.longPress(find.byKey(const Key('lab-gesture-detector')));
    await tester.pump();
    expect(find.text('gesture:longPress'), findsOneWidget);
  });

  testWidgets('pan pad distinguishes drag from fling with direction', (
    tester,
  ) async {
    await _pumpLab(tester);

    await tester.timedDrag(
      find.byKey(const Key('lab-pan-detector')),
      const Offset(80, 0),
      const Duration(milliseconds: 300),
    );
    await tester.pump();
    expect(find.text('pan:drag-right'), findsOneWidget);

    await tester.fling(
      find.byKey(const Key('lab-pan-detector')),
      const Offset(-90, 0),
      2400,
    );
    await tester.pump();
    expect(find.text('pan:fling-left'), findsOneWidget);
  });

  testWidgets('swipe pad records vertical direction', (tester) async {
    await _pumpLab(tester);

    await tester.timedDrag(
      find.byKey(const Key('lab-swipe-detector')),
      const Offset(0, -60),
      const Duration(milliseconds: 200),
    );
    await tester.pump();
    expect(find.text('swipe:up'), findsOneWidget);
  });

  testWidgets('transform pad records pinch scale through two pointers', (
    tester,
  ) async {
    await _pumpLab(tester);

    await tester.ensureVisible(find.byKey(const Key('lab-transform-detector')));
    await tester.pumpAndSettle();
    final center = tester.getCenter(
      find.byKey(const Key('lab-transform-detector')),
    );
    final first = await tester.startGesture(center - const Offset(24, 0));
    final second = await tester.startGesture(center + const Offset(24, 0));
    for (var step = 1; step <= 8; step += 1) {
      await first.moveBy(const Offset(-8, 0));
      await second.moveBy(const Offset(8, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await first.up();
    await second.up();
    await tester.pumpAndSettle();
    expect(find.text('transform:scale-up'), findsOneWidget);

    await tester.tap(find.byKey(const Key('lab-transform-reset')));
    await tester.pump();
    expect(find.text('transform:idle'), findsOneWidget);
  });

  testWidgets('multi-touch pad records concurrent pointer count', (
    tester,
  ) async {
    await _pumpLab(tester);

    await tester.ensureVisible(
      find.byKey(const Key('lab-multitouch-listener')),
    );
    await tester.pumpAndSettle();
    final center = tester.getCenter(
      find.byKey(const Key('lab-multitouch-listener')),
    );
    final first = await tester.startGesture(center - const Offset(20, 0));
    final second = await tester.startGesture(center + const Offset(20, 0));
    for (var step = 1; step <= 4; step += 1) {
      await first.moveBy(const Offset(-6, 0));
      await second.moveBy(const Offset(6, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await first.up();
    await second.up();
    await tester.pumpAndSettle();
    expect(find.text('touch:2-pointers'), findsOneWidget);
  });

  testWidgets('slider responds to semantic increase and decrease', (
    tester,
  ) async {
    await _pumpLab(tester);
    final semantics = tester.ensureSemantics();

    await tester.ensureVisible(find.byKey(const Key('lab-slider-semantics')));
    await tester.pumpAndSettle();
    expect(find.text('slider:50'), findsOneWidget);
    final node = tester.getSemantics(
      find.byKey(const Key('lab-slider-semantics')),
    );
    node.owner!.performAction(node.id, SemanticsAction.increase);
    await tester.pumpAndSettle();
    expect(find.text('slider:60'), findsOneWidget);

    node.owner!.performAction(node.id, SemanticsAction.decrease);
    await tester.pumpAndSettle();
    expect(find.text('slider:50'), findsOneWidget);

    semantics.dispose();
  });

  testWidgets('dismiss card hides through the semantics dismiss action', (
    tester,
  ) async {
    await _pumpLab(tester);
    final semantics = tester.ensureSemantics();

    await tester.ensureVisible(find.byKey(const Key('lab-dismiss-card')));
    await tester.pumpAndSettle();
    expect(find.text('dismiss:visible'), findsOneWidget);
    final node = tester.getSemantics(find.byKey(const Key('lab-dismiss-card')));
    node.owner!.performAction(node.id, SemanticsAction.dismiss);
    await tester.pumpAndSettle();
    expect(find.text('dismiss:done'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('lab-dismiss-reset')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('lab-dismiss-reset')));
    await tester.pump();
    expect(find.text('dismiss:visible'), findsOneWidget);

    semantics.dispose();
  });

  testWidgets('text field mirrors text, focus, and submit state', (
    tester,
  ) async {
    await _pumpLab(tester);

    await tester.ensureVisible(find.byKey(const Key('lab-text-field')));
    await tester.pumpAndSettle();
    expect(find.text('focus:no'), findsOneWidget);

    await tester.tap(find.byKey(const Key('lab-text-field')));
    await tester.pumpAndSettle();
    expect(find.text('focus:yes'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('lab-text-field')), 'lab text');
    await tester.pump();
    expect(find.text('text:lab text'), findsOneWidget);

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('submitted:lab text'), findsOneWidget);
  });

  testWidgets('key pad records key down and up after tap focus', (
    tester,
  ) async {
    await _pumpLab(tester);

    await tester.ensureVisible(find.byKey(const Key('lab-key-pad')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('lab-key-pad-activator')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('key:focused'), findsOneWidget);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(find.text('key:ArrowRight-down'), findsOneWidget);

    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(find.text('key:ArrowRight-up'), findsOneWidget);
  });

  testWidgets('deep target sits below the fold and can be revealed', (
    tester,
  ) async {
    await _pumpLab(tester);

    final deepFinder = find.byKey(const Key('lab-deep-item'));
    expect(deepFinder, findsOneWidget);
    expect(
      tester.getRect(deepFinder).top,
      greaterThan(tester.getSize(find.byType(Scaffold)).height),
      reason: 'Deep target must start off-viewport so showOnScreen has work.',
    );

    await tester.ensureVisible(deepFinder);
    await tester.pumpAndSettle();
    expect(find.text('Deep lab target reached'), findsOneWidget);
  });
}

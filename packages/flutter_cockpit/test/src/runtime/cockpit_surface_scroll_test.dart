import 'package:flutter/material.dart';
import 'package:flutter_cockpit/flutter_cockpit_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'ensureLocatorVisible can center an element within the viewport',
    (tester) async {
      await tester.pumpWidget(
        WidgetsApp(
          color: const Color(0xFFFFFFFF),
          builder: (context, child) {
            return Center(
              child: SizedBox(
                width: 320,
                height: 320,
                child: CockpitSurface(
                  routeName: '/center-reveal',
                  child: Material(
                    child: Directionality(
                      textDirection: TextDirection.ltr,
                      child: SingleChildScrollView(
                        key: const ValueKey<String>('center-scrollable'),
                        child: Column(
                          children: List<Widget>.generate(30, (index) {
                            return SizedBox(
                              key: ValueKey<String>('center-task-$index'),
                              height: 88,
                              child: ListTile(title: Text('Task $index')),
                            );
                          }),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      final surfaceState = tester.state<CockpitSurfaceState>(
        find.byType(CockpitSurface),
      );

      final didReveal = await surfaceState.ensureLocatorVisible(
        const CockpitLocator(
          kind: CockpitLocatorKind.text,
          value: 'Task 18',
        ),
        alignment: CockpitRevealAlignment.center,
      );
      await tester.pumpAndSettle();

      final viewportRect = tester.getRect(
        find.byKey(const ValueKey<String>('center-scrollable')),
      );
      final targetRect = tester.getRect(find.text('Task 18'));

      expect(didReveal, isTrue);
      expect(
        targetRect.center.dy,
        closeTo(viewportRect.center.dy, 40),
      );
    },
  );

  testWidgets(
    'ensureLocatorVisible can keep an end padding from the viewport edge',
    (tester) async {
      await tester.pumpWidget(
        WidgetsApp(
          color: const Color(0xFFFFFFFF),
          builder: (context, child) {
            return Center(
              child: SizedBox(
                width: 320,
                height: 320,
                child: CockpitSurface(
                  routeName: '/end-reveal',
                  child: Material(
                    child: Directionality(
                      textDirection: TextDirection.ltr,
                      child: SingleChildScrollView(
                        key: const ValueKey<String>('end-scrollable'),
                        child: Column(
                          children: List<Widget>.generate(30, (index) {
                            return SizedBox(
                              key: ValueKey<String>('end-task-$index'),
                              height: 88,
                              child: ListTile(title: Text('Task $index')),
                            );
                          }),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      final surfaceState = tester.state<CockpitSurfaceState>(
        find.byType(CockpitSurface),
      );

      final didReveal = await surfaceState.ensureLocatorVisible(
        const CockpitLocator(
          kind: CockpitLocatorKind.text,
          value: 'Task 18',
        ),
        alignment: CockpitRevealAlignment.end,
        padding: 32,
      );
      await tester.pumpAndSettle();

      final viewportRect = tester.getRect(
        find.byKey(const ValueKey<String>('end-scrollable')),
      );
      final targetRect = tester.getRect(find.text('Task 18'));

      expect(didReveal, isTrue);
      expect(
        targetRect.bottom,
        lessThanOrEqualTo(viewportRect.bottom - 24),
      );
      expect(
        targetRect.bottom,
        greaterThan(viewportRect.bottom - 88),
      );
    },
  );

  testWidgets(
    'scrollByViewport returns false when user-like scrolling cannot move the scrollable',
    (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        WidgetsApp(
          color: const Color(0xFFFFFFFF),
          builder: (context, child) {
            return CockpitSurface(
              routeName: '/locked-list',
              child: Material(
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: ListView.builder(
                    key: const ValueKey<String>('locked-scrollable'),
                    controller: controller,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: 40,
                    itemBuilder: (context, index) {
                      return SizedBox(
                        height: 96,
                        child: ListTile(title: Text('Task $index')),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      final surfaceState = tester.state<CockpitSurfaceState>(
        find.byType(CockpitSurface),
      );

      final didScroll = await surfaceState.scrollByViewport(
        viewportFraction: 0.9,
        scrollableKey: 'locked-scrollable',
      );

      expect(didScroll, isFalse);
      expect(controller.offset, 0);
    },
  );
}

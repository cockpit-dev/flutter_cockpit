import 'package:flutter/widgets.dart';
import 'package:flutter_cockpit/flutter_cockpit_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('resolves geometry from a rendered target element', (
    tester,
  ) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            key: ValueKey<String>('geometry-target'),
            width: 180,
            height: 96,
          ),
        ),
      ),
    );
    await tester.pump();

    final element = tester.element(
      find.byKey(const ValueKey<String>('geometry-target')),
    );
    final geometry = CockpitTargetGeometryResolver.maybeFromElement(element);

    expect(geometry, isNotNull);
    expect(geometry!.width, 180);
    expect(geometry.height, 96);
    expect(geometry.centerX, greaterThan(0));
    expect(geometry.centerY, greaterThan(0));
    expect(geometry.viewportWidth, greaterThan(0));
    expect(geometry.viewportHeight, greaterThan(0));
  });

  testWidgets('resolves geometry from a target diagnostic node provider', (
    tester,
  ) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            key: ValueKey<String>('geometry-provider-target'),
            width: 120,
            height: 120,
          ),
        ),
      ),
    );
    await tester.pump();

    final element = tester.element(
      find.byKey(const ValueKey<String>('geometry-provider-target')),
    );
    final target = CockpitTarget(
      registrationId: 'geometry-provider-target',
      keyValue: 'geometry-provider-target',
      routeName: '/',
      diagnosticNodeProvider: () => element,
    );

    final geometry = CockpitTargetGeometryResolver.maybeFromTarget(target);
    expect(geometry, isNotNull);
    expect(geometry!.width, 120);
  });

  test('contains returns true only when the point is inside bounds', () {
    const geometry = CockpitTargetGeometry(
      left: 24,
      top: 48,
      width: 180,
      height: 96,
      viewportLeft: 0,
      viewportTop: 0,
      viewportWidth: 400,
      viewportHeight: 800,
      viewId: 1,
    );

    expect(geometry.containsPoint(dx: 40, dy: 72), isTrue);
    expect(geometry.containsPoint(dx: 204, dy: 144), isTrue);
    expect(geometry.containsPoint(dx: 23.9, dy: 72), isFalse);
    expect(geometry.containsPoint(dx: 40, dy: 144.1), isFalse);
  });
}

import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CockpitMultiTouchSequence preserves steps through json', () {
    const sequence = CockpitMultiTouchSequence(
      steps: <CockpitMultiTouchStep>[
        CockpitMultiTouchStep(
          pointer: 1,
          phase: CockpitMultiTouchPhase.down,
          atMs: 0,
          dx: -18,
          dy: 0,
        ),
        CockpitMultiTouchStep(
          pointer: 2,
          phase: CockpitMultiTouchPhase.move,
          atMs: 140,
          dx: 24,
          dy: 12,
        ),
      ],
    );

    expect(CockpitMultiTouchSequence.fromJson(sequence.toJson()), sequence);
  });

  test(
    'CockpitTargetGeometry preserves transport-safe fields through json',
    () {
      const geometry = CockpitTargetGeometry(
        left: 48,
        top: 72,
        width: 160,
        height: 88,
        viewportLeft: 0,
        viewportTop: 0,
        viewportWidth: 430,
        viewportHeight: 932,
        viewId: 1,
      );

      expect(CockpitTargetGeometry.fromJson(geometry.toJson()), geometry);
    },
  );

  test('CockpitTargetGeometry clamps interaction points into the viewport', () {
    const geometry = CockpitTargetGeometry(
      left: 20,
      top: 928.5,
      width: 132,
      height: 48,
      viewportLeft: 0,
      viewportTop: 0,
      viewportWidth: 427,
      viewportHeight: 952,
      viewId: 1,
    );

    final clampedX = geometry.clampXToViewport(geometry.centerX);
    final clampedY = geometry.clampYToViewport(geometry.centerY);

    expect(geometry.centerY, greaterThan(geometry.viewportBottom));
    expect(clampedX, geometry.centerX);
    expect(clampedY, lessThanOrEqualTo(geometry.viewportBottom - 1));
    expect(clampedY, greaterThanOrEqualTo(geometry.viewportTop + 1));
  });
}

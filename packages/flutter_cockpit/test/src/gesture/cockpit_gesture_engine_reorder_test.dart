import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_cockpit/flutter_cockpit_flutter.dart';

void main() {
  testWidgets(
    'drag can reorder a vertical list through an explicit drag handle',
    (tester) async {
      final orderedLabels = <String>['First', 'Second', 'Third'];
      int? reorderStartIndex;
      int? reorderEndIndex;

      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: Center(
              child: SizedBox(
                width: 260,
                height: 420,
                child: ReorderableListView.builder(
                  buildDefaultDragHandles: false,
                  onReorderStart: (index) {
                    reorderStartIndex = index;
                  },
                  onReorderEnd: (index) {
                    reorderEndIndex = index;
                  },
                  itemCount: orderedLabels.length,
                  onReorderItem: (oldIndex, newIndex) {
                    final item = orderedLabels.removeAt(oldIndex);
                    orderedLabels.insert(newIndex, item);
                  },
                  itemBuilder: (context, index) {
                    final label = orderedLabels[index];
                    return Padding(
                      key: ValueKey<String>('card-$label'),
                      padding: const EdgeInsets.only(bottom: 12),
                      child: SizedBox(
                        height: 110,
                        child: Card(
                          child: Row(
                            children: <Widget>[
                              Expanded(child: Center(child: Text(label))),
                              ReorderableDragStartListener(
                                index: index,
                                child: const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: Icon(Icons.drag_indicator_rounded),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final handle = find.descendant(
        of: find.byKey(const ValueKey<String>('card-Third')),
        matching: find.byIcon(Icons.drag_indicator_rounded),
      );
      final geometry = CockpitTargetGeometryResolver.maybeFromElement(
        tester.element(handle),
      );
      expect(geometry, isNotNull);

      final engine = CockpitGestureEngine(delay: tester.pump);
      await engine.perform(
        CockpitGestureAction.drag(
          geometry: geometry!,
          delta: const Offset(0, -260),
          duration: const Duration(milliseconds: 240),
        ),
      );
      await tester.pumpAndSettle();

      expect(reorderStartIndex, 2);
      expect(reorderEndIndex, isNotNull);
      expect(orderedLabels, <String>['Third', 'First', 'Second']);
    },
  );

  testWidgets('drag hold duration can drive long-press move updates', (
    tester,
  ) async {
    double dragDistance = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: Center(
            child: GestureDetector(
              onLongPressMoveUpdate: (details) {
                dragDistance = details.offsetFromOrigin.dx;
              },
              child: Container(
                key: const ValueKey<String>('long-press-zone'),
                width: 200,
                height: 200,
                color: Colors.teal,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final geometry = CockpitTargetGeometryResolver.maybeFromElement(
      tester.element(find.byKey(const ValueKey<String>('long-press-zone'))),
    );
    expect(geometry, isNotNull);

    final engine = CockpitGestureEngine(delay: tester.pump);
    await engine.perform(
      CockpitGestureAction.drag(
        geometry: geometry!,
        delta: const Offset(96, 0),
        duration: const Duration(milliseconds: 220),
        holdDuration: const Duration(milliseconds: 650),
      ),
    );
    await tester.pumpAndSettle();

    expect(dragDistance, greaterThan(40));
  });
}

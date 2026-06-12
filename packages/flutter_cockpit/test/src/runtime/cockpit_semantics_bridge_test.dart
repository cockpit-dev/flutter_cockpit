import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_cockpit/src/runtime/cockpit_semantics_bridge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'resolves the matching semantics node through the SemanticsOwner tree',
    (tester) async {
      var confirmCount = 0;
      var cancelCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  ElevatedButton(
                    key: const ValueKey<String>('cancel-button'),
                    onPressed: () => cancelCount += 1,
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 24),
                  ElevatedButton(
                    key: const ValueKey<String>('confirm-button'),
                    onPressed: () => confirmCount += 1,
                    child: const Text('Confirm'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final element = tester.element(
        find.byKey(const ValueKey<String>('confirm-button')),
      );
      final node = cockpitResolveSemanticsNodeFromOwnerTree(element);

      expect(node, isNotNull);
      final data = node!.getSemanticsData();
      expect(data.hasAction(SemanticsAction.tap), isTrue);
      expect(data.label, contains('Confirm'));

      node.owner!.performAction(node.id, SemanticsAction.tap);
      await tester.pump();

      expect(confirmCount, 1);
      expect(cancelCount, 0);
    },
  );

  testWidgets(
    'returns null when the semantics tree is unavailable',
    semanticsEnabled: false,
    (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox.expand(),
        ),
      );
      await tester.pump();

      final element = tester.element(find.byType(SizedBox));

      expect(cockpitResolveSemanticsNodeFromOwnerTree(element), isNull);
    },
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_cockpit/flutter_cockpit_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'FlutterCockpitHost provisions an internal session controller by default',
    (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: FlutterCockpitHost(
            configuration: FlutterCockpitConfiguration(
              initialRouteName: '/inbox',
            ),
            child: SizedBox.shrink(),
          ),
        ),
      );
      await tester.pump();

      FlutterCockpit.recordStep(
        actionType: 'bootstrap',
        actionArgs: const <String, Object?>{'route': '/inbox'},
      );

      final bundle = FlutterCockpit.binding.sessionController.finish(
        environment: const CockpitEnvironment(
          platform: 'android',
          flutterVersion: '3.38.9',
          dartVersion: '3.10.8',
        ),
      );

      expect(bundle.steps, hasLength(1));
      expect(bundle.steps.single.actionType, 'bootstrap');
      expect(bundle.manifest.status, CockpitTaskStatus.completed);
    },
  );

  testWidgets(
    'FlutterCockpitHost does not recreate the binding on equivalent rebuilds',
    (tester) async {
      final firstConfiguration = FlutterCockpitConfiguration(
        initialRouteName: '/inbox',
      );

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: FlutterCockpitHost(
            configuration: firstConfiguration,
            child: SizedBox.shrink(),
          ),
        ),
      );
      await tester.pump();

      final originalBinding = FlutterCockpit.binding;
      final secondConfiguration = FlutterCockpitConfiguration(
        initialRouteName: '/inbox',
      );

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: FlutterCockpitHost(
            configuration: secondConfiguration,
            child: SizedBox.shrink(),
          ),
        ),
      );
      await tester.pump();

      expect(identical(FlutterCockpit.binding, originalBinding), isTrue);
      expect(FlutterCockpit.binding.registry.routeName, '/inbox');
    },
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_cockpit/flutter_cockpit_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(FlutterCockpit.dispose);

  test('FlutterCockpit.isInitialized reflects runtime lifecycle', () {
    expect(FlutterCockpit.isInitialized, isFalse);

    FlutterCockpit.ensureInitialized(
      const FlutterCockpitConfig(initialRouteName: '/ready'),
    );

    expect(FlutterCockpit.isInitialized, isTrue);

    FlutterCockpit.dispose();

    expect(FlutterCockpit.isInitialized, isFalse);
  });

  testWidgets(
    'FlutterCockpitApp provisions the runtime and renders through the cockpit root',
    (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: FlutterCockpitApp(
            config: FlutterCockpitConfig(initialRouteName: '/inbox'),
            child: SizedBox.shrink(),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(FlutterCockpitRoot), findsOneWidget);

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
    'FlutterCockpitApp does not recreate the binding on equivalent config rebuilds',
    (tester) async {
      const firstConfig = FlutterCockpitConfig(initialRouteName: '/inbox');

      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: FlutterCockpitApp(
            config: firstConfig,
            child: SizedBox.shrink(),
          ),
        ),
      );
      await tester.pump();

      final originalBinding = FlutterCockpit.binding;

      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: FlutterCockpitApp(
            config: FlutterCockpitConfig(initialRouteName: '/inbox'),
            child: SizedBox.shrink(),
          ),
        ),
      );
      await tester.pump();

      expect(identical(FlutterCockpit.binding, originalBinding), isTrue);
      expect(FlutterCockpit.binding.registry.routeName, '/inbox');
    },
  );

  testWidgets(
    'FlutterCockpit.setCurrentRouteName synchronizes the runtime route',
    (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: FlutterCockpitApp(
            config: FlutterCockpitConfig(initialRouteName: '/'),
            child: SizedBox.shrink(),
          ),
        ),
      );
      await tester.pump();

      FlutterCockpit.setCurrentRouteName(' /settings ');

      expect(FlutterCockpit.binding.currentRouteName.value, '/settings');
      expect(FlutterCockpit.binding.registry.routeName, '/settings');

      FlutterCockpit.setCurrentRouteName('   ');

      expect(FlutterCockpit.binding.currentRouteName.value, '/');
      expect(FlutterCockpit.binding.registry.routeName, '/');
    },
  );

  testWidgets(
    'FlutterCockpit.setCurrentRouteName preserves an explicit root route',
    (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: FlutterCockpitApp(
            config: FlutterCockpitConfig(initialRouteName: '/inbox'),
            child: SizedBox.shrink(),
          ),
        ),
      );
      await tester.pump();

      FlutterCockpit.setCurrentRouteName('/');

      expect(FlutterCockpit.binding.currentRouteName.value, '/');
      expect(FlutterCockpit.binding.registry.routeName, '/');
    },
  );

  testWidgets('FlutterCockpit.navigatorObserver normalizes route names', (
    tester,
  ) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: FlutterCockpitApp(
          config: const FlutterCockpitConfig(initialRouteName: '/'),
          child: MaterialApp(
            navigatorObservers: <NavigatorObserver>[
              FlutterCockpit.navigatorObserver,
            ],
            routes: <String, WidgetBuilder>{
              '/': (_) => _RoutePushButton(routeName: ' /details '),
              ' /details ': (_) => const Text('Details'),
            },
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Open details'));
    await tester.pumpAndSettle();

    expect(FlutterCockpit.binding.currentRouteName.value, '/details');
    expect(FlutterCockpit.binding.registry.routeName, '/details');
  });

  testWidgets(
    'FlutterCockpitApp ignores deferred route updates after the runtime is disposed',
    (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: const FlutterCockpitApp(
            config: FlutterCockpitConfig(initialRouteName: '/inbox'),
            child: _NavigatorProbeApp(),
          ),
        ),
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'FlutterCockpitApp does not dispose the shared runtime by default on unmount',
    (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: FlutterCockpitApp(
            config: FlutterCockpitConfig(initialRouteName: '/inbox'),
            child: SizedBox.shrink(),
          ),
        ),
      );
      await tester.pump();

      final originalBinding = FlutterCockpit.binding;

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      expect(identical(FlutterCockpit.binding, originalBinding), isTrue);

      FlutterCockpit.dispose();
    },
  );

  testWidgets('FlutterCockpitApp can explicitly own and dispose the runtime', (
    tester,
  ) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: FlutterCockpitApp(
          ownsRuntime: true,
          config: FlutterCockpitConfig(initialRouteName: '/owned'),
          child: SizedBox.shrink(),
        ),
      ),
    );
    await tester.pump();

    final originalBinding = FlutterCockpit.binding;

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(identical(FlutterCockpit.binding, originalBinding), isFalse);
  });

  testWidgets(
    'FlutterCockpitApp preserves the binding while applying updated runtime config',
    (tester) async {
      final firstController = CockpitSessionController(
        sessionId: 'first-session',
        taskId: 'first-task',
        platform: 'android',
      );
      final secondController = CockpitSessionController(
        sessionId: 'second-session',
        taskId: 'second-task',
        platform: 'ios',
      );
      final firstRegistry = CockpitTargetRegistry(routeName: '/inbox');
      final secondRegistry = CockpitTargetRegistry(routeName: '/settings');

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: FlutterCockpitApp(
            config: FlutterCockpitConfig.fromRuntimeConfiguration(
              FlutterCockpitConfiguration(
                initialRouteName: '/inbox',
                registry: firstRegistry,
                sessionController: firstController,
                interactionPolicy: CockpitInteractionPolicy(
                  actionVisualDelay: Duration(milliseconds: 120),
                ),
              ),
            ),
            child: SizedBox.shrink(),
          ),
        ),
      );
      await tester.pump();

      final originalBinding = FlutterCockpit.binding;
      expect(
        originalBinding.configuration.interactionPolicy.actionVisualDelay,
        const Duration(milliseconds: 120),
      );

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: FlutterCockpitApp(
            config: FlutterCockpitConfig.fromRuntimeConfiguration(
              FlutterCockpitConfiguration(
                initialRouteName: '/settings',
                registry: secondRegistry,
                sessionController: secondController,
                interactionPolicy: CockpitInteractionPolicy(
                  actionVisualDelay: Duration(milliseconds: 480),
                ),
              ),
            ),
            child: SizedBox.shrink(),
          ),
        ),
      );
      await tester.pump();

      expect(identical(FlutterCockpit.binding, originalBinding), isTrue);
      expect(
        FlutterCockpit
            .binding
            .configuration
            .interactionPolicy
            .actionVisualDelay,
        const Duration(milliseconds: 480),
      );
      expect(
        identical(FlutterCockpit.binding.registry, secondRegistry),
        isTrue,
      );
      expect(
        identical(FlutterCockpit.binding.sessionController, secondController),
        isTrue,
      );
      expect(FlutterCockpit.binding.registry.routeName, '/settings');
    },
  );

  test('FlutterCockpit.ensureInitialized bootstraps from app config', () {
    final binding = FlutterCockpit.ensureInitialized(
      const FlutterCockpitConfig(initialRouteName: '/settings'),
    );

    expect(binding.registry.routeName, '/settings');

    FlutterCockpit.dispose();
  });

  testWidgets(
    'FlutterCockpit.runApp bootstraps and mounts the cockpit root automatically',
    (tester) async {
      FlutterCockpit.runApp(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox.shrink(),
        ),
        config: const FlutterCockpitConfig(initialRouteName: '/run-app'),
      );
      await tester.pump();

      expect(find.byType(FlutterCockpitRoot), findsOneWidget);
      expect(FlutterCockpit.binding.registry.routeName, '/run-app');

      FlutterCockpit.dispose();
    },
  );
}

final class _NavigatorProbeApp extends StatelessWidget {
  const _NavigatorProbeApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorObservers: <NavigatorObserver>[FlutterCockpit.navigatorObserver],
      home: const SizedBox.shrink(),
    );
  }
}

final class _RoutePushButton extends StatelessWidget {
  const _RoutePushButton({required this.routeName});

  final String routeName;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => Navigator.of(context).pushNamed(routeName),
      child: const Text('Open details'),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_cockpit/flutter_cockpit_flutter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(FlutterCockpit.dispose);

  testWidgets(
    'FlutterCockpitRoot tracks route changes from the navigator observer',
    (tester) async {
      FlutterCockpit.initialize(
        const FlutterCockpitConfiguration(initialRouteName: '/'),
      );

      final rootKey = GlobalKey<FlutterCockpitRootState>();

      await tester.pumpWidget(
        FlutterCockpitRoot(
          key: rootKey,
          child: MaterialApp(
            navigatorObservers: [FlutterCockpit.navigatorObserver],
            routes: <String, WidgetBuilder>{
              '/': (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () =>
                        Navigator.of(context).pushNamed('/details'),
                    child: const Text('Open details'),
                  ),
                ),
              ),
              '/details': (_) =>
                  const Scaffold(body: Center(child: Text('Details'))),
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(rootKey.currentState!.snapshot().routeName, '/');

      await tester.tap(find.text('Open details'));
      await tester.pumpAndSettle();

      expect(rootKey.currentState!.snapshot().routeName, '/details');
    },
  );

  testWidgets(
    'FlutterCockpitRoot re-exposes previous route targets after a pushed route pops',
    (tester) async {
      FlutterCockpit.initialize(
        const FlutterCockpitConfiguration(initialRouteName: '/'),
      );

      final rootKey = GlobalKey<FlutterCockpitRootState>();

      await tester.pumpWidget(
        FlutterCockpitRoot(
          key: rootKey,
          child: MaterialApp(
            navigatorObservers: [FlutterCockpit.navigatorObserver],
            routes: <String, WidgetBuilder>{
              '/': (context) => Scaffold(
                body: Column(
                  children: <Widget>[
                    ElevatedButton(
                      key: const ValueKey<String>('home-compose-button'),
                      onPressed: () {},
                      child: const Text('Compose'),
                    ),
                    ElevatedButton(
                      onPressed: () =>
                          Navigator.of(context).pushNamed('/details'),
                      child: const Text('Open details'),
                    ),
                  ],
                ),
              ),
              '/details': (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    key: const ValueKey<String>('details-save-button'),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Save'),
                  ),
                ),
              ),
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        rootKey.currentState!.snapshot().visibleTargets.any(
          (target) => target.keyValue == 'home-compose-button',
        ),
        isTrue,
      );

      await tester.tap(find.text('Open details'));
      await tester.pumpAndSettle();

      final detailsSnapshot = rootKey.currentState!.snapshot();
      expect(detailsSnapshot.routeName, '/details');
      expect(
        detailsSnapshot.visibleTargets.any(
          (target) => target.keyValue == 'details-save-button',
        ),
        isTrue,
      );
      expect(
        detailsSnapshot.visibleTargets.any(
          (target) => target.keyValue == 'home-compose-button',
        ),
        isFalse,
      );

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final homeSnapshot = rootKey.currentState!.snapshot();
      expect(homeSnapshot.routeName, '/');
      expect(
        homeSnapshot.visibleTargets.any(
          (target) => target.keyValue == 'home-compose-button',
        ),
        isTrue,
      );
      expect(
        homeSnapshot.visibleTargets.any(
          (target) => target.keyValue == 'details-save-button',
        ),
        isFalse,
      );
    },
  );

  testWidgets(
    'FlutterCockpitRoot refreshes target route ownership after pushed routes mount',
    (tester) async {
      FlutterCockpit.initialize(
        const FlutterCockpitConfiguration(initialRouteName: '/'),
      );

      final rootKey = GlobalKey<FlutterCockpitRootState>();

      await tester.pumpWidget(
        FlutterCockpitRoot(
          key: rootKey,
          child: MaterialApp(
            navigatorObservers: [FlutterCockpit.navigatorObserver],
            initialRoute: '/inbox',
            routes: <String, WidgetBuilder>{
              '/inbox': (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () => Navigator.of(context).pushNamed('/details'),
                  child: const Text('Open details'),
                ),
              ),
              '/details': (context) => const Scaffold(
                body: CockpitTargetNode(
                  registrationId: 'details-title',
                  text: 'Details title',
                  child: Text('Details title'),
                ),
              ),
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open details'));
      await tester.pump();

      expect(rootKey.currentState!.snapshot().routeName, '/details');
      expect(
        rootKey.currentState!.snapshot().visibleTargets.any(
          (target) => target.text == 'Details title',
        ),
        isTrue,
      );
    },
  );

  testWidgets(
    'FlutterCockpitRoot discovers Material text fields on the current pushed route',
    (tester) async {
      FlutterCockpit.initialize(
        const FlutterCockpitConfiguration(initialRouteName: '/inbox'),
      );

      final rootKey = GlobalKey<FlutterCockpitRootState>();

      await tester.pumpWidget(
        FlutterCockpitRoot(
          key: rootKey,
          child: MaterialApp(
            navigatorObservers: [FlutterCockpit.navigatorObserver],
            initialRoute: '/inbox',
            routes: <String, WidgetBuilder>{
              '/inbox': (context) => Scaffold(
                body: Center(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pushNamed('/editor'),
                    child: const Text('New task'),
                  ),
                ),
              ),
              '/editor': (context) => const Scaffold(
                body: Padding(
                  padding: EdgeInsets.all(24),
                  child: TextField(
                    decoration: InputDecoration(labelText: 'Task title'),
                  ),
                ),
              ),
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('New task'));
      await tester.pumpAndSettle();

      final snapshot = rootKey.currentState!.snapshot();
      expect(snapshot.routeName, '/editor');
      expect(
        snapshot.visibleTargets.any(
          (target) =>
              target.routeName == '/editor' &&
              target.text == 'Task title' &&
              target.supportedCommands.contains(CockpitCommandType.enterText),
        ),
        isTrue,
      );
    },
  );

  testWidgets(
    'CockpitSurface refreshes stable child target ownership after routeName changes',
    (tester) async {
      final surfaceKey = GlobalKey<CockpitSurfaceState>();
      final routeName = ValueNotifier<String>('/inbox');
      addTearDown(routeName.dispose);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: ValueListenableBuilder<String>(
            valueListenable: routeName,
            child: const CockpitTargetNode(
              registrationId: 'stable-title-target',
              text: 'Task title',
              child: Text('Task title'),
            ),
            builder: (context, route, child) {
              return CockpitSurface(
                key: surfaceKey,
                routeName: route,
                child: child!,
              );
            },
          ),
        ),
      );
      await tester.pump();

      expect(surfaceKey.currentState!.snapshot().routeName, '/inbox');
      expect(
        surfaceKey.currentState!.snapshot().visibleTargets.single.routeName,
        '/inbox',
      );

      routeName.value = '/editor';
      await tester.pump();

      final snapshot = surfaceKey.currentState!.snapshot();
      expect(snapshot.routeName, '/editor');
      expect(snapshot.visibleTargets, hasLength(1));
      expect(snapshot.visibleTargets.single.text, 'Task title');
      expect(snapshot.visibleTargets.single.routeName, '/editor');
    },
  );

  testWidgets(
    'FlutterCockpitRoot captures a full-app Flutter screenshot without per-page CockpitSurface',
    (tester) async {
      FlutterCockpit.initialize(
        const FlutterCockpitConfiguration(initialRouteName: '/'),
      );

      final rootKey = GlobalKey<FlutterCockpitRootState>();

      await tester.pumpWidget(
        FlutterCockpitRoot(
          key: rootKey,
          child: MaterialApp(
            navigatorObservers: [FlutterCockpit.navigatorObserver],
            home: const Scaffold(body: Center(child: Text('Cockpit Root'))),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final capture = await tester.runAsync(() {
        return rootKey.currentState!.captureScreenshot(
          const CockpitScreenshotRequest(
            reason: CockpitScreenshotReason.acceptance,
            name: 'root-home',
            includeSnapshot: true,
            attachToStep: true,
          ),
        );
      });

      expect(capture, isNotNull);
      expect(capture!.screenshot.bytes.length, greaterThan(8));
      expect(capture.resolvedCaptureKind, CockpitCaptureKind.flutterView);
      expect(capture.screenshot.snapshot?.routeName, '/');
      expect(
        capture.screenshot.snapshot?.diagnosticLevel,
        CockpitSnapshotProfile.investigate,
      );
      expect(
        capture.screenshot.snapshot?.summary?.accessibilitySummaryIncluded,
        isTrue,
      );
    },
  );

  testWidgets(
    'FlutterCockpitRoot waits for network idle before acceptance capture',
    (tester) async {
      final observer = _TrackingNetworkObserver();
      FlutterCockpit.initialize(
        FlutterCockpitConfiguration(
          initialRouteName: '/',
          networkObserver: observer,
        ),
      );

      final rootKey = GlobalKey<FlutterCockpitRootState>();

      await tester.pumpWidget(
        FlutterCockpitRoot(
          key: rootKey,
          child: MaterialApp(
            navigatorObservers: [FlutterCockpit.navigatorObserver],
            home: const Scaffold(body: Center(child: Text('Cockpit Root'))),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final capture = await tester.runAsync(() {
        return rootKey.currentState!.captureScreenshot(
          const CockpitScreenshotRequest(
            reason: CockpitScreenshotReason.acceptance,
            name: 'root-home-idle',
            includeSnapshot: true,
            attachToStep: true,
          ),
        );
      });

      expect(capture, isNotNull);
      expect(observer.waitCount, 1);
      expect(observer.lastQuietWindow, const Duration(milliseconds: 96));
      expect(observer.lastTimeout, isNotNull);
      expect(
        observer.lastTimeout!.inMilliseconds,
        inInclusiveRange(1560, 1600),
      );
    },
  );

  testWidgets(
    'FlutterCockpitRoot skips native capture when the platform reports it as unavailable',
    (tester) async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final channel = const MethodChannel(
        'dev.cockpit.flutter_cockpit/capture',
      );

      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'queryNativeCaptureAvailability') {
          return false;
        }
        fail('native capture should not be invoked when unavailable');
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

      FlutterCockpit.initialize(
        FlutterCockpitConfiguration(
          initialRouteName: '/',
          nativeCapture: CockpitNativeCapture(channel: channel),
        ),
      );

      final rootKey = GlobalKey<FlutterCockpitRootState>();

      await tester.pumpWidget(
        FlutterCockpitRoot(
          key: rootKey,
          child: MaterialApp(
            navigatorObservers: [FlutterCockpit.navigatorObserver],
            home: const Scaffold(body: Center(child: Text('Cockpit Root'))),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final capture = await tester.runAsync(() {
        return rootKey.currentState!.captureScreenshot(
          const CockpitScreenshotRequest(
            reason: CockpitScreenshotReason.acceptance,
            name: 'root-home-no-native',
            includeSnapshot: true,
            attachToStep: true,
          ),
        );
      });

      expect(capture, isNotNull);
      expect(capture!.resolvedCaptureKind, CockpitCaptureKind.flutterView);
      expect(capture.usedFallback, isFalse);
      expect(capture.screenshot.bytes.length, greaterThan(8));
    },
  );

  testWidgets(
    'FlutterCockpitRoot falls back to Flutter capture when native capture fails',
    (tester) async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final channel = const MethodChannel(
        'dev.cockpit.flutter_cockpit/capture',
      );

      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'queryNativeCaptureAvailability') {
          return true;
        }
        if (call.method == 'captureAcceptanceScreenshot') {
          throw PlatformException(
            code: 'blankCapture',
            message: 'Native screenshot capture produced a blank image.',
          );
        }
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

      FlutterCockpit.initialize(
        FlutterCockpitConfiguration(
          initialRouteName: '/',
          nativeCapture: CockpitNativeCapture(channel: channel),
        ),
      );

      final rootKey = GlobalKey<FlutterCockpitRootState>();

      await tester.pumpWidget(
        FlutterCockpitRoot(
          key: rootKey,
          child: MaterialApp(
            navigatorObservers: [FlutterCockpit.navigatorObserver],
            home: const Scaffold(body: Center(child: Text('Cockpit Root'))),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final capture = await tester.runAsync(() {
        return rootKey.currentState!.captureScreenshot(
          const CockpitScreenshotRequest(
            reason: CockpitScreenshotReason.acceptance,
            name: 'root-home-fallback',
            includeSnapshot: true,
            attachToStep: true,
          ),
        );
      });

      expect(capture, isNotNull);
      expect(capture!.resolvedCaptureKind, CockpitCaptureKind.flutterView);
      expect(capture.usedFallback, isTrue);
      expect(capture.degradationReason, contains('blank image'));
      expect(capture.screenshot.snapshot?.routeName, '/');
      expect(capture.screenshot.bytes.length, greaterThan(8));
    },
  );

  testWidgets(
    'FlutterCockpitRoot remote health publishes environment when flutter metadata is configured',
    (tester) async {
      FlutterCockpit.initialize(
        const FlutterCockpitConfiguration(
          initialRouteName: '/',
          flutterVersion: '3.38.9',
          remoteSession: CockpitRemoteSessionConfiguration(
            enabled: true,
            autoStart: false,
            host: '127.0.0.1',
            port: 0,
          ),
        ),
      );

      final rootKey = GlobalKey<FlutterCockpitRootState>();

      await tester.pumpWidget(
        FlutterCockpitRoot(
          key: rootKey,
          child: MaterialApp(
            navigatorObservers: [FlutterCockpit.navigatorObserver],
            routes: <String, WidgetBuilder>{
              '/': (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () =>
                        Navigator.of(context).pushNamed('/details'),
                    child: const Text('Open details'),
                  ),
                ),
              ),
              '/details': (_) =>
                  const Scaffold(body: Center(child: Text('Details'))),
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open details'));
      await tester.pumpAndSettle();

      final status = (await tester.runAsync(() {
        return rootKey.currentState!.remoteSessionStatus();
      }))!;
      final environmentJson =
          status.toJson()['environment'] as Map<String, Object?>?;

      expect(environmentJson, isNotNull);
      expect(environmentJson?['platform'], 'android');
      expect(environmentJson?['flutterVersion'], '3.38.9');
      expect(environmentJson?['dartVersion'], isA<String>());
      expect((environmentJson?['dartVersion'] as String?)?.isNotEmpty, isTrue);
      expect(environmentJson?.keys, <String>[
        'platform',
        'flutterVersion',
        'dartVersion',
      ]);
      expect(status.currentRouteName, '/details');
      expect(status.snapshot.routeName, '/details');
    },
  );

  testWidgets(
    'FlutterCockpitRoot remote health omits environment when flutter metadata is unavailable',
    (tester) async {
      FlutterCockpit.initialize(
        const FlutterCockpitConfiguration(
          initialRouteName: '/',
          remoteSession: CockpitRemoteSessionConfiguration(
            enabled: true,
            autoStart: false,
            host: '127.0.0.1',
            port: 0,
          ),
        ),
      );

      final rootKey = GlobalKey<FlutterCockpitRootState>();

      await tester.pumpWidget(
        FlutterCockpitRoot(
          key: rootKey,
          child: MaterialApp(
            navigatorObservers: [FlutterCockpit.navigatorObserver],
            home: const Scaffold(body: Center(child: Text('Cockpit Root'))),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final status = (await tester.runAsync(() {
        return rootKey.currentState!.remoteSessionStatus();
      }))!;

      expect(status.toJson()['environment'], isNull);
    },
  );

  testWidgets(
    'FlutterCockpitRoot remote health exposes captured runtime errors',
    (tester) async {
      FlutterCockpit.initialize(
        const FlutterCockpitConfiguration(
          initialRouteName: '/',
          remoteSession: CockpitRemoteSessionConfiguration(
            enabled: true,
            autoStart: false,
            host: '127.0.0.1',
            port: 0,
          ),
        ),
      );

      final rootKey = GlobalKey<FlutterCockpitRootState>();

      await tester.pumpWidget(
        FlutterCockpitRoot(
          key: rootKey,
          child: MaterialApp(
            navigatorObservers: [FlutterCockpit.navigatorObserver],
            home: const Scaffold(body: Center(child: Text('Cockpit Root'))),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final observer =
          FlutterCockpit.binding.runtimeObserver
              as CockpitFlutterRuntimeObserver?;
      observer?.recordFlutterFrameworkError(
        FlutterErrorDetails(
          exception: StateError('runtime exploded'),
          stack: StackTrace.current,
          library: 'widgets',
        ),
      );

      final status = (await tester.runAsync(() {
        return rootKey.currentState!.remoteSessionStatus();
      }))!;

      expect(status.snapshot.runtime, isNotNull);
      expect(status.snapshot.runtime!.errorCount, 1);
      expect(
        status.snapshot.runtime!.entries.first.message,
        contains('runtime exploded'),
      );
    },
  );
}

final class _TrackingNetworkObserver implements CockpitNetworkObserver {
  int waitCount = 0;
  Duration? lastQuietWindow;
  Duration? lastTimeout;

  @override
  void clear() {}

  @override
  Future<bool> waitForIdle({
    Duration quietWindow = const Duration(milliseconds: 150),
    Duration timeout = const Duration(seconds: 2),
  }) async {
    waitCount += 1;
    lastQuietWindow = quietWindow;
    lastTimeout = timeout;
    return true;
  }

  @override
  CockpitNetworkSnapshot snapshot({
    int maxEntries = 10,
    CockpitNetworkQuery query = const CockpitNetworkQuery(),
  }) {
    return CockpitNetworkSnapshot(
      totalEntryCount: 0,
      failureCount: 0,
      entries: const <CockpitNetworkEntry>[],
      capturedEntryCount: 0,
      query: query,
    );
  }
}

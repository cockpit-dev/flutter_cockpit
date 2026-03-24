import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cockpit/flutter_cockpit_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'FlutterCockpitRoot starts and stops a recording through the runtime binding',
    (tester) async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final channel = MethodChannel('dev.cockpit.flutter_cockpit/recording');
      var started = false;

      messenger.setMockMethodCallHandler(channel, (call) async {
        switch (call.method) {
          case 'queryRecordingCapabilities':
            return <String, Object?>{
              'supportsNativeRecording': true,
              'preferredAcceptanceRecordingKind': 'nativeScreen',
              'recordingLimitations': <String>[],
            };
          case 'startRecording':
            started = true;
            return <String, Object?>{'state': 'recording'};
          case 'stopRecording':
            expect(started, isTrue);
            return <String, Object?>{
              'state': 'completed',
              'recordingKind': 'nativeScreen',
              'durationMs': 2400,
              'bytes': Uint8List.fromList(const <int>[0, 1, 2, 3]),
            };
          default:
            return null;
        }
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

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

      final capabilities =
          await rootKey.currentState!.queryRecordingCapabilities();
      expect(capabilities.supportsNativeRecording, isTrue);

      final session = await rootKey.currentState!.startRecording(
        const CockpitRecordingRequest(
          purpose: CockpitRecordingPurpose.acceptance,
          name: 'home_acceptance',
          attachToStep: true,
        ),
      );

      expect(session.state, CockpitRecordingState.recording);
      expect(FlutterCockpit.binding.activeRecordingSession, session);

      await tester.tap(find.text('Open details'));
      await tester.pumpAndSettle();

      expect(
        FlutterCockpit.binding.activeRecordingSession?.request.name,
        'home_acceptance',
      );

      final result = await rootKey.currentState!.stopRecording();
      expect(result.state, CockpitRecordingState.completed);
      expect(result.recordingKind, CockpitRecordingKind.nativeScreen);
      expect(result.artifact?.relativePath, 'recordings/home_acceptance.mp4');
      expect(result.durationMs, 2400);
      expect(FlutterCockpit.binding.activeRecordingSession, isNull);
    },
  );

  testWidgets(
    'FlutterCockpitRoot returns a structured failure when no recording is active',
    (tester) async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final channel = MethodChannel('dev.cockpit.flutter_cockpit/recording');
      messenger.setMockMethodCallHandler(channel, (call) async {
        switch (call.method) {
          case 'queryRecordingCapabilities':
            return <String, Object?>{
              'supportsNativeRecording': true,
              'preferredAcceptanceRecordingKind': 'nativeScreen',
              'recordingLimitations': <String>[],
            };
          default:
            fail('No platform call expected for ${call.method}.');
        }
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

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

      final result = await rootKey.currentState!.stopRecording();
      expect(result.state, CockpitRecordingState.failed);
      expect(result.failureReason, 'recordingNotActive');
      expect(result.artifact, isNull);
    },
  );
}

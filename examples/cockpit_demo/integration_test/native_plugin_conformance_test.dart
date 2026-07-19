import 'package:cockpit_demo/main.dart' as app;
import 'package:flutter/foundation.dart';
import 'package:flutter_cockpit/flutter_cockpit_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('public native plugin conformance', (tester) async {
    app.main();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    final report = <String, Object?>{
      'status': 'passed',
      'platform': _platformName(),
      'capabilitySnapshot': <String, Object?>{},
      'capture': <String, Object?>{},
      'recording': <String, Object?>{},
      'assertions': <String, Object?>{},
    };

    try {
      final nativeCapture = const CockpitNativeCapture();
      final nativeRecording = const CockpitNativeRecording();
      final captureAvailable = await nativeCapture.queryAvailability();
      final capabilities = await nativeRecording.queryCapabilities();
      report['capabilitySnapshot'] = <String, Object?>{
        'nativeCaptureAvailable': captureAvailable,
        ...capabilities.toJson(),
      };

      final captureReport = <String, Object?>{
        'available': captureAvailable,
        'validated': false,
      };
      if (captureAvailable) {
        final request = const CockpitScreenshotRequest(
          reason: CockpitScreenshotReason.acceptance,
          name: 'native_plugin_conformance',
          profile: CockpitCaptureProfile.acceptance,
          allowFallback: false,
        );
        final screenshot = await nativeCapture.capture(
          request: request,
          profile: CockpitCaptureProfile.acceptance,
        );
        final bytes = screenshot.bytes;
        expect(bytes, isA<Uint8List>());
        expect(bytes, isNotEmpty);
        captureReport['byteLength'] = bytes.length;
        captureReport['validated'] = true;
      } else {
        captureReport['reason'] = 'nativeCaptureUnavailable';
      }
      report['capture'] = captureReport;

      final recordingReport = <String, Object?>{
        'supportsNativeRecording': capabilities.supportsNativeRecording,
        'duplicateStartRejected': false,
        'postFinalizeStopRejected': false,
      };
      if (capabilities.supportsNativeRecording) {
        final request = CockpitRecordingRequest(
          purpose: CockpitRecordingPurpose.acceptance,
          name: 'native_plugin_conformance',
          mode: CockpitRecordingMode.native,
          layer: capabilities.preferredLayer,
          allowFallback: false,
        );
        final session = await nativeRecording.startRecording(request: request);
        expect(session.state, CockpitRecordingState.recording);

        try {
          await nativeRecording.startRecording(request: request);
        } on Object catch (error) {
          recordingReport['duplicateStartRejected'] = true;
          recordingReport['duplicateStartError'] = '$error';
        }
        expect(recordingReport['duplicateStartRejected'], isTrue);

        await tester.pump(const Duration(milliseconds: 250));
        final stopped = await nativeRecording.stopRecording(session: session);
        expect(stopped.state, CockpitRecordingState.completed);
        expect(stopped.artifact, isNotNull);
        recordingReport['completed'] = true;
        recordingReport['recordingKind'] = stopped.recordingKind?.name;
        recordingReport['sourceFilePath'] = stopped.sourceFilePath;
        recordingReport['durationMs'] = stopped.durationMs;

        final postFinalize = await nativeRecording.stopRecording(
          session: session,
        );
        recordingReport['postFinalizeStopRejected'] =
            postFinalize.state == CockpitRecordingState.failed;
        recordingReport['postFinalizeStopState'] = postFinalize.state.name;
        expect(recordingReport['postFinalizeStopRejected'], isTrue);
      } else {
        recordingReport['unavailableBranchTested'] = true;
        recordingReport['reason'] = 'recordingUnavailable';
        if (kIsWeb) {
          expect(capabilities.supportsNativeRecording, isFalse);
          expect(captureAvailable, isFalse);
        }
      }
      report['recording'] = recordingReport;
      report['assertions'] = <String, Object?>{
        'capabilitySnapshot': true,
        'acceptanceScreenshotValidation': captureReport['validated'] == true,
        'acceptanceVideoValidation':
            recordingReport['completed'] == true ||
            recordingReport['unavailableBranchTested'] == true,
      };
    } catch (error, stackTrace) {
      report['status'] = 'failed';
      report['error'] = '$error';
      report['stackTrace'] = '$stackTrace';
    }

    binding.reportData = <String, dynamic>{'nativePluginConformance': report};
    expect(report['status'], 'passed');
  });
}

String _platformName() {
  if (kIsWeb) {
    return 'web';
  }
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => 'android',
    TargetPlatform.iOS => 'ios',
    TargetPlatform.linux => 'linux',
    TargetPlatform.macOS => 'macos',
    TargetPlatform.windows => 'windows',
    TargetPlatform.fuchsia => 'fuchsia',
  };
}

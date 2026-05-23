import 'package:flutter/services.dart';

import '../model/cockpit_artifact_ref.dart';
import 'cockpit_recording_capabilities.dart';
import 'cockpit_recording_kind.dart';
import 'cockpit_recording_layer.dart';
import 'cockpit_recording_paths.dart';
import 'cockpit_recording_request.dart';
import 'cockpit_recording_result.dart';
import 'cockpit_recording_session.dart';
import 'cockpit_recording_state.dart';

class CockpitNativeRecording {
  const CockpitNativeRecording({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_channelName);

  static const String _channelName = 'dev.cockpit.flutter_cockpit/recording';

  final MethodChannel _channel;

  Future<CockpitRecordingCapabilities> queryCapabilities() async {
    final payload = await _channel.invokeMethod<Object?>(
      'queryRecordingCapabilities',
    );
    if (payload is! Map<Object?, Object?>) {
      throw StateError('Recording capabilities returned an invalid payload.');
    }

    return CockpitRecordingCapabilities.fromJson(
      Map<String, Object?>.from(payload),
    );
  }

  Future<CockpitRecordingSession> startRecording({
    required CockpitRecordingRequest request,
  }) async {
    final payload = await _channel
        .invokeMethod<Object?>('startRecording', <String, Object?>{
          'purpose': request.purpose.name,
          'name': request.name,
          'mode': request.mode.jsonValue,
          'layer': request.layer?.jsonValue,
          'allowFallback': request.allowFallback,
          'attachToStep': request.attachToStep,
          'relativePath': cockpitRecordingRelativePathFor(request),
        });
    if (payload is! Map<Object?, Object?>) {
      throw StateError('Start recording returned an invalid payload.');
    }

    final state = payload['state'] == null
        ? CockpitRecordingState.recording
        : CockpitRecordingState.fromJson(payload['state']);
    return CockpitRecordingSession(request: request, state: state);
  }

  Future<CockpitRecordingResult> stopRecording({
    required CockpitRecordingSession session,
  }) async {
    final payload = await _channel
        .invokeMethod<Object?>('stopRecording', <String, Object?>{
          'purpose': session.request.purpose.name,
          'name': session.request.name,
          'relativePath': cockpitRecordingRelativePathFor(session.request),
        });
    if (payload is! Map<Object?, Object?>) {
      throw StateError('Stop recording returned an invalid payload.');
    }

    final bytes = payload['bytes'];
    final state = CockpitRecordingState.fromJson(payload['state']);
    final relativePath = cockpitRecordingRelativePathFor(session.request);

    return CockpitRecordingResult(
      state: state,
      purpose: session.request.purpose,
      recordingKind: payload['recordingKind'] == null
          ? CockpitRecordingKind.nativeScreen
          : CockpitRecordingKind.fromJson(payload['recordingKind']),
      requestedMode: session.request.mode,
      requestedLayer: session.request.layer,
      effectiveLayer: payload['effectiveLayer'] == null
          ? session.request.layer
          : CockpitRecordingLayer.fromJson(payload['effectiveLayer']),
      fallbackUsed: payload['fallbackUsed'] as bool? ?? false,
      fallbackReason: payload['fallbackReason'] as String?,
      artifact: state == CockpitRecordingState.completed
          ? CockpitArtifactRef(role: 'recording', relativePath: relativePath)
          : null,
      durationMs: payload['durationMs'] as int?,
      bytes: bytes == null ? null : (bytes is Uint8List ? bytes : null),
      sourceFilePath: payload['sourceFilePath'] as String?,
      failureReason: payload['failureReason'] as String?,
    );
  }
}

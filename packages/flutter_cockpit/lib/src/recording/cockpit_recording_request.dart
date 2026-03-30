import 'cockpit_recording_purpose.dart';

final class CockpitRecordingRequest {
  const CockpitRecordingRequest({
    required this.purpose,
    required this.name,
    this.attachToStep = false,
    this.tailStabilizationDelay = const Duration(milliseconds: 1400),
  });

  final CockpitRecordingPurpose purpose;
  final String name;
  final bool attachToStep;
  final Duration tailStabilizationDelay;

  Map<String, Object?> toJson() => {
        'purpose': purpose.name,
        'name': name,
        'attachToStep': attachToStep,
        'tailStabilizationMs': tailStabilizationDelay.inMilliseconds,
      };

  factory CockpitRecordingRequest.fromJson(Map<String, Object?> json) {
    final purpose = CockpitRecordingPurpose.fromJson(json['purpose']);
    return CockpitRecordingRequest(
      purpose: purpose,
      name: (json['name'] as String?)?.trim().isNotEmpty == true
          ? json['name']! as String
          : purpose.name,
      attachToStep: json['attachToStep'] as bool? ?? false,
      tailStabilizationDelay: Duration(
        milliseconds: (json['tailStabilizationMs'] as int?) ??
            (json['tail_stabilization_ms'] as int?) ??
            1400,
      ),
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CockpitRecordingRequest &&
            other.purpose == purpose &&
            other.name == name &&
            other.attachToStep == attachToStep &&
            other.tailStabilizationDelay == tailStabilizationDelay;
  }

  @override
  int get hashCode =>
      Object.hash(purpose, name, attachToStep, tailStabilizationDelay);
}

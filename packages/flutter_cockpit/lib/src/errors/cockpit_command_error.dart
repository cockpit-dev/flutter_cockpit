import 'package:collection/collection.dart';

final class CockpitCommandError {
  CockpitCommandError({
    required this.code,
    required this.message,
    Map<String, Object?> details = const <String, Object?>{},
  }) : details = Map.unmodifiable(details);

  static const String targetNotFoundCode = 'targetNotFound';
  static const String ambiguousTargetCode = 'ambiguousTarget';
  static const String timeoutCode = 'timeout';
  static const String assertionFailedCode = 'assertionFailed';
  static const String captureFailedCode = 'captureFailed';
  static const String unsupportedCapabilityCode = 'unsupportedCapability';
  static const String invalidGestureParametersCode = 'invalidGestureParameters';
  static const String gestureExecutionFailedCode = 'gestureExecutionFailed';
  static const String targetNotHittableCode = 'targetNotHittable';

  final String code;
  final String message;
  final Map<String, Object?> details;

  static const MapEquality<String, Object?> _mapEquality =
      MapEquality<String, Object?>();

  factory CockpitCommandError.targetNotFound({
    required String message,
    Map<String, Object?> details = const <String, Object?>{},
  }) {
    return CockpitCommandError(
      code: targetNotFoundCode,
      message: message,
      details: details,
    );
  }

  factory CockpitCommandError.ambiguousTarget({
    required String message,
    Map<String, Object?> details = const <String, Object?>{},
  }) {
    return CockpitCommandError(
      code: ambiguousTargetCode,
      message: message,
      details: details,
    );
  }

  factory CockpitCommandError.timeout({
    required String message,
    Map<String, Object?> details = const <String, Object?>{},
  }) {
    return CockpitCommandError(
      code: timeoutCode,
      message: message,
      details: details,
    );
  }

  factory CockpitCommandError.assertionFailed({
    required String message,
    Map<String, Object?> details = const <String, Object?>{},
  }) {
    return CockpitCommandError(
      code: assertionFailedCode,
      message: message,
      details: details,
    );
  }

  factory CockpitCommandError.captureFailed({
    required String message,
    Map<String, Object?> details = const <String, Object?>{},
  }) {
    return CockpitCommandError(
      code: captureFailedCode,
      message: message,
      details: details,
    );
  }

  factory CockpitCommandError.unsupportedCapability({
    required String message,
    Map<String, Object?> details = const <String, Object?>{},
  }) {
    return CockpitCommandError(
      code: unsupportedCapabilityCode,
      message: message,
      details: details,
    );
  }

  factory CockpitCommandError.invalidGestureParameters({
    required String message,
    Map<String, Object?> details = const <String, Object?>{},
  }) {
    return CockpitCommandError(
      code: invalidGestureParametersCode,
      message: message,
      details: details,
    );
  }

  factory CockpitCommandError.gestureExecutionFailed({
    required String message,
    Map<String, Object?> details = const <String, Object?>{},
  }) {
    return CockpitCommandError(
      code: gestureExecutionFailedCode,
      message: message,
      details: details,
    );
  }

  factory CockpitCommandError.targetNotHittable({
    required String message,
    Map<String, Object?> details = const <String, Object?>{},
  }) {
    return CockpitCommandError(
      code: targetNotHittableCode,
      message: message,
      details: details,
    );
  }

  Map<String, Object?> toJson() => {
        'code': code,
        'message': message,
        'details': details,
      };

  factory CockpitCommandError.fromJson(Map<String, Object?> json) {
    return CockpitCommandError(
      code: json['code']! as String,
      message: json['message']! as String,
      details: Map<String, Object?>.from(
        (json['details'] as Map<Object?, Object?>?) ??
            const <Object?, Object?>{},
      ),
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CockpitCommandError &&
            other.code == code &&
            other.message == message &&
            _mapEquality.equals(other.details, details);
  }

  @override
  int get hashCode => Object.hash(code, message, _mapEquality.hash(details));
}

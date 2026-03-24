import 'package:collection/collection.dart';

enum CockpitMultiTouchPhase {
  down,
  move,
  up;

  static CockpitMultiTouchPhase fromJson(Object? json) {
    return values.byName(json! as String);
  }
}

final class CockpitMultiTouchStep {
  const CockpitMultiTouchStep({
    required this.pointer,
    required this.phase,
    required this.atMs,
    required this.dx,
    required this.dy,
  });

  final int pointer;
  final CockpitMultiTouchPhase phase;
  final int atMs;
  final double dx;
  final double dy;

  Map<String, Object?> toJson() => <String, Object?>{
        'pointer': pointer,
        'phase': phase.name,
        'atMs': atMs,
        'dx': dx,
        'dy': dy,
      };

  factory CockpitMultiTouchStep.fromJson(Map<String, Object?> json) {
    return CockpitMultiTouchStep(
      pointer: json['pointer']! as int,
      phase: CockpitMultiTouchPhase.fromJson(json['phase']),
      atMs: json['atMs']! as int,
      dx: (json['dx'] as num).toDouble(),
      dy: (json['dy'] as num).toDouble(),
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CockpitMultiTouchStep &&
            other.pointer == pointer &&
            other.phase == phase &&
            other.atMs == atMs &&
            other.dx == dx &&
            other.dy == dy;
  }

  @override
  int get hashCode => Object.hash(pointer, phase, atMs, dx, dy);
}

final class CockpitMultiTouchSequence {
  const CockpitMultiTouchSequence({required this.steps});

  final List<CockpitMultiTouchStep> steps;

  static const ListEquality<CockpitMultiTouchStep> _stepEquality =
      ListEquality<CockpitMultiTouchStep>();

  Map<String, Object?> toJson() => <String, Object?>{
        'steps': steps.map((step) => step.toJson()).toList(growable: false),
      };

  factory CockpitMultiTouchSequence.fromJson(Map<String, Object?> json) {
    return CockpitMultiTouchSequence(
      steps: (json['steps'] as List<Object?>? ?? const <Object?>[])
          .map(
            (step) => CockpitMultiTouchStep.fromJson(
              Map<String, Object?>.from(step! as Map<Object?, Object?>),
            ),
          )
          .toList(growable: false),
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CockpitMultiTouchSequence &&
            _stepEquality.equals(other.steps, steps);
  }

  @override
  int get hashCode => _stepEquality.hash(steps);
}

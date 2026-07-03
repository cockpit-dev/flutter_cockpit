import 'package:collection/collection.dart';
import 'package:flutter_cockpit_protocol/flutter_cockpit_protocol.dart';

import 'cockpit_intent_action.dart';
import 'cockpit_intent_subject.dart';

final class CockpitIntent {
  CockpitIntent({
    required this.intentId,
    required this.subject,
    required this.action,
    this.executionPolicy = CockpitExecutionPolicy.auto,
    this.evidencePolicy = const CockpitEvidencePolicy(),
    this.locator,
    Map<String, Object?> input = const <String, Object?>{},
  }) : input = Map.unmodifiable(input);

  final String intentId;
  final CockpitIntentSubject subject;
  final CockpitIntentAction action;
  final CockpitExecutionPolicy executionPolicy;
  final CockpitEvidencePolicy evidencePolicy;
  final CockpitLocator? locator;
  final Map<String, Object?> input;

  static const MapEquality<String, Object?> _mapEquality =
      MapEquality<String, Object?>();

  factory CockpitIntent.tap({
    required CockpitLocator locator,
    CockpitExecutionPolicy executionPolicy = CockpitExecutionPolicy.auto,
    CockpitEvidencePolicy evidencePolicy = const CockpitEvidencePolicy(),
  }) {
    return CockpitIntent(
      intentId: 'tap:${locator.toJson()}',
      subject: CockpitIntentSubject.surface,
      action: CockpitIntentAction.tap,
      executionPolicy: executionPolicy,
      evidencePolicy: evidencePolicy,
      locator: locator,
    );
  }

  factory CockpitIntent.runHostShell({
    required List<String> command,
    CockpitExecutionPolicy executionPolicy = CockpitExecutionPolicy.auto,
    CockpitEvidencePolicy evidencePolicy = const CockpitEvidencePolicy(),
  }) {
    return CockpitIntent(
      intentId: 'host-shell:${command.join(' ')}',
      subject: CockpitIntentSubject.host,
      action: CockpitIntentAction.runShell,
      executionPolicy: executionPolicy,
      evidencePolicy: evidencePolicy,
      input: <String, Object?>{'command': command},
    );
  }

  factory CockpitIntent.fromCommand(
    CockpitCommand command, {
    CockpitExecutionPolicy executionPolicy = CockpitExecutionPolicy.auto,
    CockpitEvidencePolicy evidencePolicy = const CockpitEvidencePolicy(),
  }) {
    return CockpitIntent(
      intentId: command.commandId,
      subject: CockpitIntentSubject.surface,
      action: CockpitIntentAction.fromCommandType(command.commandType),
      executionPolicy: executionPolicy,
      evidencePolicy: evidencePolicy,
      locator: command.locator,
      input: command.parameters,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CockpitIntent &&
            other.intentId == intentId &&
            other.subject == subject &&
            other.action == action &&
            other.executionPolicy == executionPolicy &&
            other.evidencePolicy == evidencePolicy &&
            other.locator == locator &&
            _mapEquality.equals(other.input, input);
  }

  @override
  int get hashCode => Object.hash(
    intentId,
    subject,
    action,
    executionPolicy,
    evidencePolicy,
    locator,
    _mapEquality.hash(input),
  );
}

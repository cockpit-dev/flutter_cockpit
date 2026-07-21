import 'dart:io';

import 'cockpit_lease_support.dart';

final class CockpitExpectedPortOwner {
  CockpitExpectedPortOwner({
    required this.ownerId,
    required this.processId,
    required this.processStartIdentity,
    required this.sessionId,
  }) {
    _validateId(ownerId, 'ownerId');
    _validateId(sessionId, 'sessionId');
    if (processId <= 0 ||
        processStartIdentity.trim().isEmpty ||
        processStartIdentity.length > 512) {
      throw const FormatException('Expected port owner identity is invalid.');
    }
  }

  final String ownerId;
  final int processId;
  final String processStartIdentity;
  final String sessionId;
}

final class CockpitObservedPortOwner {
  CockpitObservedPortOwner({
    required this.ownerId,
    required this.processId,
    required this.processStartIdentity,
    required this.sessionId,
    required this.handoffToken,
  }) {
    CockpitExpectedPortOwner(
      ownerId: ownerId,
      processId: processId,
      processStartIdentity: processStartIdentity,
      sessionId: sessionId,
    );
    if (!cockpitIsValidPortHandoffToken(handoffToken)) {
      throw const FormatException('Observed port handoff token is invalid.');
    }
  }

  final String ownerId;
  final int processId;
  final String processStartIdentity;
  final String sessionId;
  final String handoffToken;

  bool matches(CockpitExpectedPortOwner expected, String expectedToken) =>
      ownerId == expected.ownerId &&
      processId == expected.processId &&
      processStartIdentity == expected.processStartIdentity &&
      sessionId == expected.sessionId &&
      handoffToken == expectedToken;
}

final class CockpitPortBindRequest {
  const CockpitPortBindRequest({
    required this.address,
    required this.port,
    required this.handoffToken,
    required this.deadline,
  });

  final InternetAddress address;
  final int port;
  final String handoffToken;
  final DateTime deadline;
}

abstract interface class CockpitPortBinder {
  Future<void> bind(CockpitPortBindRequest request);
}

abstract interface class CockpitPortOwnerProbe {
  Future<CockpitObservedPortOwner?> inspect({
    required InternetAddress address,
    required int port,
    required DateTime deadline,
  });
}

void _validateId(String value, String name) {
  if (!cockpitIsValidSupervisorId(value)) {
    throw FormatException('Invalid $name.');
  }
}

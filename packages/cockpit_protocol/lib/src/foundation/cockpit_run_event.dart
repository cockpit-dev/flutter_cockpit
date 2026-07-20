import '../test/cockpit_test_diagnostic.dart';
import '../test/cockpit_test_policy.dart';
import 'cockpit_api_error.dart';
import 'cockpit_decode_policy.dart';
import 'cockpit_foundation_artifact.dart';
import 'cockpit_foundation_value_reader.dart';
import 'cockpit_run.dart';

final class CockpitRunEvent {
  CockpitRunEvent({
    required this.eventId,
    required this.sequence,
    required this.timestamp,
    required this.kind,
    required this.projectId,
    required this.workspaceId,
    required this.runId,
    required this.caseId,
    this.attemptId,
    this.stepExecutionId,
    this.lifecycle,
    this.outcome,
    this.stability,
    this.sourceLocation,
    this.targetId,
    this.requestedPlane,
    this.actualPlane,
    this.driverId,
    this.degradation,
    Map<String, Object?> locatorSummary = const <String, Object?>{},
    this.failure,
    Iterable<CockpitArtifactReference> artifacts =
        const <CockpitArtifactReference>[],
  }) : locatorSummary = CockpitFoundationValueReader.jsonObject(
         locatorSummary,
         r'$.locatorSummary',
       ),
       artifacts = List<CockpitArtifactReference>.unmodifiable(artifacts) {
    for (final entry in <String, String>{
      'eventId': eventId,
      'projectId': projectId,
      'workspaceId': workspaceId,
      'runId': runId,
      'caseId': caseId,
    }.entries) {
      CockpitFoundationValueReader.id(entry.value, '\$.${entry.key}');
    }
    CockpitFoundationValueReader.integer(sequence, r'$.sequence', min: 1);
    CockpitFoundationValueReader.utcDateTime(timestamp, r'$.timestamp');
    CockpitFoundationValueReader.kind(kind, r'$.kind');
    if (attemptId != null) {
      CockpitFoundationValueReader.id(attemptId, r'$.attemptId');
    }
    if (stepExecutionId != null) {
      CockpitFoundationValueReader.string(
        stepExecutionId,
        r'$.stepExecutionId',
        maximum: 512,
      );
      if (attemptId == null) {
        throw const FormatException('Step event requires an attemptId.');
      }
    }
    if (targetId != null) {
      CockpitFoundationValueReader.id(targetId, r'$.targetId');
    }
    if (driverId != null) {
      CockpitFoundationValueReader.id(driverId, r'$.driverId');
    }
    if (degradation != null) {
      CockpitFoundationValueReader.string(
        degradation,
        r'$.degradation',
        maximum: 512,
      );
    }
    _validateState(this);
    if (failure != null &&
        failure!.artifacts.any((artifact) => artifact.runId != runId)) {
      throw const FormatException(
        'Event failure artifact belongs to another run.',
      );
    }
    final artifactIds = <String>{};
    for (final artifact in this.artifacts) {
      if (artifact.runId != runId) {
        throw const FormatException('Event artifact belongs to another run.');
      }
      if (!artifactIds.add(artifact.artifactId)) {
        throw FormatException(
          'Duplicate event artifact ${artifact.artifactId}.',
        );
      }
    }
  }

  final String eventId;
  final int sequence;
  final DateTime timestamp;
  final String kind;
  final String projectId;
  final String workspaceId;
  final String runId;
  final String caseId;
  final String? attemptId;
  final String? stepExecutionId;
  final CockpitRunLifecycle? lifecycle;
  final CockpitRunOutcome? outcome;
  final CockpitRunStability? stability;
  final CockpitTestSourceLocation? sourceLocation;
  final String? targetId;
  final CockpitTestPlane? requestedPlane;
  final CockpitTestPlane? actualPlane;
  final String? driverId;
  final String? degradation;
  final Map<String, Object?> locatorSummary;
  final CockpitFailure? failure;
  final List<CockpitArtifactReference> artifacts;

  Map<String, Object?> toJson() => <String, Object?>{
    'eventId': eventId,
    'sequence': sequence,
    'timestamp': timestamp.toIso8601String(),
    'kind': kind,
    'projectId': projectId,
    'workspaceId': workspaceId,
    'runId': runId,
    'caseId': caseId,
    if (attemptId != null) 'attemptId': attemptId,
    if (stepExecutionId != null) 'stepExecutionId': stepExecutionId,
    if (lifecycle != null) 'lifecycle': lifecycle!.name,
    if (outcome != null) 'outcome': outcome!.name,
    if (stability != null) 'stability': stability!.name,
    if (sourceLocation != null) 'sourceLocation': sourceLocation!.toJson(),
    if (targetId != null) 'targetId': targetId,
    if (requestedPlane != null) 'requestedPlane': requestedPlane!.name,
    if (actualPlane != null) 'actualPlane': actualPlane!.name,
    if (driverId != null) 'driverId': driverId,
    if (degradation != null) 'degradation': degradation,
    if (locatorSummary.isNotEmpty) 'locatorSummary': locatorSummary,
    if (failure != null) 'failure': failure!.toJson(),
    if (artifacts.isNotEmpty)
      'artifacts': artifacts.map((artifact) => artifact.toJson()).toList(),
  };

  factory CockpitRunEvent.fromJson(
    Object? value, {
    String path = r'$',
    CockpitDecodePolicy decodePolicy = CockpitDecodePolicy.requests,
  }) {
    final json = CockpitFoundationValueReader.object(value, path);
    CockpitFoundationValueReader.keys(
      json,
      const <String>{
        'eventId',
        'sequence',
        'timestamp',
        'kind',
        'projectId',
        'workspaceId',
        'runId',
        'caseId',
        'attemptId',
        'stepExecutionId',
        'lifecycle',
        'outcome',
        'stability',
        'sourceLocation',
        'targetId',
        'requestedPlane',
        'actualPlane',
        'driverId',
        'degradation',
        'locatorSummary',
        'failure',
        'artifacts',
      },
      path,
      required: const <String>{
        'eventId',
        'sequence',
        'timestamp',
        'kind',
        'projectId',
        'workspaceId',
        'runId',
        'caseId',
      },
      policy: decodePolicy,
    );
    final rawArtifacts = json['artifacts'] == null
        ? const <Object?>[]
        : CockpitFoundationValueReader.list(
            json['artifacts'],
            '$path.artifacts',
          );
    return CockpitRunEvent(
      eventId: CockpitFoundationValueReader.id(
        json['eventId'],
        '$path.eventId',
      ),
      sequence: CockpitFoundationValueReader.integer(
        json['sequence'],
        '$path.sequence',
        min: 1,
      ),
      timestamp: CockpitFoundationValueReader.dateTime(
        json['timestamp'],
        '$path.timestamp',
      ),
      kind: CockpitFoundationValueReader.kind(json['kind'], '$path.kind'),
      projectId: CockpitFoundationValueReader.id(
        json['projectId'],
        '$path.projectId',
      ),
      workspaceId: CockpitFoundationValueReader.id(
        json['workspaceId'],
        '$path.workspaceId',
      ),
      runId: CockpitFoundationValueReader.id(json['runId'], '$path.runId'),
      caseId: CockpitFoundationValueReader.id(json['caseId'], '$path.caseId'),
      attemptId: json['attemptId'] == null
          ? null
          : CockpitFoundationValueReader.id(
              json['attemptId'],
              '$path.attemptId',
            ),
      stepExecutionId: CockpitFoundationValueReader.optionalString(
        json['stepExecutionId'],
        '$path.stepExecutionId',
        maximum: 512,
      ),
      lifecycle: json['lifecycle'] == null
          ? null
          : _enum(
              json['lifecycle'],
              CockpitRunLifecycle.values,
              '$path.lifecycle',
            ),
      outcome: json['outcome'] == null
          ? null
          : _enum(json['outcome'], CockpitRunOutcome.values, '$path.outcome'),
      stability: json['stability'] == null
          ? null
          : _enum(
              json['stability'],
              CockpitRunStability.values,
              '$path.stability',
            ),
      sourceLocation: json['sourceLocation'] == null
          ? null
          : CockpitTestSourceLocation.fromJson(
              json['sourceLocation'],
              path: '$path.sourceLocation',
            ),
      targetId: json['targetId'] == null
          ? null
          : CockpitFoundationValueReader.id(json['targetId'], '$path.targetId'),
      requestedPlane: json['requestedPlane'] == null
          ? null
          : _enum(
              json['requestedPlane'],
              CockpitTestPlane.values,
              '$path.requestedPlane',
            ),
      actualPlane: json['actualPlane'] == null
          ? null
          : _enum(
              json['actualPlane'],
              CockpitTestPlane.values,
              '$path.actualPlane',
            ),
      driverId: json['driverId'] == null
          ? null
          : CockpitFoundationValueReader.id(json['driverId'], '$path.driverId'),
      degradation: CockpitFoundationValueReader.optionalString(
        json['degradation'],
        '$path.degradation',
        maximum: 512,
      ),
      locatorSummary: json['locatorSummary'] == null
          ? const <String, Object?>{}
          : CockpitFoundationValueReader.jsonObject(
              json['locatorSummary'],
              '$path.locatorSummary',
            ),
      failure: json['failure'] == null
          ? null
          : CockpitFailure.fromJson(
              json['failure'],
              path: '$path.failure',
              decodePolicy: decodePolicy,
            ),
      artifacts: <CockpitArtifactReference>[
        for (var index = 0; index < rawArtifacts.length; index += 1)
          CockpitArtifactReference.fromJson(
            rawArtifacts[index],
            path: '$path.artifacts[$index]',
            decodePolicy: decodePolicy,
          ),
      ],
    );
  }

  static void validateSequence(
    Iterable<CockpitRunEvent> events, {
    int afterSequence = 0,
    bool contiguous = true,
  }) {
    ({String projectId, String workspaceId, String runId, String caseId})?
    identity;
    var previous = afterSequence;
    final eventIds = <String>{};
    for (final event in events) {
      final eventIdentity = (
        projectId: event.projectId,
        workspaceId: event.workspaceId,
        runId: event.runId,
        caseId: event.caseId,
      );
      identity ??= eventIdentity;
      if (eventIdentity != identity) {
        throw const FormatException('Event sequence crosses run identity.');
      }
      if (event.sequence <= previous ||
          (contiguous && event.sequence != previous + 1)) {
        throw const FormatException('Event sequence is not monotonic.');
      }
      if (!eventIds.add(event.eventId)) {
        throw FormatException('Duplicate event id ${event.eventId}.');
      }
      previous = event.sequence;
    }
  }
}

final class CockpitEventCursor {
  CockpitEventCursor({this.afterSequence = 0, this.lastEventId}) {
    if (afterSequence < 0) {
      throw const FormatException('afterSequence cannot be negative.');
    }
    if (lastEventId != null) {
      CockpitFoundationValueReader.id(lastEventId, r'$.lastEventId');
    }
  }

  final int afterSequence;
  final String? lastEventId;

  Map<String, Object?> toJson() => <String, Object?>{
    'afterSequence': afterSequence,
    if (lastEventId != null) 'lastEventId': lastEventId,
  };

  factory CockpitEventCursor.fromJson(Object? value, {String path = r'$'}) {
    final json = CockpitFoundationValueReader.object(value, path);
    CockpitFoundationValueReader.keys(
      json,
      const <String>{'afterSequence', 'lastEventId'},
      path,
      required: const <String>{'afterSequence'},
    );
    return CockpitEventCursor(
      afterSequence: CockpitFoundationValueReader.integer(
        json['afterSequence'],
        '$path.afterSequence',
        min: 0,
      ),
      lastEventId: json['lastEventId'] == null
          ? null
          : CockpitFoundationValueReader.id(
              json['lastEventId'],
              '$path.lastEventId',
            ),
    );
  }
}

final class CockpitEventReplayBoundary {
  CockpitEventReplayBoundary({
    required this.requestedAfterSequence,
    required this.earliestAvailableSequence,
    required this.latestAvailableSequence,
  }) {
    if (requestedAfterSequence < 0 ||
        earliestAvailableSequence < 1 ||
        latestAvailableSequence < earliestAvailableSequence) {
      throw const FormatException('Event replay boundary is invalid.');
    }
  }

  final int requestedAfterSequence;
  final int earliestAvailableSequence;
  final int latestAvailableSequence;

  bool get hasGap => requestedAfterSequence + 1 < earliestAvailableSequence;

  Map<String, Object?> toJson() => <String, Object?>{
    'requestedAfterSequence': requestedAfterSequence,
    'earliestAvailableSequence': earliestAvailableSequence,
    'latestAvailableSequence': latestAvailableSequence,
    'hasGap': hasGap,
  };

  factory CockpitEventReplayBoundary.fromJson(
    Object? value, {
    String path = r'$',
    CockpitDecodePolicy decodePolicy = CockpitDecodePolicy.requests,
  }) {
    final json = CockpitFoundationValueReader.object(value, path);
    CockpitFoundationValueReader.keys(
      json,
      const <String>{
        'requestedAfterSequence',
        'earliestAvailableSequence',
        'latestAvailableSequence',
        'hasGap',
      },
      path,
      required: const <String>{
        'requestedAfterSequence',
        'earliestAvailableSequence',
        'latestAvailableSequence',
        'hasGap',
      },
      policy: decodePolicy,
    );
    final result = CockpitEventReplayBoundary(
      requestedAfterSequence: CockpitFoundationValueReader.integer(
        json['requestedAfterSequence'],
        '$path.requestedAfterSequence',
        min: 0,
      ),
      earliestAvailableSequence: CockpitFoundationValueReader.integer(
        json['earliestAvailableSequence'],
        '$path.earliestAvailableSequence',
        min: 1,
      ),
      latestAvailableSequence: CockpitFoundationValueReader.integer(
        json['latestAvailableSequence'],
        '$path.latestAvailableSequence',
        min: 1,
      ),
    );
    if (CockpitFoundationValueReader.boolean(json['hasGap'], '$path.hasGap') !=
        result.hasGap) {
      throw const FormatException('Event replay gap flag is inconsistent.');
    }
    return result;
  }
}

void _validateState(CockpitRunEvent event) {
  if ((event.outcome == null) != (event.stability == null) ||
      (event.lifecycle == CockpitRunLifecycle.completed) !=
          (event.outcome != null)) {
    throw const FormatException(
      'Event lifecycle and outcome are inconsistent.',
    );
  }
  final passed = event.outcome == CockpitRunOutcome.passed;
  if ((event.outcome != null && !passed) != (event.failure != null) ||
      (passed && event.failure != null)) {
    throw const FormatException('Event outcome and failure disagree.');
  }
}

T _enum<T extends Enum>(Object? value, List<T> values, String path) {
  return CockpitEnumValue<T>.parse(
    value,
    values,
    path,
    policy: CockpitDecodePolicy.requests,
  ).requireKnown();
}

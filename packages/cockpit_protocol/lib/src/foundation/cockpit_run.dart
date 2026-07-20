import 'cockpit_api_error.dart';
import 'cockpit_decode_policy.dart';
import 'cockpit_foundation_value_reader.dart';

enum CockpitRunLifecycle { queued, running, completed }

enum CockpitRunOutcome { passed, failed, blocked, cancelled, interrupted }

enum CockpitRunStability { stable, flaky, unknown }

abstract final class CockpitRunStateMachine {
  static bool canTransition(CockpitRunLifecycle from, CockpitRunLifecycle to) {
    if (from == to) {
      return true;
    }
    return switch (from) {
      CockpitRunLifecycle.queued =>
        to == CockpitRunLifecycle.running ||
            to == CockpitRunLifecycle.completed,
      CockpitRunLifecycle.running => to == CockpitRunLifecycle.completed,
      CockpitRunLifecycle.completed => false,
    };
  }
}

final class CockpitRunResource {
  CockpitRunResource({
    required this.projectId,
    required this.workspaceId,
    required this.runId,
    required this.caseId,
    required this.sourceSha256,
    required this.lifecycle,
    required this.submittedAt,
    this.outcome,
    this.stability,
    this.startedAt,
    this.finishedAt,
    Iterable<String> attemptIds = const <String>[],
    this.activeAttemptId,
    this.failure,
  }) : attemptIds = List<String>.unmodifiable(attemptIds) {
    for (final entry in <String, String>{
      'projectId': projectId,
      'workspaceId': workspaceId,
      'runId': runId,
      'caseId': caseId,
    }.entries) {
      CockpitFoundationValueReader.id(entry.value, '\$.${entry.key}');
    }
    CockpitFoundationValueReader.sha256(sourceSha256, r'$.sourceSha256');
    CockpitFoundationValueReader.utcDateTime(submittedAt, r'$.submittedAt');
    if (startedAt != null) {
      CockpitFoundationValueReader.utcDateTime(startedAt!, r'$.startedAt');
    }
    if (finishedAt != null) {
      CockpitFoundationValueReader.utcDateTime(finishedAt!, r'$.finishedAt');
    }
    final attempts = <String>{};
    for (final attemptId in this.attemptIds) {
      CockpitFoundationValueReader.id(attemptId, r'$.attemptIds[]');
      if (!attempts.add(attemptId)) {
        throw FormatException('Duplicate attempt $attemptId.');
      }
    }
    if (activeAttemptId != null && !attempts.contains(activeAttemptId)) {
      throw const FormatException('Active attempt is not in attemptIds.');
    }
    _validateRunState(this);
  }

  final String projectId;
  final String workspaceId;
  final String runId;
  final String caseId;
  final String sourceSha256;
  final CockpitRunLifecycle lifecycle;
  final CockpitRunOutcome? outcome;
  final CockpitRunStability? stability;
  final DateTime submittedAt;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final List<String> attemptIds;
  final String? activeAttemptId;
  final CockpitFailure? failure;

  Map<String, Object?> toJson() => <String, Object?>{
    'projectId': projectId,
    'workspaceId': workspaceId,
    'runId': runId,
    'caseId': caseId,
    'sourceSha256': sourceSha256,
    'lifecycle': lifecycle.name,
    if (outcome != null) 'outcome': outcome!.name,
    if (stability != null) 'stability': stability!.name,
    'submittedAt': submittedAt.toIso8601String(),
    if (startedAt != null) 'startedAt': startedAt!.toIso8601String(),
    if (finishedAt != null) 'finishedAt': finishedAt!.toIso8601String(),
    'attemptIds': attemptIds,
    if (activeAttemptId != null) 'activeAttemptId': activeAttemptId,
    if (failure != null) 'failure': failure!.toJson(),
  };

  factory CockpitRunResource.fromJson(
    Object? value, {
    String path = r'$',
    CockpitDecodePolicy decodePolicy = CockpitDecodePolicy.requests,
  }) {
    final json = CockpitFoundationValueReader.object(value, path);
    CockpitFoundationValueReader.keys(
      json,
      const <String>{
        'projectId',
        'workspaceId',
        'runId',
        'caseId',
        'sourceSha256',
        'lifecycle',
        'outcome',
        'stability',
        'submittedAt',
        'startedAt',
        'finishedAt',
        'attemptIds',
        'activeAttemptId',
        'failure',
      },
      path,
      required: const <String>{
        'projectId',
        'workspaceId',
        'runId',
        'caseId',
        'sourceSha256',
        'lifecycle',
        'submittedAt',
        'attemptIds',
      },
      policy: decodePolicy,
    );
    return CockpitRunResource(
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
      sourceSha256: CockpitFoundationValueReader.sha256(
        json['sourceSha256'],
        '$path.sourceSha256',
      ),
      lifecycle: _enum(
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
      submittedAt: CockpitFoundationValueReader.dateTime(
        json['submittedAt'],
        '$path.submittedAt',
      ),
      startedAt: json['startedAt'] == null
          ? null
          : CockpitFoundationValueReader.dateTime(
              json['startedAt'],
              '$path.startedAt',
            ),
      finishedAt: json['finishedAt'] == null
          ? null
          : CockpitFoundationValueReader.dateTime(
              json['finishedAt'],
              '$path.finishedAt',
            ),
      attemptIds: CockpitFoundationValueReader.ids(
        json['attemptIds'],
        '$path.attemptIds',
      ),
      activeAttemptId: json['activeAttemptId'] == null
          ? null
          : CockpitFoundationValueReader.id(
              json['activeAttemptId'],
              '$path.activeAttemptId',
            ),
      failure: json['failure'] == null
          ? null
          : CockpitFailure.fromJson(
              json['failure'],
              path: '$path.failure',
              decodePolicy: decodePolicy,
            ),
    );
  }
}

final class CockpitRunCaseResource {
  CockpitRunCaseResource({
    required this.runId,
    required this.caseId,
    required this.sourceSha256,
    required Iterable<String> attemptIds,
    this.outcome,
    this.stability,
  }) : attemptIds = List<String>.unmodifiable(attemptIds) {
    CockpitFoundationValueReader.id(runId, r'$.runId');
    CockpitFoundationValueReader.id(caseId, r'$.caseId');
    CockpitFoundationValueReader.sha256(sourceSha256, r'$.sourceSha256');
    CockpitFoundationValueReader.ids(this.attemptIds, r'$.attemptIds');
    if ((outcome == null) != (stability == null)) {
      throw const FormatException('Run case outcome and stability disagree.');
    }
  }

  final String runId;
  final String caseId;
  final String sourceSha256;
  final List<String> attemptIds;
  final CockpitRunOutcome? outcome;
  final CockpitRunStability? stability;

  Map<String, Object?> toJson() => <String, Object?>{
    'runId': runId,
    'caseId': caseId,
    'sourceSha256': sourceSha256,
    'attemptIds': attemptIds,
    if (outcome != null) 'outcome': outcome!.name,
    if (stability != null) 'stability': stability!.name,
  };

  factory CockpitRunCaseResource.fromJson(
    Object? value, {
    String path = r'$',
    CockpitDecodePolicy decodePolicy = CockpitDecodePolicy.requests,
  }) {
    final json = CockpitFoundationValueReader.object(value, path);
    CockpitFoundationValueReader.keys(
      json,
      const <String>{
        'runId',
        'caseId',
        'sourceSha256',
        'attemptIds',
        'outcome',
        'stability',
      },
      path,
      required: const <String>{'runId', 'caseId', 'sourceSha256', 'attemptIds'},
      policy: decodePolicy,
    );
    return CockpitRunCaseResource(
      runId: CockpitFoundationValueReader.id(json['runId'], '$path.runId'),
      caseId: CockpitFoundationValueReader.id(json['caseId'], '$path.caseId'),
      sourceSha256: CockpitFoundationValueReader.sha256(
        json['sourceSha256'],
        '$path.sourceSha256',
      ),
      attemptIds: CockpitFoundationValueReader.ids(
        json['attemptIds'],
        '$path.attemptIds',
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
    );
  }
}

void _validateRunState(CockpitRunResource run) {
  if (run.startedAt != null && run.startedAt!.isBefore(run.submittedAt) ||
      run.finishedAt != null &&
          run.finishedAt!.isBefore(run.startedAt ?? run.submittedAt)) {
    throw const FormatException('Run timestamps are inconsistent.');
  }
  final completed = run.lifecycle == CockpitRunLifecycle.completed;
  if (completed !=
          (run.outcome != null &&
              run.stability != null &&
              run.finishedAt != null) ||
      (!completed &&
          (run.outcome != null ||
              run.stability != null ||
              run.finishedAt != null))) {
    throw const FormatException('Run lifecycle is inconsistent.');
  }
  if (run.lifecycle == CockpitRunLifecycle.queued && run.startedAt != null ||
      run.lifecycle == CockpitRunLifecycle.running && run.startedAt == null ||
      completed && run.activeAttemptId != null) {
    throw const FormatException('Run active state is inconsistent.');
  }
  final passed = run.outcome == CockpitRunOutcome.passed;
  if ((completed && !passed) != (run.failure != null) ||
      (passed && run.failure != null)) {
    throw const FormatException('Run outcome and failure disagree.');
  }
  if (passed && run.attemptIds.isEmpty) {
    throw const FormatException('A passed run requires a completed attempt.');
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

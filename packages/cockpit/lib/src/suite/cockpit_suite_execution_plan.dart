import 'package:cockpit_protocol/cockpit_protocol.dart';

import '../test/cockpit_test_document_compiler.dart';

enum CockpitSuitePlanNodeKind {
  isolation,
  fixtureSetup,
  testCase,
  fixtureTeardown,
}

final class CockpitSuitePlanNode {
  CockpitSuitePlanNode({
    required this.nodeId,
    required this.entryId,
    required this.kind,
    required this.compiledCase,
    required this.inputs,
    required this.matrix,
    required this.targetId,
    required Iterable<String> dependencies,
    required this.retry,
    required this.selected,
    required this.alwaysRun,
    this.isolation,
    this.cleanupGuardNodeId,
    this.caseNodeId,
  }) : dependencies = Set<String>.unmodifiable(dependencies) {
    if (dependencies.contains(nodeId)) {
      throw const FormatException('Suite node cannot depend on itself.');
    }
    if (kind == CockpitSuitePlanNodeKind.testCase && alwaysRun) {
      throw const FormatException('A case node cannot be marked alwaysRun.');
    }
    if ((kind == CockpitSuitePlanNodeKind.isolation) != (isolation != null)) {
      throw const FormatException(
        'Only an isolation node may declare an isolation policy.',
      );
    }
    if ((kind == CockpitSuitePlanNodeKind.fixtureTeardown) !=
        (cleanupGuardNodeId != null)) {
      throw const FormatException(
        'Only a fixture teardown requires a cleanup guard.',
      );
    }
    if (cleanupGuardNodeId != null &&
        !this.dependencies.contains(cleanupGuardNodeId)) {
      throw const FormatException(
        'A fixture teardown must depend on its cleanup guard.',
      );
    }
    if ((kind == CockpitSuitePlanNodeKind.isolation ||
            kind == CockpitSuitePlanNodeKind.testCase) &&
        caseNodeId == null) {
      throw const FormatException(
        'Isolation and case nodes require a case row identity.',
      );
    }
  }

  final String nodeId;
  final String entryId;
  final CockpitSuitePlanNodeKind kind;
  final CockpitCompiledTestCase compiledCase;
  final Map<String, Object?> inputs;
  final Map<String, Object?> matrix;
  final String? targetId;
  final Set<String> dependencies;
  final CockpitTestSuiteRetryPolicy retry;
  final bool selected;
  final bool alwaysRun;
  final CockpitTestSuiteIsolation? isolation;
  final String? cleanupGuardNodeId;
  final String? caseNodeId;

  Map<String, Object?> toJson() => <String, Object?>{
    'nodeId': nodeId,
    'entryId': entryId,
    'kind': kind.name,
    'caseId': compiledCase.testCase.id,
    'sourceSha256': compiledCase.sourceSha256,
    'case': compiledCase.testCase.toJson(),
    'sourceMap': <String, Object?>{
      for (final entry in compiledCase.sourceMap.entries)
        entry.key: entry.value.toJson(),
    },
    'inputs': inputs,
    'matrix': matrix,
    if (targetId != null) 'targetId': targetId,
    'dependencies': dependencies.toList(growable: false)..sort(),
    'retry': retry.toJson(),
    'selected': selected,
    'alwaysRun': alwaysRun,
    if (isolation != null) 'isolation': isolation!.name,
    if (cleanupGuardNodeId != null) 'cleanupGuardNodeId': cleanupGuardNodeId,
    if (caseNodeId != null) 'caseNodeId': caseNodeId,
  };
}

final class CockpitSuiteExecutionPlan {
  CockpitSuiteExecutionPlan({
    required this.suite,
    required this.sourceSha256,
    required Iterable<CockpitSuitePlanNode> nodes,
    Iterable<CockpitSuitePlanNode> attemptNodes =
        const <CockpitSuitePlanNode>[],
  }) : nodes = List<CockpitSuitePlanNode>.unmodifiable(nodes),
       attemptNodes = List<CockpitSuitePlanNode>.unmodifiable(attemptNodes) {
    final allNodes = <CockpitSuitePlanNode>[
      ...this.nodes,
      ...this.attemptNodes,
    ];
    final ids = <String>{};
    for (final node in allNodes) {
      if (!ids.add(node.nodeId)) {
        throw FormatException('Duplicate suite node ${node.nodeId}.');
      }
    }
    final scheduledIds = this.nodes.map((node) => node.nodeId).toSet();
    final caseNodeIds = caseNodes.map((node) => node.nodeId).toSet();
    for (final node in this.nodes) {
      if (node.kind != CockpitSuitePlanNodeKind.testCase &&
          node.caseNodeId != null) {
        throw FormatException(
          'Suite attempt node ${node.nodeId} cannot be scheduled directly.',
        );
      }
      if (node.dependencies.any(
        (dependency) => !scheduledIds.contains(dependency),
      )) {
        throw FormatException(
          'Scheduled suite node ${node.nodeId} has an internal dependency.',
        );
      }
    }
    for (final node in this.attemptNodes) {
      if (node.kind == CockpitSuitePlanNodeKind.testCase ||
          !caseNodeIds.contains(node.caseNodeId)) {
        throw FormatException(
          'Suite attempt node ${node.nodeId} has an invalid case row.',
        );
      }
    }
    for (final node in allNodes) {
      if (node.dependencies.any((dependency) => !ids.contains(dependency))) {
        throw FormatException(
          'Suite node ${node.nodeId} has an unknown dependency.',
        );
      }
    }
    for (final caseNode in caseNodes) {
      final isolationCount = this.attemptNodes
          .where(
            (node) =>
                node.caseNodeId == caseNode.nodeId &&
                node.kind == CockpitSuitePlanNodeKind.isolation,
          )
          .length;
      if (isolationCount != 1) {
        throw FormatException(
          'Suite case row ${caseNode.nodeId} requires one isolation node.',
        );
      }
    }
    _rejectCycles(allNodes);
  }

  final CockpitTestSuite suite;
  final String sourceSha256;
  final List<CockpitSuitePlanNode> nodes;
  final List<CockpitSuitePlanNode> attemptNodes;

  Iterable<CockpitSuitePlanNode> get caseNodes =>
      nodes.where((node) => node.kind == CockpitSuitePlanNodeKind.testCase);

  Iterable<CockpitSuitePlanNode> attemptNodesFor(String caseNodeId) =>
      attemptNodes.where((node) => node.caseNodeId == caseNodeId);

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': 'cockpit.suite-plan/v2',
    'suiteId': suite.id,
    'sourceSha256': sourceSha256,
    'suite': suite.toJson(),
    'nodes': nodes.map((node) => node.toJson()).toList(),
    'attemptNodes': attemptNodes.map((node) => node.toJson()).toList(),
  };

  void _rejectCycles(List<CockpitSuitePlanNode> allNodes) {
    final byId = <String, CockpitSuitePlanNode>{
      for (final node in allNodes) node.nodeId: node,
    };
    final active = <String>{};
    final done = <String>{};
    bool visit(String id) {
      if (done.contains(id)) return false;
      if (!active.add(id)) return true;
      if (byId[id]!.dependencies.any(visit)) return true;
      active.remove(id);
      done.add(id);
      return false;
    }

    if (byId.keys.any(visit)) {
      throw const FormatException('Compiled suite DAG contains a cycle.');
    }
  }
}

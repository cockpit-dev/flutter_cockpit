import 'package:cockpit_protocol/cockpit_protocol.dart';

import '../test/cockpit_test_document_compiler.dart';

enum CockpitSuitePlanNodeKind { fixtureSetup, testCase, fixtureTeardown }

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
  }) : dependencies = Set<String>.unmodifiable(dependencies) {
    if (dependencies.contains(nodeId)) {
      throw const FormatException('Suite node cannot depend on itself.');
    }
    if (kind == CockpitSuitePlanNodeKind.testCase && alwaysRun) {
      throw const FormatException('A case node cannot be marked alwaysRun.');
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
  };
}

final class CockpitSuiteExecutionPlan {
  CockpitSuiteExecutionPlan({
    required this.suite,
    required this.sourceSha256,
    required Iterable<CockpitSuitePlanNode> nodes,
  }) : nodes = List<CockpitSuitePlanNode>.unmodifiable(nodes) {
    final ids = <String>{};
    for (final node in this.nodes) {
      if (!ids.add(node.nodeId)) {
        throw FormatException('Duplicate suite node ${node.nodeId}.');
      }
    }
    for (final node in this.nodes) {
      if (node.dependencies.any((dependency) => !ids.contains(dependency))) {
        throw FormatException(
          'Suite node ${node.nodeId} has an unknown dependency.',
        );
      }
    }
    _rejectCycles();
  }

  final CockpitTestSuite suite;
  final String sourceSha256;
  final List<CockpitSuitePlanNode> nodes;

  Iterable<CockpitSuitePlanNode> get caseNodes =>
      nodes.where((node) => node.kind == CockpitSuitePlanNodeKind.testCase);

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': 'cockpit.suite-plan/v2',
    'suiteId': suite.id,
    'sourceSha256': sourceSha256,
    'suite': suite.toJson(),
    'nodes': nodes.map((node) => node.toJson()).toList(),
  };

  void _rejectCycles() {
    final byId = <String, CockpitSuitePlanNode>{
      for (final node in nodes) node.nodeId: node,
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

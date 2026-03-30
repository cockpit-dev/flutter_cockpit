enum CockpitMcpFeatureCategory {
  all(null),
  workspace(all),
  closedLoop(all, 'closed_loop'),
  sessionManagement(all, 'session_management'),
  inspection(all),
  execution(all),
  delivery(all),
  dependencyIntelligence(workspace, 'dependency_intelligence'),
  workspaceQuality(workspace, 'workspace_quality'),
  projectScaffolding(workspace, 'project_scaffolding'),
  roots(workspace),
  contextResources(workspace, 'context_resources'),
  workflowPrompts(workspace, 'workflow_prompts');

  const CockpitMcpFeatureCategory(this.parent, [this._serializedName]);

  final CockpitMcpFeatureCategory? parent;
  final String? _serializedName;

  String get serializedName => _serializedName ?? name;
}

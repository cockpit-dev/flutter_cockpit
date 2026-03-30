enum CockpitMcpFeatureCategory {
  all(null),
  sessionManagement(all, 'session_management'),
  inspection(all),
  execution(all),
  delivery(all);

  const CockpitMcpFeatureCategory(this.parent, [this._serializedName]);

  final CockpitMcpFeatureCategory? parent;
  final String? _serializedName;

  String get serializedName => _serializedName ?? name;
}

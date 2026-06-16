import 'cockpit_mcp_feature_category.dart';

abstract interface class CockpitMcpFeatureDescriptor {
  String get name;

  List<CockpitMcpFeatureCategory> get categories;

  bool get enabledByDefault;
}

import 'cockpit_mcp_feature_category.dart';
import 'cockpit_mcp_feature_descriptor.dart';

final class CockpitMcpFeatureConfiguration {
  const CockpitMcpFeatureConfiguration({
    this.enabledNames = const <String>{},
    this.disabledNames = const <String>{},
  });

  final Set<String> enabledNames;
  final Set<String> disabledNames;

  bool isEnabled(CockpitMcpFeatureDescriptor definition) {
    if (disabledNames.contains(definition.name)) {
      return false;
    }
    if (enabledNames.contains(definition.name)) {
      return true;
    }

    for (final category in _categoriesInPrecedenceOrder(
      definition.categories,
    )) {
      final categoryName = category.serializedName;
      if (disabledNames.contains(categoryName)) {
        return false;
      }
      if (enabledNames.contains(categoryName)) {
        return true;
      }
    }

    return definition.enabledByDefault;
  }

  Iterable<CockpitMcpFeatureCategory> _categoriesInPrecedenceOrder(
    List<CockpitMcpFeatureCategory> categories,
  ) sync* {
    final seen = <CockpitMcpFeatureCategory>{...categories};
    final queue = <CockpitMcpFeatureCategory>[];

    void insert(CockpitMcpFeatureCategory category) {
      final priority = _distanceToTop(category);
      for (var index = 0; index < queue.length; index++) {
        final item = queue[index];
        if (_distanceToTop(item) < priority) {
          queue.insert(index, category);
          return;
        }
      }
      queue.add(category);
    }

    categories.forEach(insert);
    while (queue.isNotEmpty) {
      final category = queue.removeAt(0);
      yield category;
      final parent = category.parent;
      if (parent != null && seen.add(parent)) {
        insert(parent);
      }
    }
  }

  int _distanceToTop(CockpitMcpFeatureCategory category) {
    var result = 0;
    var parent = category.parent;
    while (parent != null) {
      result++;
      parent = parent.parent;
    }
    return result;
  }
}

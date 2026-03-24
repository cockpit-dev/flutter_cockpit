import 'package:flutter/foundation.dart';

enum TodoThemePreference { system, light, dark }

enum TodoSortMode { manual, dueDate, priority, updatedAt }

@immutable
final class TodoSettings {
  const TodoSettings({
    required this.themePreference,
    required this.sortMode,
    required this.showCompletedInInbox,
    required this.compactMode,
  });

  static const TodoSettings defaults = TodoSettings(
    themePreference: TodoThemePreference.light,
    sortMode: TodoSortMode.manual,
    showCompletedInInbox: true,
    compactMode: false,
  );

  final TodoThemePreference themePreference;
  final TodoSortMode sortMode;
  final bool showCompletedInInbox;
  final bool compactMode;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is TodoSettings &&
            other.themePreference == themePreference &&
            other.sortMode == sortMode &&
            other.showCompletedInInbox == showCompletedInInbox &&
            other.compactMode == compactMode;
  }

  @override
  int get hashCode =>
      Object.hash(themePreference, sortMode, showCompletedInInbox, compactMode);
}

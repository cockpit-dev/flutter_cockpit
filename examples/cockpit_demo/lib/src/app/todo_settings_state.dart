import 'package:flutter/foundation.dart';

import '../model/todo_settings.dart';

@immutable
final class TodoSettingsState {
  const TodoSettingsState({
    this.settings = TodoSettings.defaults,
    this.isSaving = false,
    this.errorMessage,
  });

  final TodoSettings settings;
  final bool isSaving;
  final String? errorMessage;

  TodoSettingsState copyWith({
    TodoSettings? settings,
    bool? isSaving,
    ValueGetter<String?>? errorMessage,
  }) {
    return TodoSettingsState(
      settings: settings ?? this.settings,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: errorMessage == null ? this.errorMessage : errorMessage(),
    );
  }
}

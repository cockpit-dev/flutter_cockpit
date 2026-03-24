import 'package:flutter/material.dart';

import '../theme/orbit_todo_theme.dart';

final class TaskFilterBar extends StatelessWidget {
  const TaskFilterBar({
    required this.searchController,
    required this.highPriorityOnly,
    required this.onSearchChanged,
    required this.onHighPriorityChanged,
    super.key,
  });

  final TextEditingController searchController;
  final bool highPriorityOnly;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<bool> onHighPriorityChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final narrow = MediaQuery.sizeOf(context).width < 560;

    final controls = <Widget>[
      ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: 52,
          maxWidth: narrow ? double.infinity : 340,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: colorScheme.outlineVariant.withAlphaFraction(0.92),
              ),
            ),
          ),
          child: Row(
            children: <Widget>[
              Icon(
                Icons.search_rounded,
                size: 18,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  key: const ValueKey<String>('task-search-input'),
                  controller: searchController,
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    hintText: 'Search title or notes',
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                  onChanged: onSearchChanged,
                ),
              ),
            ],
          ),
        ),
      ),
      _PriorityToggle(
        key: const ValueKey<String>('filter-priority-high'),
        selected: highPriorityOnly,
        label: 'High priority only',
        onPressed: () => onHighPriorityChanged(!highPriorityOnly),
      ),
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant.withAlphaFraction(0.88),
          ),
          bottom: BorderSide(
            color: colorScheme.outlineVariant.withAlphaFraction(0.88),
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: narrow
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Filters',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...controls.expand(
                    (widget) => <Widget>[widget, const SizedBox(height: 10)],
                  ),
                ],
              )
            : Row(
                children: <Widget>[
                  Text(
                    'Filters',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(child: controls.first),
                  const SizedBox(width: 12),
                  controls.last,
                ],
              ),
      ),
    );
  }
}

final class _PriorityToggle extends StatelessWidget {
  const _PriorityToggle({
    required this.selected,
    required this.label,
    required this.onPressed,
    super.key,
  });

  final bool selected;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(
        Icons.priority_high_rounded,
        size: 18,
        color: selected ? colorScheme.primary : colorScheme.onSurfaceVariant,
      ),
      label: Text(label),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 10),
        foregroundColor:
            selected ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
        shape: const RoundedRectangleBorder(),
      ),
    );
  }
}

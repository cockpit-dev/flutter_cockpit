import 'package:flutter/material.dart';

import '../../model/todo_tag.dart';
import '../theme/orbit_todo_theme.dart';

final class TaskFilterBar extends StatelessWidget {
  const TaskFilterBar({
    required this.searchController,
    required this.highPriorityOnly,
    required this.conflictsOnly,
    required this.availableTags,
    required this.selectedTagIds,
    required this.onSearchChanged,
    required this.onHighPriorityChanged,
    required this.onConflictsOnlyChanged,
    required this.onTagToggle,
    required this.onClearTagSelection,
    super.key,
  });

  final TextEditingController searchController;
  final bool highPriorityOnly;
  final bool conflictsOnly;
  final List<TodoTag> availableTags;
  final Set<String> selectedTagIds;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<bool> onHighPriorityChanged;
  final ValueChanged<bool> onConflictsOnlyChanged;
  final ValueChanged<String> onTagToggle;
  final VoidCallback onClearTagSelection;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final narrow = MediaQuery.sizeOf(context).width < 560;
    final hasTags = availableTags.isNotEmpty;

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
        selected: highPriorityOnly,
        label: 'High priority only',
        onPressed: () => onHighPriorityChanged(!highPriorityOnly),
      ),
      _PriorityToggle(
        selected: conflictsOnly,
        label: 'Conflicts only',
        onPressed: () => onConflictsOnlyChanged(!conflictsOnly),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (narrow)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _FilterSectionLabel(colorScheme: colorScheme),
                  const SizedBox(height: 12),
                  ...controls.expand(
                    (widget) => <Widget>[widget, const SizedBox(height: 10)],
                  ),
                ],
              )
            else
              Row(
                children: <Widget>[
                  _FilterSectionLabel(colorScheme: colorScheme),
                  const SizedBox(width: 18),
                  Expanded(child: controls.first),
                  const SizedBox(width: 12),
                  Wrap(
                    spacing: 12,
                    children: controls.skip(1).toList(growable: false),
                  ),
                ],
              ),
            if (hasTags) ...<Widget>[
              const SizedBox(height: 14),
              Text(
                'Tags',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  FilterChip(
                    label: const Text('Any tag'),
                    selected: selectedTagIds.isEmpty,
                    onSelected: (_) => onClearTagSelection(),
                  ),
                  ...availableTags.map(
                    (tag) => FilterChip(
                      selected: selectedTagIds.contains(tag.id),
                      label: Text(tag.name),
                      onSelected: (_) => onTagToggle(tag.id),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

final class _FilterSectionLabel extends StatelessWidget {
  const _FilterSectionLabel({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      'Filters',
      style: theme.textTheme.labelMedium?.copyWith(
        color: colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.1,
      ),
    );
  }
}

final class _PriorityToggle extends StatelessWidget {
  const _PriorityToggle({
    required this.selected,
    required this.label,
    required this.onPressed,
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

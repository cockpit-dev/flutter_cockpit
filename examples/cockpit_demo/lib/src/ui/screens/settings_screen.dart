import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app/todo_app_service.dart';
import '../../app/todo_sync_state.dart';
import '../../model/todo_settings.dart';
import '../theme/orbit_todo_theme.dart';
import '../widgets/editorial_section.dart';

final class SettingsScreen extends StatefulWidget {
  const SettingsScreen({required this.service, super.key});

  final TodoAppService service;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

final class _SettingsScreenState extends State<SettingsScreen> {
  late TodoThemePreference _themePreference;
  late TodoSortMode _sortMode;
  late bool _showCompletedInInbox;
  late bool _compactMode;

  @override
  void initState() {
    super.initState();
    final settings = widget.service.settingsState.settings;
    _themePreference = settings.themePreference;
    _sortMode = settings.sortMode;
    _showCompletedInInbox = settings.showCompletedInInbox;
    _compactMode = settings.compactMode;
  }

  Future<void> _save() async {
    final settings = TodoSettings(
      themePreference: _themePreference,
      sortMode: _sortMode,
      showCompletedInInbox: _showCompletedInInbox,
      compactMode: _compactMode,
    );
    await widget.service.updateSettings(settings);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _emitDebugLog() {
    debugPrint(
      'cockpit_demo diagnostics: sync log probe emitted from settings',
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Debug log emitted to runtime diagnostics.'),
      ),
    );
  }

  void _emitRuntimeError() {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: StateError(
          'cockpit_demo diagnostics: runtime probe emitted from settings',
        ),
        stack: StackTrace.current,
        library: 'cockpit_demo diagnostics',
        context: ErrorDescription(
          'while emitting a runtime probe from Settings',
        ),
      ),
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Runtime error probe recorded.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.service,
      builder: (context, _) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        final syncState = widget.service.syncState;
        final canResetSyncState =
            !syncState.isChecking &&
            (syncState.status != TodoSyncStatus.idle ||
                syncState.hasSuccessfulCheck ||
                syncState.endpoint != null ||
                syncState.checkedAt != null);
        return Scaffold(
          appBar: AppBar(title: const Text('Settings')),
          body: DecoratedBox(
            decoration: BoxDecoration(color: theme.scaffoldBackgroundColor),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
              children: <Widget>[
                EditorialSection(
                  padding: const EdgeInsets.fromLTRB(18, 26, 18, 26),
                  backgroundColor: theme.editorialMutedSurfaceColor,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'SETTINGS',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Tune the workspace.',
                        style: theme.textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'These preferences control list density, task ordering, and visual mode so recordings and daily use stay consistent.',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                EditorialSection(
                  padding: const EdgeInsets.fromLTRB(18, 22, 18, 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'APPEARANCE',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          letterSpacing: 0.95,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text('Appearance', style: theme.textTheme.headlineSmall),
                      const SizedBox(height: 6),
                      Text(
                        'Choose the visual mode and reading density used across the workspace.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text('Theme', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 10),
                      Column(
                        children: <Widget>[
                          _ThemeModeOptionTile(
                            label: 'Follow system',
                            selected:
                                _themePreference == TodoThemePreference.system,
                            onTap: () {
                              setState(() {
                                _themePreference = TodoThemePreference.system;
                              });
                            },
                          ),
                          _ThemeModeOptionTile(
                            label: 'Light',
                            selected:
                                _themePreference == TodoThemePreference.light,
                            onTap: () {
                              setState(() {
                                _themePreference = TodoThemePreference.light;
                              });
                            },
                          ),
                          _ThemeModeOptionTile(
                            label: 'Dark',
                            selected:
                                _themePreference == TodoThemePreference.dark,
                            onTap: () {
                              setState(() {
                                _themePreference = TodoThemePreference.dark;
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                EditorialSection(
                  padding: const EdgeInsets.fromLTRB(18, 22, 18, 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'WORKFLOW',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          letterSpacing: 0.95,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Workflow defaults',
                        style: theme.textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Set the default sort order and whether completed work stays visible in the main queue.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 18),
                      DropdownButtonFormField<TodoSortMode>(
                        // ignore: deprecated_member_use
                        value: _sortMode,
                        decoration: const InputDecoration(
                          labelText: 'Sort tasks',
                        ),
                        items: TodoSortMode.values
                            .map(
                              (mode) => DropdownMenuItem<TodoSortMode>(
                                value: mode,
                                child: Text(mode.name),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _sortMode = value;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 18),
                      _SettingsToggleRow(
                        title: 'Keep completed tasks visible in Inbox',
                        value: _showCompletedInInbox,
                        onChanged: (value) {
                          setState(() {
                            _showCompletedInInbox = value;
                          });
                        },
                      ),
                      _SettingsToggleRow(
                        title: 'Use compact task rows',
                        value: _compactMode,
                        onChanged: (value) {
                          setState(() {
                            _compactMode = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                EditorialSection(
                  padding: const EdgeInsets.fromLTRB(18, 22, 18, 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'DELIVERY',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          letterSpacing: 0.95,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Storage and delivery',
                        style: theme.textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'This example stores work locally and keeps delivery artifacts reviewable before any future sync or external handoff.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text('Sync relay', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          Widget buildSyncSummary() {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  syncState.headline,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  syncState.detail,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    height: 1.45,
                                  ),
                                ),
                                if (syncState.endpoint case final endpoint?)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      'Endpoint · $endpoint${syncState.statusCode == null ? '' : ' · HTTP ${syncState.statusCode}'}',
                                      style: theme.textTheme.labelMedium
                                          ?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.4,
                                          ),
                                    ),
                                  ),
                                if (syncState.hasSuccessfulCheck)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 12),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Text(
                                          'Last successful check',
                                          style: theme.textTheme.labelMedium
                                              ?.copyWith(
                                                color: colorScheme
                                                    .onSurfaceVariant,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 0.4,
                                              ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          syncState.lastHealthySummary!,
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                                color: colorScheme
                                                    .onSurfaceVariant,
                                                height: 1.45,
                                              ),
                                        ),
                                        if (syncState.lastHealthyEndpoint
                                            case final endpoint?)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 4,
                                            ),
                                            child: Text(
                                              'Endpoint · $endpoint${syncState.lastHealthyStatusCode == null ? '' : ' · HTTP ${syncState.lastHealthyStatusCode}'}',
                                              style: theme.textTheme.labelMedium
                                                  ?.copyWith(
                                                    color: colorScheme
                                                        .onSurfaceVariant,
                                                    fontWeight: FontWeight.w700,
                                                    letterSpacing: 0.4,
                                                  ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                              ],
                            );
                          }

                          Widget buildSyncActions() {
                            return Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: <Widget>[
                                FilledButton.tonal(
                                  onPressed:
                                      syncState.status == TodoSyncStatus.syncing
                                      ? null
                                      : widget.service.runSyncNow,
                                  child: const Text('Run queued sync'),
                                ),
                                FilledButton.tonal(
                                  onPressed: syncState.isChecking
                                      ? null
                                      : widget.service.runSyncHealthCheck,
                                  child: Text(syncState.actionLabel),
                                ),
                              ],
                            );
                          }

                          if (constraints.maxWidth < 520) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                buildSyncSummary(),
                                const SizedBox(height: 16),
                                buildSyncActions(),
                              ],
                            );
                          }

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Expanded(child: buildSyncSummary()),
                              const SizedBox(width: 16),
                              Flexible(
                                child: Align(
                                  alignment: Alignment.topRight,
                                  child: buildSyncActions(),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      if (canResetSyncState) ...<Widget>[
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: widget.service.resetSyncRelayState,
                            child: const Text('Reset relay state'),
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      _SettingsToggleRow(
                        title: 'Simulate relay outage',
                        value: syncState.simulateFailure,
                        onChanged: widget.service.setSimulateRelayFailure,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Use this to validate failure recovery before wiring the example to any real upstream sync service.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 18),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(
                              color: colorScheme.outlineVariant
                                  .withAlphaFraction(0.82),
                            ),
                          ),
                        ),
                        child: Column(
                          children: const <Widget>[
                            _SettingsLedgerRow(
                              title: 'Local-first storage',
                              message:
                                  'Tasks and settings stay available offline before any future sync layer is introduced.',
                            ),
                            _SettingsLedgerRow(
                              title: 'Acceptance bundles',
                              message:
                                  'Screenshots, recordings, and diagnostics stay reviewable before any external handoff.',
                            ),
                            _SettingsLedgerRow(
                              title: 'Recovery workflow',
                              message:
                                  'Undo recent deletions, reopen completed items, and keep notes available during validation and handoff.',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (kDebugMode) ...<Widget>[
                  const SizedBox(height: 24),
                  EditorialSection(
                    padding: const EdgeInsets.fromLTRB(18, 22, 18, 22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'DIAGNOSTICS',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            letterSpacing: 0.95,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Runtime probes',
                          style: theme.textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'These controls exist only in debug builds so the framework can validate runtime logs and framework errors on real simulators.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: FilledButton.tonal(
                                onPressed: _emitDebugLog,
                                child: const Text('Emit debug log'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton.tonal(
                                onPressed: _emitRuntimeError,
                                child: const Text('Trigger runtime error'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save settings'),
              ),
            ),
          ),
        );
      },
    );
  }
}

final class _SettingsLedgerRow extends StatelessWidget {
  const _SettingsLedgerRow({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            flex: 3,
            child: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            flex: 5,
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

final class _ThemeModeOptionTile extends StatelessWidget {
  const _ThemeModeOptionTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(
              color: selected
                  ? colorScheme.primary
                  : colorScheme.outlineVariant.withAlphaFraction(0.82),
            ),
            color: selected
                ? colorScheme.primary.withAlphaFraction(0.08)
                : colorScheme.surface,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: <Widget>[
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOutCubic,
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected
                          ? colorScheme.primary
                          : colorScheme.outlineVariant,
                      width: 2,
                    ),
                  ),
                  child: selected
                      ? Center(
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: colorScheme.primary,
                            ),
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 14),
                Text(label, style: theme.textTheme.titleMedium),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

final class _SettingsToggleRow extends StatelessWidget {
  const _SettingsToggleRow({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => onChanged(!value),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(
              color: colorScheme.outlineVariant.withAlphaFraction(0.82),
            ),
            color: colorScheme.surface,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(title, style: theme.textTheme.titleMedium),
                ),
                IgnorePointer(
                  child: Switch(value: value, onChanged: (_) {}),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

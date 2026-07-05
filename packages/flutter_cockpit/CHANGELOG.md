# Changelog

## 1.1.4

- Updated published package metadata and documentation for the 1.1.4 host tooling release.

## 1.1.3

- Re-exported shared AI control, evidence, recording, and runtime protocol models from the pure Dart `flutter_cockpit_protocol` package so host tooling can run without a Flutter SDK dependency.

## 1.1.0

- Added shared Flutter launch configuration support for `--dart-define`, `--dart-define-from-file`, extra Flutter arguments, and process-scoped environment values across CLI, MCP, development sessions, remote sessions, workflow scripts, and platform launchers.
- Added centralized internal remote-control dart define generation so cockpit-owned launch flags stay consistent across platforms and cannot be accidentally overridden by user-provided raw Flutter arguments.
- Improved AI-first runtime evidence flows through app, native, system, host, and recording planes while preserving low-intrusion `cockpit/` entrypoint integration.
- Improved task and recording artifact traceability with step-attached screenshots, recording evidence metadata, and chronological artifact naming.

## 1.0.0

- Initial public release of the in-app runtime layer for `flutter_cockpit`
- Added low-intrusion root bootstrap and Flutter-native target discovery
- Added in-app control, gesture, wait/assert, capture, and recording primitives
- Added native acceptance capture and recording across Android, iOS, macOS, Windows, and Linux, with capability-truthful web rejection
- Added rich runtime snapshots, network observation, and runtime event observation
- Added remote session server, a WebSocket bridge client for web, and shared bundle/domain models
- Added sortable, readable artifact naming helpers for screenshots, diagnostics, and task-run bundles
- Added `waitFor` absent mode (`parameters.absent: true`) so flows can wait for spinners, dialogs, or routes to disappear
- Added `dismissKeyboard` command and focus-state snapshots (`snapshot.focus`) reporting the focused widget and whether text input is active
- Added direct activation for Radio/RadioListTile and the real tristate Checkbox cycle, with occlusion-safe multi-touch validation and pointer-cancel cleanup
- Added release-build semantics resolution through the live SemanticsOwner tree so the semantic plane stays truthful outside debug builds
- Defaulted `CockpitInteractionPolicy.hitTestMissPolicy` to `fail` so taps that miss their target surface as errors instead of silently passing as no-ops
- Fixed screenshot-only acceptance bundles so video evidence gates are satisfied when recording was not requested, while real recording failures still surface explicitly
- Guarded Android window PixelCopy capture behind API 26 so older devices report `captureUnavailable` instead of crashing

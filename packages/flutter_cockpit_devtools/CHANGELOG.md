# Changelog

## 1.0.0

- Initial public release of the host-side tooling layer for `flutter_cockpit`
- Added CLI and MCP entrypoints for session bootstrap, control execution, snapshot collection, orchestration, and validation
- Added task-run bundle writing, summary shaping, and delivery evidence handling
- Added `read-task-bundle-summary` CLI output for low-token bundle review alongside MCP `read_task_bundle_summary`
- Added AI-readable default stdout rendering with JSON/path/file output formats for shell-friendly workflows
- Added sortable task-run bundle names, screenshot names, and recording keyframe paths for chronological artifact review
- Added host-side screenshot and recording adapters with validation and keyframe extraction
- Added remote session launchers for Android emulators and iOS Simulators

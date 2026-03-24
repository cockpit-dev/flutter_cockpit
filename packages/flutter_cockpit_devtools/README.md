# flutter_cockpit_devtools

[简体中文](README.zh-CN.md)

`flutter_cockpit_devtools` is the host-side companion package for `flutter_cockpit`.

It turns app-side runtime instrumentation into AI-consumable workflows:

- CLI commands for launch, query, run, snapshot collection, task orchestration, and validation
- MCP tools for AI-native access to the same workflows
- task-run bundle writing and summary reading
- host-side screenshot and recording adapters for Android emulators, iOS Simulators, and local macOS, Windows, and Linux desktop runs
- artifact validation, including screenshot, recording, and keyframe coverage checks

## Installation

Add it to the host package's `dev_dependencies`.

From pub:

```yaml
dev_dependencies:
  flutter_cockpit_devtools: any
```

Or directly from Git:

```yaml
dev_dependencies:
  flutter_cockpit_devtools:
    git:
      url: https://github.com/cockpit-dev/flutter_cockpit.git
      path: packages/flutter_cockpit_devtools
```

## CLI entrypoints

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools run-task --help
dart run flutter_cockpit_devtools:flutter_cockpit_devtools validate-task --help
dart run flutter_cockpit_devtools:flutter_cockpit_mcp
```

## What this package contains

- shared application services used by both CLI and MCP
- task orchestration and delivery validation
- bundle summary shaping for AI consumption, including acceptance-facing semantic evidence so later AI steps can compare the final UI state directly
- host-side capture and recording strategy resolution
- remote session client and bootstrap launchers

The in-app runtime layer lives in the companion package `flutter_cockpit`.

See the repository root README for the full workflow and current supported platforms.

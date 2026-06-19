# Flutter Cockpit

Use this power when a Flutter or host-control task needs live UI, route, screenshot, recording, native/system action, or validation evidence.

## Bundled Assets

- `mcp.json` exposes `flutter-cockpit -> dart run cockpit serve-mcp`.
- `skills/flutter-cockpit/SKILL.md` carries the complete AI-first workflow.

## Fast Loop

Use the smallest live proof that answers the task:

```bash
dart run cockpit list-targets
dart run cockpit launch-app --project-dir <dir> --platform <platform> --device-id <id>
dart run cockpit read-app --profile minimal
dart run cockpit hot-reload
dart run cockpit read-errors --max-errors 10
dart run cockpit capture-screenshot --name acceptance --profile inspect
```

For native or system surfaces, read capabilities first:

```bash
dart run cockpit read-system-capabilities
dart run cockpit run-system-action --action <available-action>
```

Do not treat command success as product proof. Compare baseline state, post-action state, errors, and evidence before claiming completion.

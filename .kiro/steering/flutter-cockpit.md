# Flutter Cockpit

Use this steering note when a Flutter or host-control task needs live UI, route, screenshot, recording, or validation evidence.

Read `skills/flutter-cockpit/SKILL.md` before controlling an app or claiming validation.

Fast path:

```bash
dart run cockpit list-targets
dart run cockpit launch-app --project-dir <dir> --platform <platform> --device-id <id>
dart run cockpit read-app --profile minimal
dart run cockpit hot-reload
dart run cockpit capture-screenshot --name acceptance --profile inspect
```

Prefer the smallest live evidence that answers the task. Use `dart run cockpit serve-mcp` when the agent supports MCP.

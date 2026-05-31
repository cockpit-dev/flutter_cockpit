# Runtime Validation Example

Use this pattern when the task needs live app evidence.

## Recommended Flow

1. `launch-app`
2. `read-app --profile minimal`
3. `run-command` or `run-batch`
4. `inspect-ui`, `read-network`, `read-errors`, `read-logs`, or `wait-idle` only when needed
5. `hot-reload` or `hot-restart` during active development
6. repeat until correct

When the task is not purely Flutter UI, switch to:

1. `launch-target`
2. `read-target --profile minimal`
3. `inspect-surface` or `run-shell`
4. CLI `read-task-bundle-summary`, MCP `read_task_bundle_summary`, or `validate-task`

Use `run-shell` only when the resolved target truthfully exposes shell control. Browser targets stay `read-target` and `inspect-surface` first; any browser prerequisite checks should use host shell scope instead of a browser device shell.

Target-first example:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  launch-target \
  --project-dir <project-dir> \
  --platform <platform> \
  --device-id <device-id> \
  --target-json /tmp/flutter_cockpit/target.json
```

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  read-target \
  --target-json /tmp/flutter_cockpit/target.json \
  --profile minimal
```

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  inspect-surface \
  --target-json /tmp/flutter_cockpit/target.json \
  --profile inspect
```

## Example

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  launch-app \
  --project-dir <project-dir> \
  --platform <platform> \
  --device-id <device-id> \
  --app-json /tmp/flutter_cockpit/app.json
```

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  read-app \
  --app-json /tmp/flutter_cockpit/app.json \
  --profile minimal
```

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  run-command \
  --app-json /tmp/flutter_cockpit/app.json \
  --command-json '{"commandId":"assert-ready","commandType":"assertText","parameters":{"text":"<expected-text>"}}'
```

During active feature work, prefer a project-owned rapid verifier over a full
release sweep. It should launch the app, drive one representative user flow,
hot reload, assert the changed state, capture one still artifact when useful,
read runtime errors, and keep the app alive while more edits are likely. Stop
only for cleanup, a user request, a stuck supervisor, a failed hot restart, or a
clean rebuild/relaunch. Its JSON should stay compact enough for an agent to
read first after every failure.

For release-grade coverage, run the heavier verifier only after the feature is
ready to claim. That verifier should add the expensive surfaces: recordings,
hot restart, network and log reads, target-first inspection, multi-platform
coverage, and acceptance/delivery gates.

Make recording platform-aware in any verifier: desktop and physical device
recording often depend on remote or host adapters, browser recording depends on
host permission, simulators usually have simulator-native capture, and Android
emulators usually use device tooling. Blocked host permissions should be
reported as structured environment warnings when the app-control path is still
valid.

## Expected Agent Behavior

- keep `app.json`
- keep the app alive across edit loops unless cleanup or recovery requires `stop-app`
- let `launch-app` auto-detect `cockpit/main.dart` before spelling out a target
- start with the smallest useful profile
- do not trust command success without a follow-up read
- if the workflow used target-first control, inspect `targetKind`, `primaryExecutionPlane`, `planesUsed`, and `fallbackCount` before claiming success
- for network questions, prefer `run-command` -> `wait-idle` -> `read-network`
- prefer app-centric `read-logs` before tailing host-supervisor logs
- prefer `read-network` over full UI snapshots when the missing fact is about requests, failures, or endpoint coverage
- treat `read-logs` with `available=true` and empty `lines` as “no app logs emitted”, not as an automatic failure
- use `blocked_by_environment` when the app never becomes reachable

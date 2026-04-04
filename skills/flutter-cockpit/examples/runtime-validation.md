# Runtime Validation Example

Use this pattern when the task needs live app evidence.

## Recommended Flow

1. `launch-app`
2. `read-app --profile minimal`
3. `run-command` or `run-batch`
4. `inspect-ui`, `read-network`, `read-errors`, `read-logs`, or `wait-idle` only when needed
5. `hot-reload` or `hot-restart` during active development
6. repeat until correct

## Example

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  launch-app \
  --project-dir examples/cockpit_demo \
  --platform macos \
  --device-id macos \
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
  --command-json '{"commandId":"assert-inbox","commandType":"assertText","parameters":{"text":"Inbox"}}'
```

## Expected Agent Behavior

- keep `app.json`
- let `launch-app` auto-detect `cockpit/main.dart` before spelling out a target
- start with the smallest useful profile
- do not trust command success without a follow-up read
- for network questions, prefer `run-command` -> `wait-idle` -> `read-network`
- prefer app-centric `read-logs` before tailing host-supervisor logs
- prefer `read-network` over full UI snapshots when the missing fact is about requests, failures, or endpoint coverage
- treat `read-logs` with `available=true` and empty `lines` as “no app logs emitted”, not as an automatic failure
- use `blocked_by_environment` when the app never becomes reachable

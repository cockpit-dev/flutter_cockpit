# Rapid Dev Loop

Use this pattern when the goal is fast implementation plus fast runtime verification, not final acceptance delivery on every step.

## Core Rule

Keep each cycle small:

1. make one code change
2. reload only what is needed
3. check one missing fact
4. repeat until behavior is correct
5. run delivery-grade validation only when the feature is ready to claim

## Fastest Useful Loop

1. `launch-app`
2. `read-app --profile minimal`
3. edit code
4. `hot-reload`
5. `run-command` for one action or assertion
6. `read-app --profile minimal` or `inspect-ui --profile inspect` only if the result is still ambiguous

## Code-Side Shortcuts

- Use `analyze_files` before `analyze_workspace` when the change is local.
- Use `lsp` for hover, definition, signature help, or symbols instead of opening large files blindly.
- Use `pub` for bounded dependency edits.
- Use `pub_dev_search` before adding a package you do not know well.

## Runtime Escalation Rules

- Start with `minimal` when you only need route, app reachability, or a tiny state check.
- Use `standard` when you need a small UI summary after an action.
- Use `inspect` when a locator is ambiguous, scrolling failed, or the UI changed in an unexpected way.
- Use `read-network` when the missing fact is request traffic, endpoint coverage, or recent network failures.
- For network questions, prefer `run-command` -> `wait-idle` -> `read-network` over a large snapshot read.
- Use `evidence` only for final proof, hard bugs, or artifact-heavy diagnosis.

## Command Strategy

- Prefer one `run-command` per decision point.
- Use `run-batch` only for short deterministic sequences that do not need mid-step reasoning.
- Prefer `read-network` over `inspect-ui` when the uncertainty is purely about HTTP traffic.
- Prefer locator combinations like `key + text + ancestor.route` over long brittle paths.
- Use fuzzy `path` only when semantic signals are insufficient.
- Add `fallbacks` when the same intent can be reached through 2-3 stable signals.

## Timeout Strategy

- Keep default timeouts unless the step is known to be slow.
- Raise `timeout_ms` for long scrolls, waits, or slow environment transitions.
- Raise `timeout_seconds` for `pub`, `analyze_files`, `run_tests`, or project creation only when needed.
- If a command times out, inspect whether the environment is blocked before retrying with a larger budget.

## Verification Ladder

- During development: `run-command` -> `read-app`
- Before claiming a fix: `inspect-ui` or `read-errors` if needed
- Before claiming delivery readiness: `run-script`, `run-task`, or `validate-task`

Do not pay delivery-grade cost on every edit. Do pay it before any user-facing completion claim.

## Example

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  launch-app \
  --project-dir examples/cockpit_demo \
  --platform macos \
  --app-json /tmp/flutter_cockpit/app.json
```

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  hot-reload \
  --app-json /tmp/flutter_cockpit/app.json
```

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  run-command \
  --app-json /tmp/flutter_cockpit/app.json \
  --profile standard \
  --command-json '{"command_id":"open-today","command_type":"tap","locator":{"text":"Today","key":"nav-today","ancestor":{"route":"/inbox"}}}'
```

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  read-app \
  --app-json /tmp/flutter_cockpit/app.json \
  --profile minimal
```

## Expected Agent Behavior

- keep `app.json` and reuse it instead of relaunching
- prefer hot reload over restart when state preservation helps
- ask for one missing fact per cycle
- avoid reading full snapshots unless the smaller profile failed to answer the question
- avoid bundle generation until the feature is ready for a completion claim

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

## Target-First Quick Loop

Use this branch when the target is not purely a Flutter app handle:

1. `launch-target`
2. `read-target --profile minimal`
3. one bounded edit or one bounded external action
4. `inspect-surface --profile inspect` only when the target summary is still ambiguous
5. `run-shell` only when the resolved platform truthfully exposes shell control

For desktop Flutter targets, prefer semantic inspection when the remote path is reachable. Fall back to native/window evidence only when that semantic path is unavailable.

## Code-Side Shortcuts

- Use `analyze_files` before `analyze_workspace` when the change is local.
- Use `lsp` for hover, definition, signature help, or symbols instead of opening large files blindly.
- Use `grep-package-uris` before `read-package-uris` when you only know the symbol, string, or API fragment inside a dependency.
- Use `pub` for bounded dependency edits.
- Use `pub_dev_search` before adding a package you do not know well.
- Keep command JSON in files when it grows beyond a few lines.

## Runtime Escalation Rules

- Start with `minimal` when you only need route, app reachability, or a tiny state check.
- Use `standard` when you need a small UI summary after an action.
- `read-app --profile standard` gives counts and `textPreviews`, not a full locator inventory. Escalate to `inspect-ui` only when text, tooltip, semantic IDs, or path clues are still insufficient.
- Use `inspect` when a locator is ambiguous, scrolling failed, or the UI changed in an unexpected way.
- Use `read-network` when the missing fact is request traffic, endpoint coverage, or recent network failures.
- For network questions, prefer `run-command` -> `wait-idle` -> `read-network` over a large snapshot read.
- Use `evidence` only for final proof, hard bugs, or artifact-heavy diagnosis.

## Command Strategy

- Prefer one `run-command` per decision point.
- Use `run-batch` only for short deterministic sequences that do not need mid-step reasoning.
- If the next 3-8 mutations are already obvious and order-dependent, prefer `run-batch` to amortize round-trips.
- Prefer `read-network` over `inspect-ui` when the uncertainty is purely about HTTP traffic.
- Prefer locator combinations like `text + ancestor.route + type` over long brittle paths.
- Use `key` only when the app already has a meaningful stable key. Do not add keys just to make automation pass.
- Use fuzzy `path` only when semantic signals are insufficient.
- Add `fallbacks` when the same intent can be reached through 2-3 stable signals.
- When identical text appears in multiple visible regions, tighten the locator with `index` or a nearby `ancestor` instead of reaching for code changes.
- `scrollUntilVisible` already probes between internal scroll segments, so try one precise locator before composing manual multi-scroll loops.
- `scrollUntilVisible` can recover once in the opposite direction after it hits the wrong boundary, so only force `reverse` when you already know you started above or below the target region.
- On long pages, first reveal a stable section heading or card, then target deeper controls inside that section.
- If you have already scrolled past the target region, switch direction with `reverse: true` or re-anchor from a stable card instead of repeatedly scrolling forward.
- After selection banners, snackbars, or bottom sheets appear, assume the list shifted and re-anchor before tapping the next off-edge row.
- After a mutation inserts, removes, filters, or reorders collection items, re-anchor from a stable visible signal before the next deep collection gesture.
- Do not parallelize a mutating `run-command` with the follow-up `read-app`, `read-network`, or `inspect-ui` that depends on its side effects.

## Timeout Strategy

- Keep default timeouts unless the step is known to be slow.
- Raise `timeoutMs` for long scrolls, waits, or slow environment transitions.
- If a deep target keeps slipping under sticky headers or footers, lower `viewportFraction` to `0.35`-`0.55` before escalating to `inspect-ui`.
- After `hot-restart`, re-read route and consider one explicit `wait-idle` or a larger `timeoutMs` for the first deep interaction instead of assuming the session is immediately stable.
- Treat hot reload success as transport-level success, not proof that your literal, layout, or banner copy changed. Re-read the changed control, then relaunch once if the intended delta is still missing.
- Raise `timeoutSeconds` for `pub`, `analyze_files`, `run_tests`, or project creation only when needed.
- If a command times out, inspect whether the environment is blocked before retrying with a larger budget.

## Verification Ladder

- During development: `run-command` -> `read-app`
- Before claiming a fix: `inspect-ui` or `read-errors` if needed
- Before claiming delivery readiness: `run-script`, `run-task`, or `validate-task`

Do not pay delivery-grade cost on every edit. Do pay it before any user-facing completion claim.

## Token-Saving Shell Patterns

- Keep `app.json` and reuse it:
  `flutter_cockpit_devtools read-app --app-json /tmp/flutter_cockpit/app.json --profile minimal | jq '{currentRouteName,state}'`
- For reload status, project nested fields instead of assuming top-level booleans:
  `flutter_cockpit_devtools hot-reload --app-json /tmp/flutter_cockpit/app.json | jq '{reloadGeneration: .status.reloadGeneration, lastReloadSucceeded: .status.lastReloadSucceeded}'`
- For text input flows, verify the next control or saved state instead of expecting `textPreviews` to mirror the field contents:
  `flutter_cockpit_devtools run-command --app-json /tmp/flutter_cockpit/app.json --command-file /tmp/enter_text.json --profile standard`
- Search first, then open one dependency file:
  `flutter_cockpit_devtools grep-package-uris --package flutter --query ThemeData | jq -r '.packages[0].files[0].packageUri'`
- When only one branch decision matters, extract one field:
  `flutter_cockpit_devtools read-errors --app-json /tmp/flutter_cockpit/app.json | jq '.hasErrors'`
- Keep larger results off stdout only when a later step needs the full payload again:
  `flutter_cockpit_devtools run-task --config-json /tmp/run_task.json --output-json /tmp/runTaskResult.json`
  `jq '{classification,recommendedNextStep}' /tmp/runTaskResult.json`
- Workspace commands default to the current directory, so omit `--workspace-root` unless you are operating outside the repo you already opened.
- Prefer file inputs over long inline JSON:
  `flutter_cockpit_devtools run-command --app-json /tmp/flutter_cockpit/app.json --command-file /tmp/command.json --profile standard`
- Use `jq` to trim, not to compensate for asking the app for an unnecessarily heavy profile.

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
  --command-json '{"commandId":"open-today","commandType":"tap","locator":{"text":"Today","type":"TextButton","ancestor":{"route":"/inbox"}}}'
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

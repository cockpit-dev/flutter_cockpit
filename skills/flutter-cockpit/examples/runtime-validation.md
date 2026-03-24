# Runtime Validation Example

Use this pattern when the task requires live app verification instead of code-only reasoning.

## Example Flow

1. Decide the task requires `flutter_cockpit` because the app must be run and observed.
2. Choose the lighter loop first:
   - for active edit/reload work, prefer a development session
   - for one-off runtime verification, start or reuse a remote session
3. Verify session reachability before issuing interactive commands.
4. Capture baseline state before moving into a longer workflow.
5. Escalate observation detail only when needed:
   - `quick` or `live` for fast health checks
   - `interactive` or `baseline` for the first structured snapshot
   - `diagnostic` or `investigate` for failures or ambiguity
   - `forensic` only when you need a separate diagnostics artifact

## Example Commands

For iterative development work:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  launch-development-session \
  --project-dir examples/cockpit_demo \
  --target lib/main.dart \
  --platform android \
  --android-device-id emulator-5554 \
  --output-json /tmp/flutter_cockpit/development_session.json

dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  collect-development-probe \
  --session-json /tmp/flutter_cockpit/development_session.json \
  --profile interactive
```

For remote runtime verification:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  launch-remote-session \
  --project-dir examples/cockpit_demo \
  --target lib/main.dart \
  --platform android \
  --android-device-id emulator-5554 \
  --session-port 48331 \
  --output-json /tmp/flutter_cockpit/session.json

dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  query-remote-session \
  --session-json /tmp/flutter_cockpit/session.json
```

## Expected Agent Behavior

- prefer `launch-development-session` plus probe/diff during active edit cycles instead of repeatedly relaunching the full app
- do not assume the app is ready until `query-development-session` or `query-remote-session` confirms it
- treat the returned status as baseline evidence and preserve that before-state view for later comparison
- keep high-frequency status reads lightweight; use explicit snapshot or probe collection when richer diagnostics are required
- if the session is unreachable, classify the result as `blocked_by_environment`

# Install `flutter-cockpit`

This directory is a complete `flutter-cockpit` skill asset. In the source repository, the canonical copy lives at:

- `skills/flutter-cockpit/`

Installing the skill means linking or copying **this whole directory** into the current host's skill-discovery directory.

## Preferred AI Prompt

If the current AI host can install skills for you, paste this prompt first:

```text
Install the flutter-cockpit skill for the current AI host by following https://github.com/cockpit-dev/flutter_cockpit/blob/main/skills/flutter-cockpit/INSTALL.md
```

Use the manual steps below only when the host cannot complete installation itself.

## Host-First Rule

Do not assume the current agent is Codex or Claude Code.

The current agent should:

1. identify the active host
2. determine which directory that host scans for personal or local skills
3. install `skills/flutter-cockpit/` into that directory, or configure the host to load this directory directly by path

If the host supports repo-local skill loading by path, it may be able to load this directory directly without copying or linking it into a separate skill directory.

## Repository Adapters

This repository also includes native adapters for common hosts:

- Codex plugin: `plugins/codex/flutter-cockpit`
- Claude Code plugin: `plugins/claude-code/flutter-cockpit`
- Cursor rule: `.cursor/rules/flutter-cockpit.mdc`
- Kiro steering: `.kiro/steering/flutter-cockpit.md`
- OpenCode/OMP skill: `.agents/skills/flutter-cockpit`
- OpenCode config: `opencode.json`

Use `docs/agent-integrations.md` in the source repository when the host supports plugins, rules, steering files, native skill discovery, or MCP setup. Use the symlink flow below when the host only supports personal skill directories.

## Typical Skill Directories

These are common examples, not universal rules:

- **Codex**
  - prefer `~/.agents/skills/flutter-cockpit`
  - some setups still use `~/.codex/skills/flutter-cockpit`
- **Claude Code**
  - `~/.claude/skills/flutter-cockpit`
- **OpenCode / OMP**
  - repo-local `.agents/skills/flutter-cockpit`
  - personal skills may also use `~/.agents/skills/flutter-cockpit`
- **Other hosts**
  - use that host's documented personal-skill or local-skill directory
  - if the host supports direct path loading, use `skills/flutter-cockpit/` itself

## Preferred Install Method

Use a symlink so the installed skill stays in sync with the repository copy.

1. Resolve the absolute path of this directory.
2. Determine the current host's skill-discovery directory.
3. Create the destination parent directory if needed.
4. Create or replace the symlink.
5. Restart the host so it rescans skills.

## Commands

Set the source directory first:

```bash
SKILL_SRC="/absolute/path/to/flutter_cockpit/skills/flutter-cockpit"
```

### Generic Template

```bash
SKILL_DEST="/path/to/current-host-skill-directory/flutter-cockpit"
mkdir -p "$(dirname "$SKILL_DEST")"
ln -sfn "$SKILL_SRC" "$SKILL_DEST"
```

### Codex Examples

Preferred native-discovery location:

```bash
mkdir -p ~/.agents/skills
ln -sfn "$SKILL_SRC" ~/.agents/skills/flutter-cockpit
```

Fallback if the current Codex setup still scans `~/.codex/skills`:

```bash
mkdir -p ~/.codex/skills
ln -sfn "$SKILL_SRC" ~/.codex/skills/flutter-cockpit
```

### Claude Code Example

```bash
mkdir -p ~/.claude/skills
ln -sfn "$SKILL_SRC" ~/.claude/skills/flutter-cockpit
```

## Copy Instead Of Symlink

If symlinks are not appropriate in the current environment:

```bash
SKILL_DEST="/path/to/current-host-skill-directory/flutter-cockpit"
mkdir -p "$(dirname "$SKILL_DEST")"
cp -R "$SKILL_SRC" "$SKILL_DEST"
```

## Verification

After installation:

1. Restart the AI host.
2. Confirm the host can discover `flutter-cockpit`.
3. Confirm the host loads:
   - `SKILL.md`
   - `examples/`
   - `pressure-scenarios.md`
4. Confirm any symlink resolves to this repository's `skills/flutter-cockpit/` directory, not an older checkout or a deleted path.
5. Do not assume the skill is active until the host has restarted or rescanned skills.
6. If the host still does not discover the skill, verify that you chose the correct skill-discovery directory for that host.

## Boundary

- The repository owns the source skill at `skills/flutter-cockpit/`.
- The AI host owns skill discovery and activation.
- Cloning the repository does **not** install the skill automatically.

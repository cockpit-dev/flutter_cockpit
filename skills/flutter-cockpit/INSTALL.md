# Install `flutter-cockpit`

This directory is the source-controlled skill asset:

- `skills/flutter-cockpit/`

Installing the skill means linking or copying **this whole directory** into the current host's personal skill directory.

## Agent-Specific Target Directory

Choose the destination based on the current AI host:

- **Codex**
  - prefer `~/.agents/skills/flutter-cockpit`
  - fall back to `~/.codex/skills/flutter-cockpit` if that is the directory your Codex host scans
- **Claude Code**
  - `~/.claude/skills/flutter-cockpit`

If the host supports repo-local skill loading by path, it may also be able to load this directory directly without copying or linking it into a personal skill directory.

## Preferred Install Method

Use a symlink so the installed skill stays in sync with the repository copy.

1. Resolve the absolute path of this directory.
2. Pick the correct destination for the current host.
3. Create the destination parent directory if needed.
4. Create or replace the symlink.
5. Restart the host so it rescans skills.

## Commands

Set the source directory first:

```bash
SKILL_SRC="/absolute/path/to/flutter_cockpit/skills/flutter-cockpit"
```

### Codex

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

### Claude Code

```bash
mkdir -p ~/.claude/skills
ln -sfn "$SKILL_SRC" ~/.claude/skills/flutter-cockpit
```

## Copy Instead Of Symlink

If symlinks are not appropriate in the current environment:

```bash
cp -R "$SKILL_SRC" ~/.agents/skills/flutter-cockpit
```

Adjust the destination directory to match the current host.

## Verification

After installation:

1. Restart the AI host.
2. Confirm the host can discover `flutter-cockpit`.
3. Confirm the host loads:
   - `SKILL.md`
   - `examples/`
   - `pressure-scenarios.md`
4. Do not assume the skill is active until the host has restarted or rescanned skills.

## Boundary

- The repository owns the source skill at `skills/flutter-cockpit/`.
- The AI host owns skill discovery and activation.
- Cloning the repository does **not** install the skill automatically.

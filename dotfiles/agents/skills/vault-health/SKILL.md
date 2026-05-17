---
name: vault-health
description: Audit an Obsidian vault for consistency issues — broken wikilinks, missing frontmatter, forbidden # Title headings, orphan notes, missing attachments, and unread-tracking violations. Run interactive health checks and generate formatted reports.
user_invocable: true
---

# Vault Health

Scans an Obsidian vault for structural issues and enforces vault conventions. Designed for vaults where multiple AI agents write notes — the health checks catch mistakes before they accumulate.

## Trigger

Use this skill when:
- The user asks to "check vault health", "audit vault", "find broken links", "find orphans", "vault cleanup", or similar
- The user says "run vault-health" or uses `/skill:vault-health`
- You notice the user's vault may have consistency issues (e.g. after bulk edits, migrations, or heavy AI agent activity)

The skill auto-detects the vault root by walking up from `$PWD` looking for `.obsidian/`. Override with `$VAULT_ROOT`.

## Requirements

- **Bash** (macOS default `/bin/bash` is fine)
- Standard POSIX tools: `find`, `grep`, `sed`, `awk`, `sort`, `uniq`
- No npm/pip dependencies

## Configuration

The scan respects an exclusion file: `$VAULT_ROOT/.vaultignore` can list glob patterns (one per line) of paths to skip. Standard `.gitignore` syntax.

```
# Example .vaultignore
_Attachments/*
800 Images/*
.Smart-Sources/*
```

## Available checks

| Check | Flag | What it finds |
|-------|------|---------------|
| Broken wikilinks | `--links` | `[[Target]]` where `Target.md` doesn't exist |
| Frontmatter | `--frontmatter` | Files missing frontmatter or missing `unread: true` |
| Forbidden headings | `--headings` | Files with `# Title` heading (forbidden by vault convention) |
| Orphan notes | `--orphans` | Notes with zero backlinks and zero outgoing links |
| Missing attachments | `--attachments` | `![[file.png]]` references where the file doesn't exist |
| Dangling references | `--references` | Reference notes with zero incoming links |
| Empty dirs | `--emptydirs` | Empty folders in the vault |

## Step 0: Resolve vault root and run the scan

First, resolve the vault root:

```bash
SKILL_DIR="$HOME/.agents/skills/vault-health"
VAULT="${VAULT_ROOT:-}"

# Auto-detect vault if VAULT_ROOT not set
if [ -z "$VAULT" ]; then
  dir="$PWD"
  while [ "$dir" != "/" ]; do
    if [ -d "$dir/.obsidian" ]; then VAULT="$dir"; break; fi
    dir="$(dirname "$dir")"
  done
fi

# Validate
if [ -z "$VAULT" ] || [ ! -d "$VAULT/.obsidian" ]; then
  echo "ERROR: Vault root not found. Set \$VAULT_ROOT or run from inside your vault."
  exit 1
fi
echo "Vault: $VAULT"
export VAULT_ROOT="$VAULT"
```

Then run the scan (all checks by default, or pick specific ones):

```bash
cd "$SKILL_DIR"
./scripts/vault-health.sh                          # all checks
./scripts/vault-health.sh --links --frontmatter    # specific checks only
```

## Step 1: Read and interpret the report

The script prints a clear report with `✓` (pass), `✗` (issues found), and `?` (informational). Example:

```
  vault-health report
  vault: /Users/oliverfildes/notes/obsidian-notes
  date:  2026-05-12 16:30:00

── Broken Wikilinks ──
✗ 3 broken wikilink(s) out of 270 total:
  [[Missing Page]]
    └ path/to/source.md

── Frontmatter Issues ──
✗ 2 file(s) with frontmatter issues:
  some-note.md  —  missing unread: true
  rough.md      —  no frontmatter

── PASS: 5/7 checks clean  WARN: 2/7 checks have issues
```

Present the report to the user in a clear, scannable format. Highlight the most critical issues (broken links > frontmatter > headings > orphans).

## Step 2: Fix issues (user-permission required for each)

Present each category of issue to the user and ask if they want to fix them. **Ask before making any changes.** Work through issues in priority order.

### Broken wikilinks

For each broken `[[Target]]`:
1. Check if the file exists under a different name (case mismatch? renamed?)
2. Check if the link has a simple typo
3. If the target should exist, offer to create a stub note with frontmatter (`created`, `updated`, `unread: true`) and a `# TODO` placeholder
4. If the user declines to create it, note the link as intentionally dangling

**Bulk option**: if there are many broken links that all follow a pattern (e.g. all are missing reference notes for concepts), offer to create them all as stubs.

### Frontmatter issues

For files missing `unread: true`:
```bash
# Add unread: true to existing frontmatter
sed -i '' '/^---$/,/^---$/s/^unread:.*$/unread: true/' "$file"
# Or if unread: doesn't exist yet
sed -i '' '/^---$/,/^---$/{
  /^---$/!b
  a\
unread: true
}' "$file"
```

For files without any frontmatter:
- Add minimal frontmatter: `---\ncreated: $(date -Iseconds)\nupdated: $(date -Iseconds)\nunread: true\n---`
- Use the current date for `created`/`updated`

### Forbidden headings

Strip the `# Title` heading that appears as the first body content after frontmatter (or at the top of files without frontmatter). The filename is the title — the heading is redundant.

```bash
# After frontmatter, remove first # heading
# For files with frontmatter: strip first # heading from body
# For files without frontmatter: strip first # heading from top
```

### Orphan notes

For each orphan (0 in / 0 out), review with the user:
1. Delete it (if truly worthless — e.g. empty rough note)
2. Add links to/from it
3. Move it to `Archive/`

### Missing attachments

For each `![[missing_file]]`:
1. Check if the file exists somewhere else in the vault
2. Check if it was accidentally deleted
3. Remove the embed if the file is gone and not coming back

### Dangling reference notes

For reference notes with zero incoming links:
1. Check if they should be linked from relevant notes
2. If stale, consider deleting or archiving

### Empty directories

Remove empty directories (harmless but clutter navigation).

## Step 3: Write a report note (optional, ask the user)

If the user wants, create a health report note in the vault:

- **Location**: vault root or `500 Notes/520 Daily Notes/`
- **Filename**: `Vault Health DD-MM-YY.md`
- **Frontmatter**: `unread: true`, `type: audit`
- **Body**: Summary of findings with checkboxes for each fix applied

```markdown
---
created: 2026-05-12T16:30:00
updated: 2026-05-12T16:30:00
unread: true
type: audit
---

> [!abstract] Vault Health Report — 2026-05-12
> **5/7 checks passed**, 2 with issues.

## Issues found

- [x] **Broken wikilinks** — 3 broken links, created stubs for all
- [ ] **Frontmatter issues** — 2 files missing `unread: true` (skipped)
- [x] **Orphan notes** — deleted 1 stale rough note
```

## Model notes

- **Always ask before modifying** any file in the vault. Present findings first, then offer fixes.
- The `vault-health.sh` script exits 0 if all checks pass, 1 if issues are found.
- When fixing, work in priority order: broken links → frontmatter → headings → orphans → attachments → references → empty dirs.
- Set `unread: true` on every note you create or modify.
- Respect the vault's convention: **no `# Title` headings** on any note.
- The skill directory is at `$HOME/.agents/skills/vault-health/`. Use absolute paths or cd there before running scripts.
- If the user wants to ignore certain directories from future scans, suggest adding them to `$VAULT_ROOT/.vaultignore`.

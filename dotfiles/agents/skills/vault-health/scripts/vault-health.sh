#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────────────────────
# vault-health.sh  —  Obsidian vault consistency checker
# Usage:  ./vault-health.sh [--links] [--frontmatter] [--headings]
#                          [--orphans] [--attachments] [--references] [--emptydirs]
#
# If no flags given, runs ALL checks.
# ─────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"

# ── Resolve vault root ──────────────────────────────────────
VAULT="${VAULT_ROOT:-}"
if [ -z "$VAULT" ]; then
  dir="$PWD"
  while [ "$dir" != "/" ]; do
    if [ -d "$dir/.obsidian" ]; then VAULT="$dir"; break; fi
    dir="$(dirname "$dir")"
  done
fi

if [ -z "$VAULT" ] || [ ! -d "$VAULT/.obsidian" ]; then
  echo "ERROR: Cannot find Obsidian vault root. Set \$VAULT_ROOT or run from inside your vault."
  exit 1
fi

cd "$VAULT"

# ── Parse flags ─────────────────────────────────────────────
RUN_ALL=true
RUN_LINKS=false
RUN_FRONTMATTER=false
RUN_HEADINGS=false
RUN_ORPHANS=false
RUN_ATTACHMENTS=false
RUN_REFERENCES=false
RUN_EMPTYDIRS=false

for arg in "$@"; do
  case "$arg" in
    --links)        RUN_LINKS=true;        RUN_ALL=false ;;
    --frontmatter)  RUN_FRONTMATTER=true;  RUN_ALL=false ;;
    --headings)     RUN_HEADINGS=true;     RUN_ALL=false ;;
    --orphans)      RUN_ORPHANS=true;      RUN_ALL=false ;;
    --attachments)  RUN_ATTACHMENTS=true;  RUN_ALL=false ;;
    --references)   RUN_REFERENCES=true;   RUN_ALL=false ;;
    --emptydirs)    RUN_EMPTYDIRS=true;    RUN_ALL=false ;;
    --help|-h)
      echo "Usage: vault-health.sh [--links] [--frontmatter] [--headings] [--orphans] [--attachments] [--references] [--emptydirs]"
      echo "  (no flags = run all checks)"
      exit 0
      ;;
    *)
      echo "Unknown flag: $arg"
      exit 1
      ;;
  esac
done

if [ "$RUN_ALL" = true ]; then
  RUN_LINKS=true
  RUN_FRONTMATTER=true
  RUN_HEADINGS=true
  RUN_ORPHANS=true
  RUN_ATTACHMENTS=true
  RUN_REFERENCES=true
  RUN_EMPTYDIRS=true
fi

# ── Temp files ──────────────────────────────────────────────
TMPDIR=$(mktemp -d /tmp/vault-health.XXXXXX)
trap 'rm -rf "$TMPDIR"' EXIT

# ── Helpers ─────────────────────────────────────────────────
PASS=0
WARN=0
TOTAL_CHECKS=0

header() { echo ""; echo "────────────────────────────────────────"; echo "  $1"; echo "────────────────────────────────────────"; }

# Safe find for markdown files, respecting .vaultignore
# Pass extra args (e.g. -print0) as arguments to this function
find_md() {
  local find_cmd=(
    find "$VAULT"
    -name "*.md" -type f
    -not -path "*/.git/*"
    -not -path "*/.obsidian/*"
    -not -path "*/node_modules/*"
  )

  # Read .vaultignore and build exclusion patterns
  if [ -f "$VAULT/.vaultignore" ]; then
    while IFS= read -r line; do
      [[ "$line" =~ ^[[:space:]]*# ]] && continue
      [[ -z "${line// }" ]] && continue
      find_cmd+=( -not -path "*/${line}*" )
    done < "$VAULT/.vaultignore"
  fi

  # Append any extra arguments passed to this function (e.g. -print0)
  "${find_cmd[@]}" "$@" 2>/dev/null
}

relpath() { echo "${1#$VAULT/}"; }

# Check if a list file is non-empty for reporting
count_lines() {
  local f="$1"
  if [ -f "$f" ] && [ -s "$f" ]; then
    wc -l < "$f" | tr -d ' '
  else
    echo 0
  fi
}

# ════════════════════════════════════════════════════════════
#  CHECK 1: Broken Wikilinks
# ════════════════════════════════════════════════════════════
check_links() {
  TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
  header "Broken Wikilinks"

  # Build a set of ALL existing note paths (relative from vault root, case-insensitive)
  # We store both the basename and the full path for matching
  find_md -print0 | while IFS= read -r -d '' f; do
    rel="$(relpath "$f")"
    lower_rel="$(echo "$rel" | tr '[:upper:]' '[:lower:]')"
    base="$(basename "$rel" .md)"
    lower_base="$(echo "$base" | tr '[:upper:]' '[:lower:]')"
    echo "BASENAME|$lower_base" >> "$TMPDIR/existing-notes.txt"
    echo "PATH|$lower_rel" >> "$TMPDIR/existing-notes.txt"
  done
  sort -u "$TMPDIR/existing-notes.txt" -o "$TMPDIR/existing-notes.txt"

  # Extract all wikilink targets
  find_md -print0 | xargs -0 grep -roh '\[\[[^]]*\]\]' 2>/dev/null \
    | sed 's/\[\[//; s/\]\]//' \
    | sed 's/|.*//' \
    | sed 's/#.*//' \
    | sed 's/\^.*//' \
    | sort -u > "$TMPDIR/all-linked-targets.txt" || true

  # Filter out: URLs, emails, file paths, dates, template placeholders, empty targets
  grep -vE '^(https?://|mailto:|file:|ftp://|[0-9]{2,}[-/][0-9]{2,}|[A-Z]:\\|/|[<>])' \
    "$TMPDIR/all-linked-targets.txt" > "$TMPDIR/linked-targets.txt" || true
  grep -vE '[<>]' "$TMPDIR/linked-targets.txt" > "$TMPDIR/linked-targets-filtered.txt" || true
  mv "$TMPDIR/linked-targets-filtered.txt" "$TMPDIR/linked-targets.txt"

  local total_links
  total_links=$(wc -l < "$TMPDIR/linked-targets.txt" | tr -d ' ')

  # For each target, check if it exists
  > "$TMPDIR/broken-links.txt"
  local broken=0

  while IFS= read -r target; do
    [ -z "$target" ] && continue

    # Remove trailing slash (folder references like [[700 People/]])
    target="${target%/}"
    [ -z "$target" ] && continue

    local target_lower
    target_lower=$(echo "$target" | tr '[:upper:]' '[:lower:]')

    local found=false

    # Check 1: If target contains /, treat as relative path and check directly
    if echo "$target" | grep -q '/'; then
      # Try as full path from vault root (with .md extension)
      local test_path_lower="${target_lower}.md"
      if grep -qF "PATH|$test_path_lower" "$TMPDIR/existing-notes.txt" 2>/dev/null; then
        found=true
      fi
      # Also try without .md (in case relpath didn't have it)
      if [ "$found" = false ]; then
        if grep -qF "PATH|$target_lower" "$TMPDIR/existing-notes.txt" 2>/dev/null; then
          found=true
        fi
      fi
    fi

    # Check 2: If not found by path, check by basename (case-insensitive)
    if [ "$found" = false ]; then
      if grep -qi "^BASENAME|$target_lower$" "$TMPDIR/existing-notes.txt" 2>/dev/null; then
        found=true
      fi
    fi

    if [ "$found" = false ]; then
      echo "$target" >> "$TMPDIR/broken-links.txt"
      broken=$((broken + 1))
    fi
  done < "$TMPDIR/linked-targets.txt"

  if [ "$broken" -eq 0 ]; then
    echo "  ✓ All $total_links wikilinks resolve to existing notes."
    PASS=$((PASS + 1))
  else
    echo "  ✗ $broken broken wikilink(s) out of $total_links total:"
    echo ""
    # Show broken links with sources (limit to avoid SIGPIPE)
    local count=0
    while IFS= read -r link && [ "$count" -lt 30 ]; do
      echo "    [[$link]]"
      # Find source files (limit to 3)
      local src_count=0
      while IFS= read -r -d '' src && [ "$src_count" -lt 3 ]; do
        echo "      └ $(relpath "$src")"
        src_count=$((src_count + 1))
      done < <(find_md -print0 | xargs -0 grep -l "\[\[$link" 2>/dev/null | head -3 | tr '\n' '\0')
      echo ""
      count=$((count + 1))
    done < "$TMPDIR/broken-links.txt"

    local bc
    bc=$(wc -l < "$TMPDIR/broken-links.txt" | tr -d ' ')
    if [ "$bc" -gt 30 ]; then
      echo "  (... and $((bc - 30)) more broken links)"
    fi
    WARN=$((WARN + 1))
  fi
}

# ════════════════════════════════════════════════════════════
#  CHECK 2: Frontmatter Issues
# ════════════════════════════════════════════════════════════
check_frontmatter() {
  TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
  header "Frontmatter Issues"

  > "$TMPDIR/fm-issues.txt"

  find_md -print0 | while IFS= read -r -d '' f; do
    local rel=$(relpath "$f")

    # Read first line
    local first_line
    first_line=$(head -1 "$f" 2>/dev/null || echo "")

    # Check 2a: No frontmatter at all
    if [ "$first_line" != "---" ]; then
      echo "$rel  —  no frontmatter" >> "$TMPDIR/fm-issues.txt"
      continue
    fi

    # Check 2b: Has frontmatter, check for unread: true
    local has_unread=false
    local line_num=0
    while IFS= read -r line; do
      line_num=$((line_num + 1))
      if [ "$line_num" -eq 1 ] && [ "$line" = "---" ]; then continue; fi
      if [ "$line" = "---" ]; then break; fi
      if echo "$line" | grep -qE '^unread:\s*true'; then
        has_unread=true
        break
      fi
    done < "$f"

    if [ "$has_unread" = false ]; then
      echo "$rel  —  missing unread: true" >> "$TMPDIR/fm-issues.txt"
    fi
  done

  local count
  count=$(count_lines "$TMPDIR/fm-issues.txt")
  if [ "$count" -eq 0 ]; then
    echo "  ✓ All files have proper frontmatter with unread: true."
    PASS=$((PASS + 1))
  else
    echo "  ✗ $count file(s) with frontmatter issues:"
    echo ""
    head -40 "$TMPDIR/fm-issues.txt" | while IFS= read -r line; do
      echo "    $line"
    done
    if [ "$count" -gt 40 ]; then
      echo "  (... and $((count - 40)) more)"
    fi
    WARN=$((WARN + 1))
  fi
}

# ════════════════════════════════════════════════════════════
#  CHECK 3: Forbidden # Title Headings
# ════════════════════════════════════════════════════════════
check_headings() {
  TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
  header "Forbidden # Title Headings"

  > "$TMPDIR/bad-headings.txt"

  find_md -print0 | while IFS= read -r -d '' f; do
    local rel=$(relpath "$f")
    local first_line
    first_line=$(head -1 "$f" 2>/dev/null || echo "")

    if [ "$first_line" = "---" ]; then
      # Has frontmatter — skip past it, check first body line
      local in_fm=true
      local line_num=0
      while IFS= read -r line; do
        line_num=$((line_num + 1))
        if [ "$in_fm" = true ]; then
          if [ "$line" = "---" ] && [ "$line_num" -gt 1 ]; then
            in_fm=false
          fi
          continue
        fi
        # Skip blank lines
        if echo "$line" | grep -qE '^\s*$'; then
          continue
        fi
        # First non-empty body line — is it a heading?
        if echo "$line" | grep -qE '^#\s'; then
          # Extract just first 60 chars for display
          local display
          display=$(echo "$line" | head -c 60)
          echo "$rel  —  \"$display...\"" >> "$TMPDIR/bad-headings.txt"
        fi
        break
      done < "$f"
    else
      # No frontmatter — check first non-empty line
      while IFS= read -r line; do
        if echo "$line" | grep -qE '^\s*$'; then
          continue
        fi
        if echo "$line" | grep -qE '^#\s'; then
          local display
          display=$(echo "$line" | head -c 60)
          echo "$rel  —  \"$display...\" (also missing frontmatter)" >> "$TMPDIR/bad-headings.txt"
        fi
        break
      done < "$f"
    fi
  done

  local count
  count=$(count_lines "$TMPDIR/bad-headings.txt")
  if [ "$count" -eq 0 ]; then
    echo "  ✓ No notes start with a forbidden # Title heading."
    PASS=$((PASS + 1))
  else
    echo "  ✗ $count note(s) start with a # Title heading (convention violation):"
    echo ""
    cat "$TMPDIR/bad-headings.txt"
    WARN=$((WARN + 1))
  fi
}

# ════════════════════════════════════════════════════════════
#  CHECK 4: Orphan Notes
# ════════════════════════════════════════════════════════════
check_orphans() {
  TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
  header "Orphan Notes"

  # First, build a list of all notes and their basenames
  > "$TMPDIR/orphans.txt"

  # Collect all note basenames
  find_md -print0 | while IFS= read -r -d '' f; do
    local rel=$(relpath "$f")

    # Skip template, base, plugin, and attachment directories
    case "$rel" in
      _Templates/*|_BASES/*|.obsidian/*|Plugins/*|_Attachments/*|800\ Images/*|.git/*)
        continue ;;
    esac

    local basename_note
    basename_note=$(basename "$f" .md)

    # Count outgoing wikilinks in this file
    local outgoing
    outgoing=$(grep -c '\[\[[^]]*\]\]' "$f" 2>/dev/null || true)

    if [ "$outgoing" -eq 0 ]; then
      # No outgoing links.
      # Count incoming links (other files that [[link]] to this basename)
      local incoming=0
      # Use find_md and xargs for safe iteration, exclude self
      while IFS= read -r -d '' other; do
        if [ "$other" = "$f" ]; then continue; fi
        if grep -q "\[\[${basename_note}\]" "$other" 2>/dev/null ||
           grep -q "\[\[${basename_note}|" "$other" 2>/dev/null ||
           grep -q "\[\[${basename_note}#" "$other" 2>/dev/null ||
           grep -q "\[\[${basename_note}\^" "$other" 2>/dev/null; then
          incoming=$((incoming + 1))
        fi
      done < <(find_md -print0)

      if [ "$incoming" -eq 0 ]; then
        echo "$rel  (0 in / 0 out)" >> "$TMPDIR/orphans.txt"
      fi
    fi
  done

  local count
  count=$(count_lines "$TMPDIR/orphans.txt")
  if [ "$count" -eq 0 ]; then
    echo "  ✓ No orphan notes found."
    PASS=$((PASS + 1))
  else
    echo "  ? $count note(s) with zero incoming AND zero outgoing links:"
    echo ""
    cat "$TMPDIR/orphans.txt"
    WARN=$((WARN + 1))
  fi
}

# ════════════════════════════════════════════════════════════
#  CHECK 5: Missing Attachments
# ════════════════════════════════════════════════════════════
check_attachments() {
  TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
  header "Missing Attachments"

  > "$TMPDIR/all-embeds.txt"
  > "$TMPDIR/missing-attachments.txt"

  # Find all ![[file.ext]] references (embeds) using safe xargs
  find_md -print0 | xargs -0 grep -roh '!\[\[[^]]*\]\]' 2>/dev/null \
    | sed 's/!\[\[//; s/\]\]//' \
    | sort -u > "$TMPDIR/all-embeds.txt" || true

  # Clean embed references: strip |width, #fragment, ^block-id
  # Also filter out template variables (${...}), .base files
  > "$TMPDIR/cleaned-embeds.txt"
  while IFS= read -r embed; do
    [ -z "$embed" ] && continue
    # Skip template variables (${...})
    echo "$embed" | grep -qE '^\$\{' && continue
    # Skip .base references (Obsidian Bases plugin)
    echo "$embed" | grep -qi '\.base' && continue
    # Strip |width syntax and #fragment
    local cleaned
    cleaned=$(echo "$embed" | sed 's/|.*//' | sed 's/#.*//' | sed 's/\^.*//')
    [ -n "$cleaned" ] && echo "$cleaned" >> "$TMPDIR/cleaned-embeds.txt"
  done < "$TMPDIR/all-embeds.txt"
  sort -u "$TMPDIR/cleaned-embeds.txt" -o "$TMPDIR/cleaned-embeds.txt" 2>/dev/null || true

  # Also find ![](path) image references
  find_md -print0 | xargs -0 grep -roh '!\[[^]]*\]([^)]*)' 2>/dev/null \
    | sed 's/.*](//; s/)$//' \
    | sort -u > "$TMPDIR/all-img-refs.txt" || true

  # Check each cleaned embed
  while IFS= read -r embed; do
    [ -z "$embed" ] && continue
    local found_file=""
    # If no extension, try .md (Obsidian ![[Note]] -> Note.md)
    if ! echo "$embed" | grep -qE '\.[a-zA-Z0-9]+$'; then
      found_file=$(find "$VAULT" -name "${embed}.md" -type f 2>/dev/null | head -1)
    fi
    # Also try as exact name (for images, PDFs, etc.)
    if [ -z "$found_file" ]; then
      found_file=$(find "$VAULT" -name "$embed" -type f 2>/dev/null | head -1)
    fi
    if [ -z "$found_file" ]; then
      echo "$embed" >> "$TMPDIR/missing-attachments.txt"
    fi
  done < "$TMPDIR/cleaned-embeds.txt"

  # Check image references ![](path)
  while IFS= read -r ref; do
    [ -z "$ref" ] && continue
    # Skip URLs and template variables
    echo "$ref" | grep -qE '^https?://' && continue
    echo "$ref" | grep -qE '^\$\{' && continue
    local full_path="$VAULT/$ref"
    if [ ! -f "$full_path" ] && [ ! -f "$ref" ]; then
      echo "$ref (image ref)" >> "$TMPDIR/missing-attachments.txt"
    fi
  done < "$TMPDIR/all-img-refs.txt"

  # Deduplicate
  if [ -f "$TMPDIR/missing-attachments.txt" ]; then
    sort -u "$TMPDIR/missing-attachments.txt" -o "$TMPDIR/missing-attachments.txt"
  fi

  local count
  count=$(count_lines "$TMPDIR/missing-attachments.txt")
  if [ "$count" -eq 0 ]; then
    echo "  ✓ All embedded files and images resolve to existing files."
    PASS=$((PASS + 1))
  else
    echo "  ✗ $count attachment(s) reference missing files:"
    echo ""
    cat "$TMPDIR/missing-attachments.txt"
    WARN=$((WARN + 1))
  fi
}

# ════════════════════════════════════════════════════════════
#  CHECK 6: Dangling Reference Notes
# ════════════════════════════════════════════════════════════
check_references() {
  TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
  header "Dangling Reference Notes"

  # Find the reference notes directory
  local ref_dir=""
  for candidate in \
    "$VAULT/200 Source Material/250 Reference" \
    "$VAULT/200 Source Material/250 References" \
    "$VAULT/250 Reference" \
    "$VAULT/References"; do
    if [ -d "$candidate" ]; then
      ref_dir="$candidate"
      break
    fi
  done

  if [ -z "$ref_dir" ]; then
    echo "  - No reference notes directory found."
    echo "    (Searched: 200 Source Material/250 Reference, etc.)"
    PASS=$((PASS + 1))
    return
  fi

  > "$TMPDIR/dangling-refs.txt"

  find "$ref_dir" -name "*.md" -type f -print0 2>/dev/null | while IFS= read -r -d '' ref_note; do
    local basename_note
    basename_note=$(basename "$ref_note" .md)
    local rel=$(relpath "$ref_note")

    # Count incoming links from OTHER files
    local incoming=0
    while IFS= read -r -d '' other; do
      if [ "$other" = "$ref_note" ]; then continue; fi
      if grep -q "\[\[${basename_note}\]" "$other" 2>/dev/null ||
         grep -q "\[\[${basename_note}|" "$other" 2>/dev/null ||
         grep -q "\[\[${basename_note}#" "$other" 2>/dev/null ||
         grep -q "\[\[${basename_note}\^" "$other" 2>/dev/null; then
        incoming=$((incoming + 1))
        break  # We only need to know if at least one exists
      fi
    done < <(find_md -print0)

    if [ "$incoming" -eq 0 ]; then
      echo "$rel" >> "$TMPDIR/dangling-refs.txt"
    fi
  done

  local count
  count=$(count_lines "$TMPDIR/dangling-refs.txt")
  if [ "$count" -eq 0 ]; then
    echo "  ✓ All reference notes have incoming links."
    PASS=$((PASS + 1))
  else
    echo "  ? $count reference note(s) with zero incoming links from other notes:"
    echo ""
    head -30 "$TMPDIR/dangling-refs.txt" | while IFS= read -r line; do
      echo "    $line"
    done
    if [ "$count" -gt 30 ]; then
      echo "  (... and $((count - 30)) more)"
    fi
    WARN=$((WARN + 1))
  fi
}

# ════════════════════════════════════════════════════════════
#  CHECK 7: Empty Directories
# ════════════════════════════════════════════════════════════
check_emptydirs() {
  TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
  header "Empty Directories"

  local empty_list
  empty_list=$(find "$VAULT" -type d -empty \
    -not -path "*/.git/*" \
    -not -path "*/.obsidian/*" \
    -not -path "*/node_modules/*" \
    2>/dev/null | sort)

  if [ -z "$empty_list" ]; then
    echo "  ✓ No empty directories found."
    PASS=$((PASS + 1))
  else
    local count
    count=$(echo "$empty_list" | wc -l | tr -d ' ')
    echo "  ? $count empty director(ies):"
    echo ""
    echo "$empty_list" | while IFS= read -r d; do
      echo "    $(relpath "$d")"
    done
    WARN=$((WARN + 1))
  fi
}

# ════════════════════════════════════════════════════════════
#  REPORT
# ════════════════════════════════════════════════════════════
echo ""
echo "════════════════════════════════════════════════"
echo "  vault-health report"
echo "  vault: $VAULT"
echo "  date:  $(date '+%Y-%m-%d %H:%M:%S')"
echo "════════════════════════════════════════════════"

$RUN_LINKS       && check_links
$RUN_FRONTMATTER && check_frontmatter
$RUN_HEADINGS    && check_headings
$RUN_ORPHANS     && check_orphans
$RUN_ATTACHMENTS && check_attachments
$RUN_REFERENCES  && check_references
$RUN_EMPTYDIRS   && check_emptydirs

echo ""
echo "════════════════════════════════════════════════"
echo "  PASS: $PASS/$TOTAL_CHECKS checks clean"
echo "  WARN: $WARN/$TOTAL_CHECKS checks have issues"
echo "════════════════════════════════════════════════"
echo ""

if [ "$WARN" -gt 0 ]; then
  exit 1
fi
exit 0

---
name: daily-note
description: Create or update the daily note for today — scaffold with Dataview task queries, weather, and server health. Safe to re-run: preserves user-added content, only refreshes weather + server.
user_invocable: true
---

# Daily Note

Creates today's daily note at `500 Notes/520 Daily Notes/DD-MM-YY.md` with Dataview-powered task queries, live weather, and server health. On re-runs, preserves all user content and only refreshes weather + server.

## Trigger

Use this skill when:
- The user asks to "create my daily note", "start daily note", "make today's note", or similar
- The user says `/skill:daily-note`
- A session starts and today's daily note doesn't exist (auto-create)
- The user asks to "update my daily note"

## Requirements

- `curl` for weather
- SSH key access to `100.75.139.39` (default key)
- Vault root auto-detected from `$PWD` or `$VAULT_ROOT`
- Dataview plugin installed in Obsidian (tasks render at view time via DQL blocks — no ripgrep scanning needed)

## Behavior

### First create (note doesn't exist)

Writes a full daily note:
- Frontmatter (`created`, `updated`, `unread: true`)
- Tag link `[[300 Tags/Daily Note|Daily Note]]`
- Date line
- `### 🧥 Weather` — live weather from wttr.in with commentary
- `## 🎯 Tasks` — five Dataview `TASK` query blocks in callouts:
  - `[!danger]` Overdue
  - `[!warning]` Due Today
  - `[!example]` School (tasks from `500 Notes/530 School/` due within 3 days)
  - `[!info]` Upcoming (tasks due this week)
  - `[!note]` Priority tasks with no due date
- `## ✍️ Tasks for today` — empty checklist for ad-hoc tasks throughout the day
- `## 📝 What I did` — empty
- `## 🖥️ Server check` — live SSH data with error handling
- `## 💭 Random` — empty

### Re-run (note exists for today)

Preserves ALL user-written sections. Only updates:
- `### 🧥 Weather` — refreshed from wttr.in
- `## 🖥️ Server check` — refreshed from SSH
- Frontmatter `updated:` timestamp and `unread: true`

Dataview query blocks are dynamic — they auto-refresh inside Obsidian, so task data is always current without the skill needing to scan or parse tasks.

## Step-by-step

### 1. Resolve date and path

Determine today's date parameters:

| Variable | Format | Example |
|----------|--------|---------|
| `TODAY` | `DD-MM-YY` | `13-05-26` |
| `FULL_DATE` | `dddd, DD MMMM YYYY` | `Wednesday, 13 May 2026` |
| `ISO_DATE` | `YYYY-MM-DDTHH:mm` | `2026-05-13T16:40` |
| `NOTE_PATH` | `/{vault}/500 Notes/520 Daily Notes/DD-MM-YY.md` | |

```bash
TODAY=$(date +%d-%m-%y)
FULL_DATE=$(date "+%A, %d %B %Y")
ISO_DATE=$(date +%Y-%m-%dT%H:%M)
VAULT="${VAULT_ROOT:-$PWD}"
NOTE_PATH="$VAULT/500 Notes/520 Daily Notes/$TODAY.md"
```

### 2. Determine mode

```bash
if [ -f "$NOTE_PATH" ]; then
  MODE="update"
else
  MODE="create"
fi
```

### 3. Fetch live data (both modes)

**Weather (with error handling):**
```bash
weather=$(curl -s --max-time 10 "wttr.in/Whitley+Bay?format=%C+%t+%w" 2>/dev/null || echo "")
if [ -z "$weather" ]; then
  weather="⚠️ Weather unavailable — check your connection"
else
  # Add charming commentary matching the daily-brief style.
  # Examples:
  #   ⛅ Partly cloudy +11°C ↓23km/h — light jacket weather, pleasant enough 🧥
  #   🌧️ Light rain +9°C ↙30km/h — grim, proper Whitley Bay special 🌂
  #   ☀️ Sunny +18°C →5km/h — genuinely nice, enjoy it while it lasts 😎
fi
```

**Server health (with error handling):**
```bash
server=$(ssh -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=accept-new 100.75.139.39 \
  "echo '=== UPTIME ===' && uptime && \
   echo '=== DOCKER ===' && docker ps --format 'table {{.Names}}\t{{.Status}}' && \
   echo '=== DISK ===' && df -h / | tail -1" 2>/dev/null || echo "")
if [ -z "$server" ]; then
  server="SSH_FAILED"
fi
```

Parse server output:
- **uptime** → duration and load average
- **docker ps** → container count; flag any with `unhealthy` or `restarting` status
- **df -h /** → disk usage

No ripgrep task scanning. Tasks are handled by Dataview DQL blocks at view time.

### 4a. Mode: create — write the full note

Compose the note:

````markdown
---
created: {ISO_DATE}
updated: {ISO_DATE}
unread: true
---

[[300 Tags/Daily Note|Daily Note]]

> _{FULL_DATE}_

### 🧥 Weather
{weather_output}

## 🎯 Tasks

> [!danger] ⏰ Overdue
> ```dataview
> TASK
> WHERE !completed AND due AND due < date(today)
> SORT priority DESC
> ```

> [!warning] 📅 Due Today
> ```dataview
> TASK
> WHERE !completed AND due AND due = date(today)
> SORT priority DESC
> ```

> [!example] 📚 School (due within 3 days)
> ```dataview
> TASK
> FROM "500 Notes/530 School"
> WHERE !completed AND due AND due <= date(today) + dur(3d)
> SORT due ASC
> ```

> [!info] 🔜 Upcoming (this week)
> ```dataview
> TASK
> WHERE !completed AND due AND due > date(today) AND due <= date(today) + dur(7d)
> SORT due ASC
> ```

> [!note] ⏫ No due date
> ```dataview
> TASK
> WHERE !completed AND !due AND priority != null
> SORT priority DESC
> ```

## ✍️ Tasks for today
<!-- Add tasks as they come up during the day: - [ ] description 📅 YYYY-MM-DD ⏫ -->
- [ ] 

## 📝 What I did
-

## 🖥️ Server check
{server_health_block}

## 💭 Random
-
````

**Rules:**
- Dataview blocks use 3 backticks with `dataview` language tag
- Each Dataview block wraps in a callout matching its intent: `[!danger]` overdue, `[!warning]` due today, `[!example]` school, `[!info]` upcoming, `[!note]` priority
- School tasks appear in BOTH the `📚 School` section AND the general `⏰ Overdue`/`📅 Due Today`/`🔜 Upcoming` sections — intentional duplication for visibility
- `✍️ Tasks for today` starts with a single empty checkbox (`- [ ]`) ready for user input
- The HTML comment in `✍️ Tasks for today` is a hint; the user can use any format
- `## 🖥️ Server check` is a top-level `##` heading (not `###`)

**Server formatting:**

On success:
```markdown
- ⏱️ Up {X}d {X}h — load {X.XX} (commentary) ☕
- 💾 {used} / {total} used ({X}%) — commentary
- 🐳 {X} containers, all healthy ✅
```

If any container shows `unhealthy` or `restarting`:
```markdown
- 🐳 {X} containers — ⚠️ {N} unhealthy! ({names})
```

On failure:
```markdown
- ⚠️ Unable to reach server — SSH connection failed
```

### 4b. Mode: update — preserve and refresh

1. **Read** the existing note file
2. **Update `### 🧥 Weather`** — replace everything from that heading to the next heading (any level), preserving the heading itself
3. **Update `## 🖥️ Server check`** — replace everything from that heading to the next `## ` heading or end of file, preserving the heading
4. **Bump frontmatter:**
   - Set `updated: {ISO_DATE}`
   - Ensure `unread: true` is present
5. **Everything else untouched** — all user content in `## 📝 What I did`, `## 💭 Random`, `## ✍️ Tasks for today`, and any user-added sections stays as-is

### 5. Style rules

- **No `# Title` heading** — ever. Filename is the title.
- Dataview blocks use ` ```dataview ` fence with the `TASK` query type
- Each Dataview callout stays compact — one query per callout, no nesting
- All task rendering is done by Dataview at view time; no static `- [ ]` checkboxes in `## 🎯 Tasks`
- The `✍️ Tasks for today` section is the only place for manual user-added tasks
- Emoji cheat sheet:
  - ⏰ overdue, 📅 due today, 📚 school, 🔜 upcoming, ⏫ high priority
  - ⏱️ uptime, 💾 disk, 🐳 Docker, 🧥 weather, 🖥️ server
  - ✅ healthy, ⚠️ problem, ☕ load comment, 😎 sunny, 🌧️ rain, 🌂 umbrella, 🧥 jacket
- Sort within Dataview blocks: `priority DESC` for overdue/due-today/no-date, `due ASC` for school/upcoming
- Weather commentary and server commentary keep the daily-brief skill's charming, light tone
- School tasks appear 3 days before their due date automatically — `dur(3d)` in the Dataview query handles this

## Examples

### Full create

```markdown
---
created: 2026-05-15T08:16
updated: 2026-05-15T08:16
unread: true
---

[[300 Tags/Daily Note|Daily Note]]

> _Friday, 15 May 2026_

### 🧥 Weather
🌤️ Partly cloudy +12°C ↓18km/h — light jacket weather, fairly pleasant 🧥

## 🎯 Tasks

> [!danger] ⏰ Overdue
> ```dataview
> TASK
> WHERE !completed AND due AND due < date(today)
> SORT priority DESC
> ```

> [!warning] 📅 Due Today
> ```dataview
> TASK
> WHERE !completed AND due AND due = date(today)
> SORT priority DESC
> ```

> [!example] 📚 School (due within 3 days)
> ```dataview
> TASK
> FROM "500 Notes/530 School"
> WHERE !completed AND due AND due <= date(today) + dur(3d)
> SORT due ASC
> ```

> [!info] 🔜 Upcoming (this week)
> ```dataview
> TASK
> WHERE !completed AND due AND due > date(today) AND due <= date(today) + dur(7d)
> SORT due ASC
> ```

> [!note] ⏫ No due date
> ```dataview
> TASK
> WHERE !completed AND !due AND priority != null
> SORT priority DESC
> ```

## ✍️ Tasks for today
<!-- Add tasks as they come up during the day: - [ ] description 📅 YYYY-MM-DD ⏫ -->
- [ ] 

## 📝 What I did
-

## 🖥️ Server check
- ⏱️ Up 7d 0h — load 0.25 (quiet morning brew) ☕
- 💾 63G / 227G used (30%) — plenty of breathing room
- 🐳 25 containers, all healthy ✅

## 💭 Random
-
```

### Update — weather + server refresh only

When re-running on an existing note, only weather and server sections are touched. All user-written sections preserved exactly as-is.

### Server failure

```markdown
## 🖥️ Server check
- ⚠️ Unable to reach server — SSH connection failed
```

### Weather failure

```markdown
### 🧥 Weather
⚠️ Weather unavailable — check your connection
```

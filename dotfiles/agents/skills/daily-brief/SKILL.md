---
name: daily-brief
description: Generate a daily briefing — weather, vault tasks, server health, and top news headlines. Writes to 📌 Daily Brief.md and 📰 Daily News.md.
user_invocable: true
---

# Daily Brief

Generates a compact daily briefing in `📌 Daily Brief.md` with live weather, vault-sourced tasks, server health, and top news headlines from BBC RSS feeds. Also writes headlines to `📰 Daily News.md`. Each day is a collapsed callout so the files stay clean.

## Trigger

Use this skill when:
- The user asks to "update my daily brief", "run the daily brief", "get today's brief", or similar
- The user says `/skill:daily-brief`
- The user asks for weather and tasks in one go
- It's a new day and the brief hasn't been updated yet

## Requirements

- `curl` for weather and RSS feeds
- `rg` (ripgrep) for searching vault tasks
- SSH key access to `100.75.139.39` (default key)
- Vault root auto-detected from `$PWD` or `$VAULT_ROOT`
- `📌 Daily Brief.md` and `📰 Daily News.md` must exist at vault root

## Step-by-step

### 1. Locate the brief file

The file is `📌 Daily Brief.md` at the vault root. Read its current contents to find the latest month header and entries.

### 2. Fetch weather

```bash
curl -s "wttr.in/Whitley+Bay?format=%C+%t+%w"
```

Returns something like: `Light rain +12°C ↙15km/h`

### 3. Fetch tasks from the vault

Search all markdown files for open tasks in Obsidian Tasks format:

```bash
rg '^- \[ \]' "$VAULT_ROOT" --type md -n 2>/dev/null
```

Each match looks like:
```
path/to/note.md:10:- [ ] Task content 📅 2026-04-17 ⏫
```

Parse out:
- **Content** — the task description
- **Due date** — `📅 YYYY-MM-DD`
- **Priority** — `⏫` / `🔺` / `🔼`
- **File** — where it lives

Cross-reference with today — anything due today or past due gets flagged as ⚠️.

### 4. Fetch server health

```bash
ssh 100.75.139.39 "echo '=== UPTIME ===' && uptime && echo '=== DOCKER ===' && docker ps --format 'table {{.Names}}\t{{.Status}}' && echo '=== DISK ===' && df -h / | tail -1"
```

Note uptime, any unhealthy/restarting containers, and disk usage percentage.

### 5. Fetch news headlines

Fetch top headlines from free BBC RSS feeds. Fetch all 4 feeds in parallel with separate `curl` calls:

| Category | Emoji | Feed |
|----------|-------|------|
| World | 🌍 | `https://feeds.bbci.co.uk/news/world/rss.xml` |
| UK | 🇬🇧 | `https://feeds.bbci.co.uk/news/uk/rss.xml` |
| AI & Tech | 🤖 | `https://feeds.bbci.co.uk/news/technology/rss.xml` |
| Business | 💰 | `https://feeds.bbci.co.uk/news/business/rss.xml` |

```bash
curl -s -A "Mozilla/5.0" "https://feeds.bbci.co.uk/news/world/rss.xml" \
  | grep -E '<title>' \
  | sed -E 's/.*<title>//; s/<\/title>.*//; s/<!\[CDATA\[//g; s/\]\]>//g' \
  | tail -n +2 \
  | head -5
```

The first `<title>` is the feed name ("BBC News"), so `tail -n +2` skips it. Extract the remaining 5 item titles. Repeat for UK, Tech, and Business feeds.

Take only the **#1 headline** from each feed for the brief (keeps it scannable). Store the full 5-per-feed for the `📰 Daily News.md` entry.

### 6. Write the new day entry

- Determine the current date and day name for the heading: `[[DD-MM-YY ddd]]`
- Group under the current month header `## YYYY-MM` (create if missing)
- Add the day as a collapsed callout:

```markdown
> [!note]- [[DD-MM-YY ddd]]
> > ☀️/🌧️ weather summary
>
> > [!breaking] Tasks
> > - ⚠️ Overdue tasks first
> > - Today's tasks
>
> > [!news] Server Health
> > - Uptime: X days Xh, load X.XX
> > - Disk: XX% used
> > - Docker: XX containers running
>
> > [!news] 📰 News
> > - 🌍 World — #1 headline from BBC World
> > - 🇬🇧 UK — #1 headline from BBC UK
> > - 🤖 Tech — #1 headline from BBC Technology
> > - 💰 Business — #1 headline from BBC Business
```

- The weather line inside the callout should be a single `>` blockquote line
- Tasks section uses `[!breaking]` callout
- Server Health and News sections use `[!news]` callout
- News section gets the **top 1 headline per category** to keep it scannable
- Also write the **full 5-headlines-per-feed** to `📰 Daily News.md` as a separate collapsed entry (same `[[DD-MM-YY ddd]]` format, just news-only)
- **Add charm!** Emojis on every line — make weather descriptions fun (🌧️ drizzly, ☀️ crisp), use 🐳 for Docker, 💾 for disk, 📋 for tasks, 🖥️ for server, ⏱️ for uptime, 🌍/🇬🇧/🤖/💰 for news
- Set `unread: true` and update `updated:` in frontmatter on **both** files

### 7. Collapse the previous day

If there was a previous day entry at the top of either file (not inside a callout), wrap it in a `> [!note]- [[date]]` callout by prefixing all its lines with `>`.

## Example output

```markdown
## 2026-05

> [!note]- [[12-05-26 Tue]]
> > 🌦️ 9°C — patchy rain, dodgy jacket weather 🧥
>
> > [!breaking] Tasks 📋
> > - ⚠️ **🏗️ Server stabilisation** — overdue!
> > - 🏠 Check on server when you're home
>
> > [!news] Server Health 🖥️
> > - ⏱️ Up 4d 11h — humming along
> > - 💾 27% used — plenty of breathing room
> > - 🐳 25 containers, all healthy
> >
> > [!news] 📰 News
> > - 🌍 World — Ukraine talks resume, G7 pledges aid
> > - 🇬🇧 UK — New energy bill passes first reading
> > - 🤖 Tech — Anthropic drops Claude 5, beats GPT-5
> > - 💰 Business — BOE holds rates at 4.5%
```

---
name: emerge
description: Scan rough notes for buried ideas, themes, and connections — then surface them as a structured Emergent Ideas note with project suggestions.
user_invocable: true
---

# Emerge

Surfaces ideas hiding in `100 Rough Notes/`. Reads every note in the folder, extracts the core concepts, finds threads and connections between them, and writes an **Emergent Ideas** summary note. Helps you spot which random thoughts are worth turning into projects.

## Trigger

Use this skill when:
- The user asks to "emerge ideas", "surface my rough notes", "what's in my rough notes", or similar
- The user says `/skill:emerge`
- You notice `100 Rough Notes/` has accumulated several new notes since last check
- The user is looking for inspiration or deciding what to work on next

## Requirements

- Vault root auto-detected from `$PWD` or `$VAULT_ROOT`
- `100 Rough Notes/` folder must exist (will be created if missing)

## Step-by-step

### 1. Read all rough notes

```bash
ls "$VAULT_ROOT/100 Rough Notes/"*.md 2>/dev/null
```

If the folder doesn't exist or is empty, create it and write a note saying nothing to emerge yet.

For each `.md` file found, read its contents. Skip the frontmatter — focus on the body.

### 2. Analyse and connect

For each note, identify:
- **Core idea** — what's the one-sentence essence?
- **Vibe** — is this practical, ambitious, silly, genius? Be honest and fun about it.
- **Potential** — could this become a project? A one-off task? Nothing?

Then look across all notes for:
- **Connections** — do any ideas share a theme, tool, or goal?
- **Conflicts** — do any ideas contradict or compete?
- **Seeds** — which feel like the start of something bigger?

### 3. Write the emerge note

Create or update `📌 Emergent Ideas.md` at the vault root. Structure:

```markdown
---
created: {{date}}
updated: {{date}}
topic: emergent ideas
unread: true
---

> [!summary]- 🌱 Emergent Ideas
> A live snapshot of what's brewing in the rough notes. Updated whenever `/skill:emerge` runs.

## Current Crop ({{date}})

> [!note]- [[note-name]] — 💡 Core idea in 5 words
> > **Essence**: One-line summary of the idea
> > **Vibe**: 😤 Ambitious / 🤪 Unhinged / 🛠️ Practical / 💭 Half-baked
> > **Could be**: A project? A task? A rabbit hole?
> > **Connects to**: [[other-note]] (same theme)

> [!note]- [[another-note]] — 🔥 Hot take on something
> > **Essence**: ...
```

Then add a **Threads** section if connections were found:

```markdown
## 🧵 Threads

- **Theme: Homelab** — [[note-a]], [[note-b]], and [[note-c]] all touch on server stuff. Could bundle into a single project.
- **Theme: AI tinkering** — [[note-d]] and [[note-e]] are both about playing with LLMs.
```

And a **Recommendations** section:

```markdown
## 🎯 Recommendations

- **🚀 Ready to ship**: [[note-name]] — just needs a decision, no more research
- **📦 Project potential**: [[note-name]] — carve out a dedicated project folder
- **🗑️ Probably nothing**: [[note-name]] — fun thought, not worth pursuing
```

### 4. Style

- **Lots of emojis** — this is a creative, playful skill. Lean into it.
- **Honest but kind** — call out silly ideas warmly, celebrate promising ones.
- **Vary the section callout types** — `[!summary]` for the header, `[!note]-` for each idea.
- Set `unread: true` and update `updated:` in frontmatter.

## Example output

````markdown
## Current Crop (12-05-26)

> [!note]- [[server-idea]] — 🏗️ Pihole turbo mode
> > **Essence**: Make pihole do more — ad blocking + DNS-level tracker killing
> > **Vibe**: 🛠️ Practical, half-done
> > **Could be**: A weekend project (already in Todoist!)
> > **Connects to**: [[homelab-vision]] (same server)

> [!note]- [[homelab-vision]] — 🖥️ Ultimate media server
> > **Essence**: Build an unstoppable arr-stack with VPN, automation, the works
> > **Vibe**: 😤 Ambitious — you've basically done this already
> > **Could be**: A project doc to codify what's running
> > **Connects to**: [[server-idea]] (both live on that machine)

## 🧵 Threads

- **Homelab** 🔥 — [[server-idea]], [[homelab-vision]] — you're deep in server land. Write a master project note!

## 🎯 Recommendations

- **📦 Project potential**: [[homelab-vision]] — you've already built most of it. Document it as a project.
- **🚀 Ready to ship**: [[server-idea]] — pi-hole config tweak, knock it out this week.
````

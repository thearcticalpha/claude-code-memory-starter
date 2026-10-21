# Memory Protocol (Claude Code)

How this agent records durable memory. Claude Code has a built-in memory feature that
activates when a memory directory exists (this folder, symlinked into
`~/.claude/projects/<cwd>/memory`). This doc documents the conventions and reinforces
that memory should be written **routinely**, not only when asked.

## What a memory is

One fact per file, a markdown file in this folder, with frontmatter:

```markdown
---
name: <short-kebab-case-slug>
description: <one-line summary — used to decide relevance later>
metadata:
  type: user | feedback | project | reference
---

<the fact. For feedback/project, add **Why:** and **How to apply:** lines.
Link related memories with [[their-name]].>
```

## The four types

- **user** — who the human is (role, expertise, preferences, life context).
- **feedback** — how they want the agent to work (corrections + confirmed approaches). Include the *why*.
- **project** — ongoing work, goals, constraints not obvious from files. Convert relative dates to absolute.
- **reference** — pointers to external resources (URLs, accounts, where things live).

## The index

`MEMORY.md` is the index loaded every session — **one line per memory**:
`- [Title](file.md) — short hook`. Never put memory content in MEMORY.md itself.

## When to save (routinely)

Write a memory whenever you learn something that will still matter next session:
- A stable fact about the human or their preferences.
- Feedback/correction on how to work ("next time, do X").
- A project's goal, status, or a decision and its reasoning.
- Where something lives or how to reach a resource.

Before saving, check for an existing file that already covers it — update rather than
duplicate. Delete memories that turn out wrong. Don't save what a file/readme already
records, or what only matters to the current conversation.

## Backup

This folder is a git repo. A `Stop` hook commits every session end (that history is your
local backup) and pushes to any configured backups (a local mirror and/or a private GitHub
repo). Nothing here should contain secrets — see `.gitignore`.

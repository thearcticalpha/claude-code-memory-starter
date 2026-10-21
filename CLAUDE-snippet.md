# CLAUDE.md snippet — paste into ~/.claude/CLAUDE.md

Adding this reinforces routine memory-writing (the built-in feature plus an explicit nudge).

```markdown
## Memory (record routinely)

You have a persistent memory folder, symlinked into `~/.claude/projects/<cwd>/memory`
and auto-backed-up by a Stop hook (local git history + optional mirror/GitHub).

- **Proactively save durable facts** — don't wait to be asked. When you learn something
  that will matter next session (who I am, a preference, a project's status, where a thing
  lives), write it to a memory file and add a one-line pointer to `MEMORY.md`.
- One fact per file, with frontmatter (`name`, `description`, `metadata.type`), type one of
  `user | feedback | project | reference`. See `memory-protocol.md` in the memory folder.
- Update an existing memory instead of duplicating; delete ones that turn out wrong.
- Never write secrets (passwords, API keys) into memory.
```

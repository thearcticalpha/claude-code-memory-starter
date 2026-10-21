# Claude Code Memory Starter

Give Claude Code a **persistent memory that records automatically every session** — with a
**local backup** by default, and an optional private GitHub mirror.

## What it does

- Symlinks Claude Code's memory folder (`~/.claude/projects/<cwd>/memory`) to a git repo you control.
- Installs a **Stop hook** that, on *every* session end, commits your memory (that git history
  **is** your local backup) and pushes to any backup you set up. You don't have to remember to do it.
- Seeds a `MEMORY.md` index and a `memory-protocol.md` describing how memories are written.

Backup options (pick any combination):
1. **Local only** (default) — every session is a git commit in the repo. No GitHub, no internet.
2. **Local mirror** — a second copy (a bare git repo) somewhere else, e.g. an external drive.
3. **Private GitHub** — optional off-machine backup that survives a lost/wiped laptop.

## Install

```bash
# 1. Get this kit onto the machine (clone your starter repo, or copy this folder), then:
cd claude-code-memory-starter        # wherever this folder lives
bash install.sh
```

It will ask a few questions (all have sensible defaults, and you can just press Enter):

| Prompt | Meaning | Example |
|---|---|---|
| Local path for the memory repo | Where memory lives on disk | `~/claude-code-memory` |
| Extra LOCAL backup location | A second copy (external drive, etc.) — blank to skip | `/Volumes/Backup/memory.git` |
| PRIVATE GitHub repo URL | Optional off-machine backup — **blank for local-only** | `https://github.com/you/my-memory.git` |
| Directory you launch Claude Code from | Memory attaches to this folder | `~` |
| Git name / email | For commit history | |

Non-interactive is supported too — set the same values as env vars before `bash install.sh`
(see the header of `install.sh`).

## After install

1. **Launch Claude Code from the directory you chose** (default your home folder) so memory attaches.
2. Paste the block from `CLAUDE-snippet.md` into `~/.claude/CLAUDE.md` so the agent writes memory routinely.
3. If you added a GitHub repo, make it **private** — memory can contain personal context.

## Verify it's working

- After a session ends, run `git -C ~/claude-code-memory log --oneline` — you should see an `auto: …` commit.
- Check the hook exists: it's under `hooks.Stop` in `~/.claude/settings.json`.

## Undo

```bash
bash uninstall.sh
```
Removes the Stop hook and the memory symlink. Your memory repo (and any backups) are left intact.

## Notes

- The installer is safe to re-run and won't clobber existing `settings.json` (it merges).
- Memory is **per-launch-directory**. If you use several project folders, re-run the installer
  with `CLAUDE_CWD=<that folder>` for each (they can all point at the same repo).

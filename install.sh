#!/bin/bash
# Claude Code Memory Starter — deterministic auto-backup installer.
#
# Reproduces this setup:
#   ~/.claude/projects/<encoded-cwd>/memory  --symlink-->  a local git repo
#   a Stop hook in ~/.claude/settings.json  --commit+push every session end-->  your private GitHub repo
#
# So every Claude Code session's memory is recorded AND backed up automatically,
# without the agent having to remember to do it.
#
# Safe + idempotent: merges into settings.json (never clobbers), backs up any
# existing real memory dir before symlinking, and skips work already done.
#
# Usage (interactive):   bash install.sh
# Usage (non-interactive, override via env):
#   REPO_URL=https://github.com/you/my-memory.git \
#   REPO_DIR="$HOME/claude-code-memory" \
#   CLAUDE_CWD="$HOME" \
#   GIT_NAME="Jane Doe" GIT_EMAIL="jane@example.com" \
#   bash install.sh
set -uo pipefail

echo "=== Claude Code Memory Starter — installer ==="

# --- prerequisites ---
command -v git >/dev/null 2>&1 || { echo "ERROR: git is required."; exit 1; }

ask() { # ask VAR "prompt" "default"
  local __var="$1" __prompt="$2" __default="${3:-}" __cur
  eval "__cur=\${$__var:-}"
  if [ -n "$__cur" ]; then return; fi           # already set via env
  if [ -t 0 ]; then
    read -r -p "$__prompt${__default:+ [$__default]}: " __ans || true
    eval "$__var=\"\${__ans:-$__default}\""
  else
    eval "$__var=\"$__default\""
  fi
}

ask REPO_DIR     "Local path for the memory git repo" "$HOME/claude-code-memory"
ask LOCAL_BACKUP "Extra LOCAL backup location (e.g. an external drive) — blank to skip" ""
ask REPO_URL     "PRIVATE GitHub repo URL — OPTIONAL, blank = local-only, no GitHub" ""
ask CLAUDE_CWD   "Directory you launch Claude Code from (memory attaches to this)" "$HOME"
ask GIT_NAME   "Git name for commits" "$(git config user.name 2>/dev/null || echo '')"
ask GIT_EMAIL  "Git email for commits" "$(git config user.email 2>/dev/null || echo '')"
ask BRANCH     "Default branch to push" "main"

REPO_DIR="${REPO_DIR/#\~/$HOME}"
CLAUDE_CWD="${CLAUDE_CWD/#\~/$HOME}"
[ -n "${LOCAL_BACKUP:-}" ] && LOCAL_BACKUP="${LOCAL_BACKUP/#\~/$HOME}"
KIT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo
echo "Plan:"
echo "  repo dir      : $REPO_DIR   (its .git history IS a local backup)"
echo "  local backup  : ${LOCAL_BACKUP:-(none)}"
echo "  github remote : ${REPO_URL:-(none — local-only)}"
echo "  memory attaches to cwd: $CLAUDE_CWD"
echo "  branch        : $BRANCH"
echo

# --- 1) create/prepare the memory repo ---
if [ ! -d "$REPO_DIR/.git" ]; then
  if [ -n "$REPO_URL" ] && git clone "$REPO_URL" "$REPO_DIR" 2>/dev/null && [ -n "$(ls -A "$REPO_DIR" 2>/dev/null)" ]; then
    echo "cloned existing repo into $REPO_DIR"
  else
    echo "initializing new repo at $REPO_DIR"
    mkdir -p "$REPO_DIR"
    git -C "$REPO_DIR" init -q
    git -C "$REPO_DIR" symbolic-ref HEAD "refs/heads/$BRANCH" 2>/dev/null || true
    [ -n "$REPO_URL" ] && git -C "$REPO_DIR" remote add origin "$REPO_URL" 2>/dev/null || true
  fi
else
  echo "using existing repo at $REPO_DIR"
fi

# per-repo git identity (never global)
[ -n "$GIT_NAME" ]  && git -C "$REPO_DIR" config user.name  "$GIT_NAME"
[ -n "$GIT_EMAIL" ] && git -C "$REPO_DIR" config user.email "$GIT_EMAIL"

# seed MEMORY.md + .gitignore if the repo doesn't have them yet
[ -f "$REPO_DIR/MEMORY.md" ]  || cp "$KIT_DIR/MEMORY.md"  "$REPO_DIR/MEMORY.md"
[ -f "$REPO_DIR/.gitignore" ] || cp "$KIT_DIR/.gitignore" "$REPO_DIR/.gitignore"
[ -f "$REPO_DIR/memory-protocol.md" ] || cp "$KIT_DIR/memory-protocol.md" "$REPO_DIR/memory-protocol.md" 2>/dev/null || true

# --- 1b) optional LOCAL backup: a bare git repo (can live on an external drive) ---
# This is a real second copy with full history — survives deleting the working repo dir.
if [ -n "${LOCAL_BACKUP:-}" ]; then
  if [ ! -d "$LOCAL_BACKUP/objects" ] && [ ! -f "$LOCAL_BACKUP/HEAD" ]; then
    mkdir -p "$LOCAL_BACKUP"
    git init --bare -q "$LOCAL_BACKUP" && echo "created local backup repo at $LOCAL_BACKUP"
  fi
  if git -C "$REPO_DIR" remote | grep -qx localbak; then
    git -C "$REPO_DIR" remote set-url localbak "$LOCAL_BACKUP"
  else
    git -C "$REPO_DIR" remote add localbak "$LOCAL_BACKUP"
  fi
  echo "local backup remote 'localbak' -> $LOCAL_BACKUP"
fi

# --- 2) symlink the Claude Code memory dir to the repo ---
enc="${CLAUDE_CWD//\//-}"                 # /Users/jane -> -Users-jane
MEM_PARENT="$HOME/.claude/projects/$enc"
MEM_LINK="$MEM_PARENT/memory"
mkdir -p "$MEM_PARENT"

if [ -L "$MEM_LINK" ]; then
  cur="$(readlink "$MEM_LINK")"
  if [ "$cur" != "$REPO_DIR" ]; then
    echo "re-pointing existing symlink ($cur -> $REPO_DIR)"; rm "$MEM_LINK"; ln -s "$REPO_DIR" "$MEM_LINK"
  else
    echo "symlink already correct"
  fi
elif [ -e "$MEM_LINK" ]; then
  bak="$MEM_LINK.bak-$(date +%Y%m%d%H%M%S)"
  echo "WARNING: $MEM_LINK is a real dir; backing up to $bak then symlinking"
  mv "$MEM_LINK" "$bak"
  # preserve any pre-existing memory files by copying them into the repo
  cp -a "$bak/." "$REPO_DIR/" 2>/dev/null || true
  ln -s "$REPO_DIR" "$MEM_LINK"
else
  ln -s "$REPO_DIR" "$MEM_LINK"
  echo "symlinked $MEM_LINK -> $REPO_DIR"
fi

# --- 3) install the deterministic Stop hook (merge, don't clobber) ---
SETTINGS="$HOME/.claude/settings.json"
mkdir -p "$HOME/.claude"
# Hook: ALWAYS commit locally (that history is your local backup), then push to
# EVERY configured remote (localbak and/or github) best-effort. Works with zero remotes.
HOOK_CMD="cd $REPO_DIR && git add -A && (git diff --staged --quiet || git commit -m \"auto: \$(date '+%Y-%m-%d %H:%M:%S')\" >/dev/null 2>&1); for r in \$(git remote 2>/dev/null); do git push \"\$r\" $BRANCH >/dev/null 2>&1 || true; done; true"
python3 - "$SETTINGS" "$HOOK_CMD" <<'PY'
import json, os, sys
path, cmd = sys.argv[1], sys.argv[2]
data = {}
if os.path.exists(path):
    try: data = json.load(open(path))
    except Exception: data = {}
hooks = data.setdefault("hooks", {})
stop = hooks.setdefault("Stop", [])
# dedupe: skip if a memory-backup hook already present
already = any(
    isinstance(g, dict)
    for g in stop
    for h in g.get("hooks", [])
    if isinstance(h, dict) and "git add -A" in h.get("command", "") and "claude" in h.get("command", "").lower()
)
if not already:
    stop.append({"matcher": "", "hooks": [{"type": "command", "command": cmd}]})
    json.dump(data, open(path, "w"), indent=2)
    print("Stop hook installed in", path)
else:
    print("Stop hook already present; left as-is")
PY

# --- 4) first commit + push to whatever remotes exist (best-effort) ---
git -C "$REPO_DIR" add -A
if ! git -C "$REPO_DIR" diff --staged --quiet; then
  git -C "$REPO_DIR" commit -q -m "init: memory workspace" || true
fi
for r in $(git -C "$REPO_DIR" remote 2>/dev/null); do
  if git -C "$REPO_DIR" push -u "$r" "$BRANCH" 2>/dev/null; then
    echo "pushed to $r"
  else
    echo "NOTE: initial push to '$r' failed (repo missing / not authed) — the Stop hook will retry each session."
  fi
done

echo
echo "=== DONE ==="
echo "• Memory dir  : $MEM_LINK -> $REPO_DIR"
echo "• Local backup: the repo's own git history (every session is a commit)$([ -n "${LOCAL_BACKUP:-}" ] && echo " + mirror at $LOCAL_BACKUP")"
[ -n "$REPO_URL" ] && echo "• GitHub      : $REPO_URL (keep it PRIVATE — memory can hold personal context)"
echo "• Backup runs : automatically on EVERY Claude Code session end (Stop hook). No GitHub required."
echo "• IMPORTANT   : launch Claude Code from  $CLAUDE_CWD  so memory attaches."
echo "• Reinforce   : add the block in CLAUDE-snippet.md to ~/.claude/CLAUDE.md so the agent writes memory routinely."

#!/bin/bash
# Remove the memory Stop hook and the memory symlink. Leaves your memory repo + backups intact.
set -uo pipefail
ask() { local __v="$1" __p="$2" __d="${3:-}"; local __c; eval "__c=\${$__v:-}"; [ -n "$__c" ] && return
  if [ -t 0 ]; then read -r -p "$__p${__d:+ [$__d]}: " __a || true; eval "$__v=\"\${__a:-$__d}\""; else eval "$__v=\"$__d\""; fi; }

ask CLAUDE_CWD "Directory Claude Code was launched from (memory attaches there)" "$HOME"
CLAUDE_CWD="${CLAUDE_CWD/#\~/$HOME}"
enc="${CLAUDE_CWD//\//-}"
MEM_LINK="$HOME/.claude/projects/$enc/memory"

# 1) remove the symlink (only if it IS a symlink — never delete a real dir)
if [ -L "$MEM_LINK" ]; then rm "$MEM_LINK"; echo "removed symlink $MEM_LINK"; else echo "no symlink at $MEM_LINK (left as-is)"; fi

# 2) strip the memory backup hook from settings.json (merge-safe)
SETTINGS="$HOME/.claude/settings.json"
if [ -f "$SETTINGS" ]; then
python3 - "$SETTINGS" <<'PY'
import json, sys
p = sys.argv[1]
try: d = json.load(open(p))
except Exception: raise SystemExit("could not parse settings.json")
stop = d.get("hooks", {}).get("Stop", [])
def is_mem(g):
    return any(isinstance(h, dict) and "git add -A" in h.get("command","") and "claude" in h.get("command","").lower()
               for h in g.get("hooks", []))
new = [g for g in stop if not (isinstance(g, dict) and is_mem(g))]
if len(new) != len(stop):
    if new: d["hooks"]["Stop"] = new
    else: d["hooks"].pop("Stop", None)
    json.dump(d, open(p, "w"), indent=2)
    print("removed memory Stop hook from", p)
else:
    print("no memory Stop hook found")
PY
fi
echo "Done. Your memory repo and backups were NOT touched."

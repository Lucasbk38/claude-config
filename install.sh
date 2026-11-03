#!/bin/sh
# Copies this Claude Code config into ~/.claude (existing files are backed up as *.bak),
# merges settings.json (this repo's keys win, other keys are kept) and installs the mods.
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
DEST="$HOME/.claude"
mkdir -p "$DEST"

command -v jq >/dev/null 2>&1 || { echo "jq is required (macOS: brew install jq, Debian/Ubuntu: apt install jq)"; exit 1; }

backup() { [ -e "$1" ] && cp -R "$1" "$1.bak" || true; }

backup "$DEST/CLAUDE.md";        cp "$HERE/claude/CLAUDE.md" "$DEST/CLAUDE.md"
backup "$DEST/statusline";       mkdir -p "$DEST/statusline" && cp "$HERE"/claude/statusline/* "$DEST/statusline/"
[ -f "$DEST/statusline/agent-parents.json" ] || echo '{}' > "$DEST/statusline/agent-parents.json"
mkdir -p "$DEST/skills" && cp -R "$HERE"/claude/skills/* "$DEST/skills/"

# agent wiki: a live symlink, so agents edit the repo copy directly (the SessionEnd hook commits and pushes it)
[ -e "$DEST/wiki" ] && [ ! -L "$DEST/wiki" ] && mv "$DEST/wiki" "$DEST/wiki.bak"
ln -sfn "$HERE/wiki" "$DEST/wiki"
[ -s "$HERE/wiki/agents.json" ] || echo '{}' > "$HERE/wiki/agents.json"

[ -f "$DEST/settings.json" ] || echo '{}' > "$DEST/settings.json"
backup "$DEST/settings.json"
jq -s '.[0] * .[1]' "$DEST/settings.json.bak" "$HERE/claude/settings.json" > "$DEST/settings.json"

# the mods are public repos: registering them is enough, Claude Code installs the enabled ones
if command -v claude >/dev/null 2>&1; then
  for r in claude-agent-tree claude-syntax-cmd claude-plot-pane; do
    claude plugin marketplace add "Lucasbk38/$r" || true
  done
  claude plugin install agent-tree@claude-agent-tree || true
  claude plugin install syntax-cmd@claude-syntax-cmd || true
  claude plugin install plot-pane@claude-plot-pane || true
else
  echo "claude not found: install Claude Code, then run this script again to install the mods."
fi

echo "Done. Restart Claude Code."

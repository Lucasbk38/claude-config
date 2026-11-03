# claude-config

My global [Claude Code](https://claude.com/claude-code) setup, to copy onto another machine in one command. **Private repo**: it holds personal instructions.

## What is in it

| Path | Goes to |
| --- | --- |
| `claude/CLAUDE.md` | `~/.claude/CLAUDE.md` (global instructions) |
| `claude/settings.json` | merged into `~/.claude/settings.json` (model, effort, status lines, plugins) |
| `claude/statusline/` | `~/.claude/statusline/` (status line + subagent panel, same as [claude-statusline](https://github.com/Lucasbk38/claude-statusline)) |
| `claude/skills/` | `~/.claude/skills/` (graphify, dispatch) |
| `wiki/` | symlinked at `~/.claude/wiki`: shared memory of all agents (start at `wiki/INDEX.md`). Auto-committed and pushed by the SessionEnd hook |
| mods | installed from their own repos: [agent-tree](https://github.com/Lucasbk38/claude-agent-tree), [syntax-cmd](https://github.com/Lucasbk38/claude-syntax-cmd), [plot-pane](https://github.com/Lucasbk38/claude-plot-pane) |

Not included on purpose: login and account data (`~/.claude.json`), history, projects, caches, per-machine paths and the project-specific `autoMode` text.

## Install

macOS / Linux (needs `gh` logged in, `jq`, `claude`):

```sh
gh repo clone Lucasbk38/claude-config && sh claude-config/install.sh
```

Windows: run the same two commands in Git Bash or WSL. Existing files are saved as `*.bak` first, and `settings.json` is merged, not replaced.

After install, set the plot folder on that machine: `/config`, then `plot-pane`, then `dir`.

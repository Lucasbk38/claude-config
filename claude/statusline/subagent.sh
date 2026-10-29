#!/bin/sh
# One row per subagent: name + description on the left, model · effort · tokens as a right-aligned table.
# Colors and icons come from theme.json, shared with the main status line.
# Parent links come from agent-parents.json (written by the agent-tree mod). The panel only lists top-level
# agents, so each top-level row also carries its descendants as extra tree lines.
[ -f ~/.claude/statusline/agent-parents.json ] || echo '{}' > ~/.claude/statusline/agent-parents.json
jq -c --slurpfile theme ~/.claude/statusline/theme.json --slurpfile parents ~/.claude/statusline/agent-parents.json '
  $theme[0] as $t
  | def esc(c): "\u001b[38;5;\(c)m";
  def rst: "\u001b[0m";
  def spaces(n): if n > 0 then [range(n)] | map(" ") | join("") else "" end;
  def rpad(n): tostring | if length > n then .[0:n-1] + "…" else . + spaces(n - length) end;
  def lpad(n): tostring | if length > n then .[0:n-1] + "…" else spaces(n - length) + . end;
  def family: ascii_downcase | (first(("opus", "sonnet", "haiku", "fable") as $f | select(test($f)) | $f) // "other");
  def short_model:
    sub("^claude-"; "") | sub("-[0-9]{8}$"; "")
    | capture("^(?<f>[a-z]+)-(?<v>[0-9]+(-[0-9]+)?)") as $m
    | ($m.f[0:1] | ascii_upcase) + $m.f[1:] + " " + ($m.v | gsub("-"; "."));
  def tokens: if . >= 1000 then "\((. / 100 | floor) / 10)k" else tostring end;
  ($parents[0] // {}) as $p
  | .tasks as $tasks
  | ([$tasks[].id]) as $ids
  | def par($id): $p[$id] as $x | if $x != null and ($ids | index($x)) != null then $x else null end;
  def islast($id): [$ids[] | select(par(.) == par($id))] | last == $id;
  def chain($id): par($id) as $q | if $q == null then [] else chain($q) + [$q] end;
  def tree_prefix($id): chain($id) as $a
    | if ($a | length) == 0 then ""
      else ($a[1:] | map(if islast(.) then "    " else "│   " end) | join("")) + (if islast($id) then "└── " else "├── " end) end;
  def dfs($id): $tasks[] | select(par(.id) == $id) | ., dfs(.id);
  ((.columns // 100) - 6) as $cols
  | def line:
      (.model // "" | family) as $fam
      | $t.models[$fam] as $m
      | (if .model then (.model | try short_model catch .) else "…" end) as $model
      | ((.effort // "default") | tostring) as $effort
      | ($t.efforts[$effort] // $t.efforts.default) as $e
      | (.tokenCount // 0 | tokens) as $tok
      | tree_prefix(.id) as $tp
      | ([18 - ($tp | length), 8] | max) as $nw
      # right block, fixed width: icon + " " + model(10) + "  " + icon + " " + effort(7) + "  " + tokens(6) = 29
      | 29 as $rw
      | ([($cols - $rw - 18 - 4), 0] | max) as $dw
      | esc(240) + $tp + rst + "\u001b[1m● " + ((.name // .agentType // "agent") | rpad($nw)) + rst
        + " " + esc(250) + ((.label // .description // "") | rpad($dw)) + rst
        + "  " + esc($m.color) + $m.icon + " " + ($model | rpad(10)) + rst
        + "  " + esc($e.color) + $e.icon + " " + ($effort | rpad(7)) + rst
        + "  " + esc(244) + ($tok | lpad(6)) + rst;
  $tasks[]
  | . as $task
  | {id, content: ([($task | line)] + [if par($task.id) == null then dfs($task.id) | line else empty end] | join("\n"))}'

#!/bin/sh
# Status line modeled on the user's starship prompt: directory, git branch, model + effort, context, plan usage
# Segments are packed into rows: when a row is full, the next segment goes to a new row (no "…" truncation).
export LC_ALL=en_US.UTF-8
input=$(cat)
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd')
model=$(echo "$input" | jq -r '.model.display_name')
effort=$(echo "$input" | jq -r '.effort.level // empty')
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
# absolute context size in tokens: what /context counts (input + cache), else derived from the percentage
ctx_tokens=$(echo "$input" | jq -r '(.context_window.current_usage // null) as $u | if $u then ($u.input_tokens // 0) + ($u.cache_creation_input_tokens // 0) + ($u.cache_read_input_tokens // 0) elif .context_window.used_percentage and .context_window.context_window_size then (.context_window.used_percentage * .context_window.context_window_size / 100 | floor) else empty end')
five=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
five_reset=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
week=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
week_reset=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')
dir=$(echo "$cwd" | sed "s|^$HOME|~|")
branch=$(git -C "$cwd" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null)
repo=$(git -C "$cwd" --no-optional-locks rev-parse --show-toplevel 2>/dev/null)
repo=${repo##*/}
# model + effort colors and icons from the shared theme
model_id=$(echo "$input" | jq -r ".model.id // .model.display_name // empty")
mc=$(jq -r --arg id "$model_id" ".models[(\$id | ascii_downcase | first((\"opus\", \"sonnet\", \"haiku\", \"fable\") as \$f | select(test(\$f)) | \$f) // \"other\")] | \"\\(.color) \\(.icon)\"" ~/.claude/statusline/theme.json)
ec=$(jq -r --arg e "$effort" ".efforts[\$e] // .efforts.default | \"\\(.color) \\(.icon)\"" ~/.claude/statusline/theme.json)
# terminal width (stty on the claude tty, fallback $COLUMNS; 0 = unknown, no wrapping)
cols=$(stty -f "/dev/$(ps -o tty= -p $PPID | tr -d ' ')" size 2>/dev/null | awk '{print $2}')
[ "${cols:-0}" -ge 20 ] 2>/dev/null || cols=${COLUMNS:-0}

# green < 50%, yellow < 80%, red otherwise
pct_color() {
  p=${1%.*}
  if [ "$p" -ge 80 ]; then echo 196; elif [ "$p" -ge 50 ]; then echo 220; else echo 34; fi
}

# 167000 -> 167k, 1250000 -> 1.2M
tokens() {
  awk -v n="$1" 'BEGIN { if (n >= 1000000) printf "%.1fM", n / 1000000; else if (n >= 1000) printf "%.0fk", n / 1000; else printf "%d", n }'
}

# time left until an epoch timestamp, e.g. 2h10m or 3d4h
until_reset() {
  left=$(( $1 - $(date +%s) ))
  [ "$left" -le 0 ] && return
  d=$(( left / 86400 )); h=$(( left % 86400 / 3600 )); m=$(( left % 3600 / 60 ))
  if [ "$d" -gt 0 ]; then printf '%dd%dh' "$d" "$h"
  elif [ "$h" -gt 0 ]; then printf '%dh%02dm' "$h" "$m"
  else printf '%dm' "$m"; fi
}

# --- segment packing ---------------------------------------------------------
# add JOINER COLOR TEXT [EXTRA_WIDTH]
#   JOINER: n = first of a row, s = " │ " (may break), w = space (may break), g = space (never breaks)
#   COLOR: 256-color index, empty = default; EXTRA_WIDTH: for wide glyphs (emoji count 2 cols)
NL='
'
TAB='	'
items=""
add() {
  if [ -n "$2" ]; then c=$(printf '\033[38;5;%sm%s\033[0m' "$2" "$3"); else c=$3; fi
  items="$items$1$TAB${4:-0}$TAB$3$TAB$c$NL"
}
# addwords JOINER COLOR TEXT: one segment per word so long text wraps between words
addwords() {
  j=$1; for wd in $3; do add "$j" "$2" "$wd"; j=w; done
}
# print the segments as rows no wider than cols - 3 (Claude indents the status line by 2)
pack() {
  W=$((cols - 3))
  sepc=$(printf ' \033[38;5;240m│\033[0m ')
  printf %s "$items" | {
    cur=0
    while IFS="$TAB" read -r j x p c; do
      w=$(( ${#p} + x ))
      case $j in s) jw=3 js=$sepc;; w|g) jw=1 js=' ';; *) jw=0 js='';; esac
      if [ "$cur" -gt 0 ] && [ "$j" != g ] && [ "$cols" -gt 0 ] && [ $((cur + jw + w)) -gt "$W" ]; then
        printf '\n'; cur=0
      fi
      [ "$cur" -gt 0 ] && { printf %s "$js"; cur=$((cur + jw)); }
      printf %s "$c"; cur=$((cur + w))
    done
  }
  printf '\n'
  items=""
}

# --- line 1: dir, repo, branch │ model effort │ ctx │ 5h │ wk  cup ----------------
add n 208 "$(printf '\357\201\273') $dir"
[ -n "$repo" ] && add w 80 "$(printf '\357\220\201') $repo"
[ -n "$branch" ] && add w 179 "$(printf '\356\202\240') $branch"
add s "${mc%% *}" "${mc#* } $model"
[ -n "$effort" ] && add g "${ec%% *}" "${ec#* } $effort"
if [ -n "$used" ]; then
  if [ "${used%.*}" = 0 ] && [ "${ctx_tokens:-0}" = 0 ]; then
    add s "" ctx; add g 244 "–"
  else
    add s "" ctx; add g "$(pct_color "$used")" "$(printf '%.0f%%' "$used")"
    # same blue/purple as the token counts in /context
    [ -n "$ctx_tokens" ] && add g 147 "$(tokens "$ctx_tokens")"
  fi
fi
usage() { # label pct reset
  add s "" "$1"; add g "$(pct_color "$2")" "$(printf '%.0f%%' "$2")"
  [ -n "$3" ] && r=$(until_reset "$3") && [ -n "$r" ] && add g 244 "$(printf '\363\260\221\223') $r"
}
[ -n "$five" ] && usage 5h "$five" "$five_reset"
[ -n "$week" ] && usage wk "$week" "$week_reset"
sid=$(echo "$input" | jq -r '.session_id // empty')
# claude pid from the session id (PPID may be an intermediate shell, unlike the pid the caffeine mod uses)
cpid=$(/usr/bin/grep -l "\"sessionId\":\"$sid\"" "$HOME"/.claude/sessions/*.json 2>/dev/null | head -1); cpid=$(basename "${cpid:-$PPID}" .json)
# caffeine state (refreshes every statusLine.refreshInterval s): on = filled gold, off = outline dim
if [ -f "$HOME/.claude/caffeine/important/$cpid" ]; then add g 214 "$(printf '\357\203\264')"; else add g 240 "$(printf '\363\260\233\212')"; fi
pack

# --- line 2 (dim): short id · wiki name · waits ------------------------------
if [ -n "$sid" ]; then
  add n 244 "$(printf '\363\260\222\213') $(printf %.8s "$sid")"
  # one jq: wiki name, who I wait on (pid, short, to, what), and who waits on me (shorts)
  info=$(jq -r --arg id "$sid" '(.[$id].name // ""), ((.[$id].waiting_on // [])[] | "W\t\(.pid)\t\(.to)\t\(.what)\t\(.short)"), ([.[] | select(.waiting_on[]?.short == ($id[0:8])) | .short] | if length > 0 then "B\t" + join(",") else empty end)' ~/.claude/wiki/agents.json 2>/dev/null)
  name=$(printf %s "$info" | sed -n 1p)
  [ -n "$name" ] && { add g 244 "·"; addwords w 244 "$name"; }
  # only waits whose target session is still busy count (otherwise the wait is over)
  wl=""
  for w in $(printf %s "$info" | awk -F'\t' '$1=="W"{print $2}'); do
    [ -f "$HOME/.claude/sessions/$w.json" ] && [ "$(jq -r .status "$HOME/.claude/sessions/$w.json" 2>/dev/null)" != idle ] || continue
    l=$(printf %s "$info" | awk -F'\t' -v p="$w" '$1=="W"&&$2==p{print $3 " " $5 ": " $4}')
    wl="${wl:+$wl, }$l"
  done
  [ -n "$wl" ] && { add w 110 "⏳ ←" 1; addwords g 110 "${wl%% *}"; addwords w 110 "${wl#* }"; }
  by=$(printf %s "$info" | awk -F'\t' '$1=="B"{print $2}'); [ -n "$by" ] && add w 110 "👥 $by" 1
fi
pack

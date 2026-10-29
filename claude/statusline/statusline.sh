#!/bin/sh
# Status line modeled on the user's starship prompt: directory, git branch, model + effort, context, plan usage
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
# model + effort colors and icons from the shared theme
model_id=$(echo "$input" | jq -r ".model.id // .model.display_name // empty")
mc=$(jq -r --arg id "$model_id" ".models[(\$id | ascii_downcase | first((\"opus\", \"sonnet\", \"haiku\", \"fable\") as \$f | select(test(\$f)) | \$f) // \"other\")] | \"\\(.color) \\(.icon)\"" ~/.claude/statusline/theme.json)
ec=$(jq -r --arg e "$effort" ".efforts[\$e] // .efforts.default | \"\\(.color) \\(.icon)\"" ~/.claude/statusline/theme.json)
sep=' \033[38;5;240m│\033[0m'

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

usage() { # label pct reset
  printf "$sep"' %s \033[38;5;%sm%.0f%%\033[0m' "$1" "$(pct_color "$2")" "$2"
  [ -n "$3" ] && r=$(until_reset "$3") && [ -n "$r" ] && printf ' \033[38;5;244m󰑓 %s\033[0m' "$r"
}

printf '\033[38;5;208m\357\201\273 %s\033[0m' "$dir"
[ -n "$branch" ] && printf ' \033[38;5;179m\356\202\240 %s\033[0m' "$branch"
printf "$sep"' \033[38;5;%sm%s %s\033[0m' "${mc%% *}" "${mc#* }" "$model"
[ -n "$effort" ] && printf ' \033[38;5;%sm%s %s\033[0m' "${ec%% *}" "${ec#* }" "$effort"
if [ -n "$used" ]; then
  [ "${used%.*}" = 0 ] && [ "${ctx_tokens:-0}" = 0 ] && { printf "$sep"' ctx \033[38;5;244m–\033[0m'; } || {
  printf "$sep"' ctx \033[38;5;%sm%.0f%%\033[0m' "$(pct_color "$used")" "$used"
  # same blue/purple as the token counts in /context
  [ -n "$ctx_tokens" ] && printf ' \033[38;5;147m%s\033[0m' "$(tokens "$ctx_tokens")"
  }
fi
[ -n "$five" ] && usage 5h "$five" "$five_reset"
[ -n "$week" ] && usage wk "$week" "$week_reset"
printf '\n'

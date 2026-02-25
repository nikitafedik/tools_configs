#!/usr/bin/env bash
# Starship-inspired status line for Claude Code
# Mirrors ~/.config/starship.toml style: soft green user, dim separators, green dir, blue time

input=$(cat)
cwd=$(echo "$input" | jq -r '.cwd // .workspace.current_dir // empty')
cwd="${cwd:-$(pwd)}"
model=$(echo "$input" | jq -r '.model.display_name // empty')
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
used_tokens=$(echo "$input" | jq -r '.context_window.used // empty')

# ANSI color codes matching starship.toml
RESET='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'
# #a1e3b3 -> closest 256-color: 121 (light green); use truecolor
GREEN_SOFT='\033[1;38;2;161;227;179m'   # #a1e3b3 bold  (username / model)
GREEN_DIR='\033[1;38;2;95;217;128m'     # #5fd980 bold  (directory)
BLUE_BOLD='\033[1;34m'                  # bold blue     (time / context)
DIM_SEP='\033[2;37m'                    # dim white     (| separators)

# Shorten path: replace $HOME with
home_sym=""
display_cwd="${cwd/#$HOME/$home_sym}"

# Git branch (fast, no locks)
git_branch=""
if git_ref=$(GIT_OPTIONAL_LOCKS=0 git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null); then
  git_branch="$git_ref"
elif git_ref=$(GIT_OPTIONAL_LOCKS=0 git -C "$cwd" rev-parse --short HEAD 2>/dev/null); then
  git_branch="$git_ref"
fi

# Build the line
printf "${GREEN_SOFT}$(whoami)${RESET}"

printf " ${DIM_SEP}|${RESET} ${GREEN_DIR}${display_cwd}${RESET}"

if [ -n "$git_branch" ]; then
  printf " ${DIM_SEP}|${RESET} ${BOLD}● ${git_branch}${RESET}"
fi

if [ -n "$model" ]; then
  printf " ${DIM_SEP}|${RESET} ${GREEN_SOFT}${model}${RESET}"
fi

if [ -n "$used_tokens" ] && [ -n "$used" ]; then
  used_int=$(printf "%.0f" "$used")
  used_k=$(awk "BEGIN {printf \"%.1f\", $used_tokens/1000}")
  printf " ${DIM_SEP}|${RESET} ${BLUE_BOLD}ctx: ${used_k}k / ${used_int}%%${RESET}"
elif [ -n "$used" ]; then
  used_int=$(printf "%.0f" "$used")
  printf " ${DIM_SEP}|${RESET} ${BLUE_BOLD}ctx: ${used_int}%%${RESET}"
fi

printf " ${DIM_SEP}|${RESET} ${BLUE_BOLD}$(date +%T)${RESET}"

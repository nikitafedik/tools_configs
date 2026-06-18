# Track foreground command lifecycle for tmux status markers.
[[ -n ${ZSH_VERSION:-} ]] || return 0
[[ -o interactive ]] || return 0
[[ -n ${TMUX:-} && -n ${TMUX_PANE:-} ]] || return 0
[[ -x "$HOME/.local/bin/tmux-ergo-pane-status" ]] || return 0

autoload -Uz add-zsh-hook

_ergo_tmux_status_preexec() {
  emulate -L zsh
  [[ -n ${TMUX_PANE:-} ]] || return 0
  command "$HOME/.local/bin/tmux-ergo-pane-status" start "$1" >/dev/null 2>&1 || true
}

_ergo_tmux_status_precmd() {
  local exit_code=$?
  emulate -L zsh
  [[ -n ${TMUX_PANE:-} ]] || return 0
  command "$HOME/.local/bin/tmux-ergo-pane-status" finish "$exit_code" >/dev/null 2>&1 || true
}

add-zsh-hook preexec _ergo_tmux_status_preexec
add-zsh-hook precmd _ergo_tmux_status_precmd

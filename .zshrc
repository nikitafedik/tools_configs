# === PATH ===
export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$HOME/soft:$HOME/soft/scripts:$PATH

unsetopt AUTO_NAME_DIRS

ZIM_HOME=~/.zim

ENABLE_CORRECTION="true"

setopt INC_APPEND_HISTORY
setopt globdots

# === Completion ===

# Completer chain: expand aliases, complete files/dirs, handle typos
zstyle ':completion:*' completer _expand _complete _ignored _approximate

# Highlight files and directories using LS_COLORS
eval "$(dircolors -b)"
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}

# File and directory behavior
zstyle ':completion:*:cd:*' tag-order local-directories directory-stack path-directories
zstyle ':completion:*:vim:*' file-patterns '*.txt' '*.md' '*.py' '*.sh'
zstyle ':completion:*:files' file-sort modification
zstyle ':completion:*' users
zstyle ':completion:*:named-directories' format '%d -> %p'
zstyle ':completion:*:hashed-directories' format '%d -> %p'

# Menu selection with scrolling
zstyle ':completion:*' menu select
zstyle ':completion:*' select-prompt '%SScrolling... currently at %p%s'
zstyle ':completion:*:*:*:users' ignored-patterns '*'

# Case-insensitive matching
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'

# Partial path matching
zstyle ':completion:*' expand prefix suffix

# === FZF ===
[[ -f ~/.fzf.zsh ]] && source ~/.fzf.zsh
[ -f /usr/share/doc/fzf/examples/key-bindings.zsh ] && source /usr/share/doc/fzf/examples/key-bindings.zsh
[ -f /usr/share/doc/fzf/examples/completion.zsh ] && source /usr/share/doc/fzf/examples/completion.zsh

# === Zimfw ===

# Download zimfw plugin manager if missing.
if [[ ! -e ${ZIM_HOME}/zimfw.zsh ]]; then
  curl -fsSL --create-dirs -o ${ZIM_HOME}/zimfw.zsh \
      https://github.com/zimfw/zimfw/releases/latest/download/zimfw.zsh
fi

# Install missing modules and update ${ZIM_HOME}/init.zsh if missing or outdated.
if [[ ! ${ZIM_HOME}/init.zsh -nt ${ZDOTDIR:-${HOME}}/.zimrc ]]; then
  source ${ZIM_HOME}/zimfw.zsh init -q
fi

# Initialize modules.
source ${ZIM_HOME}/init.zsh
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=238'

# === Prompt ===
precmd () { echo -n "\x1b]1337;CurrentDir=$(pwd)\x07" }
eval "$(starship init zsh)"

# === Editor ===
export EDITOR=fresh
export VISUAL=fresh
export FCEDIT=fresh

# === Conda ===
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$('/home/nfedik/miniconda3/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "/home/nfedik/miniconda3/etc/profile.d/conda.sh" ]; then
        . "/home/nfedik/miniconda3/etc/profile.d/conda.sh"
    else
        export PATH="/home/nfedik/miniconda3/bin:$PATH"
    fi
fi
unset __conda_setup

# === Optional tools (loaded if present) ===

# Ruby gems
[ -d "$HOME/.gems" ] && export GEM_HOME="$HOME/.gems" && export PATH="$HOME/.gems/bin:$PATH"

# NVM
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"

# Cargo / Rust
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"

# Local env
[ -f "$HOME/.local/bin/env" ] && . "$HOME/.local/bin/env"

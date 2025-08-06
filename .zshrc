# If you come from bash you might have to change your $PATH.
# created/modified by FNS (nikitafedik@gmail.com)
# === PATH ===
export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$HOME/SOFT:$PATH
unsetopt AUTO_NAME_DIRS
ZIM_HOME=~/.zim

zstyle ':omz:update' mode reminder  # just remind me to update when it's time
zstyle ':omz:update' frequency 13
# DISABLE_MAGIC_FUNCTIONS="true" # Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_LS_COLORS="true" # Uncomment the following line to disable colors in ls.
# DISABLE_AUTO_TITLE="true" # Uncomment the following line to disable auto-setting terminal title.
ENABLE_CORRECTION="true" # Uncomment the following line to enable command auto-correction.

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"


# === MY  FUNCTIONS and SETTINGS  ====

setopt INC_APPEND_HISTORY # append to history immediately
hash -r # remove hashed dirs to declutter hash table; needed for custom bookmark functionality

function virtualenv_info() {
    if [[ -n "$VIRTUAL_ENV" ]]; then
        echo "($(basename $VIRTUAL_ENV)) "
    fi
}

# autoload -Uz compinit && compinit
fpath=(~/.zsh/functions/bookmarks $fpath)

# Autoload the common function and the bookmark functions.
autoload -Uz init_bookmarks ba br b

# Source the common file to ensure BOOKMARK_FILE and BOOKMARKS_LOADED are set.
source ~/.zsh/functions/bookmarks/bookmark_common

# Initialize bookmarks on shell startup.
init_bookmarks

# Completer chain: expand aliases, complete files/dirs, handle typos
zstyle ':completion:*' completer _expand _complete _ignored _approximate

# Highlight files and directories using LS_COLORS
eval "$(dircolors -b)"
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}

# File and directory behavior
zstyle ':completion:*:cd:*' tag-order local-directories directory-stack path-directories
zstyle ':completion:*:vim:*' file-patterns '*.txt' '*.md' '*.py' '*.sh'
zstyle ':completion:*:files' file-sort modification
zstyle ':completion:*:named-directories' format '%d -> %p'
zstyle ':completion:*:hashed-directories' format '%d -> %p'
# Include hidden files in completions
setopt globdots

# Enable menu selection with custom scrolling prompt
zstyle ':completion:*' menu select
zstyle ':completion:*' select-prompt '%SScrolling... currently at %p%s'
zstyle ':completion:*:*:*:users' ignored-patterns '*'
# Case-insensitive matching for completions
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'

# Partial path matching for more intuitive navigation
zstyle ':completion:*' expand prefix suffix

# FUZZY FINDER for HISTORY
[[ -f ~/.fzf.zsh ]] && source ~/.fzf.zsh

# # === ZIMFW ===

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

# === END ZIMFW ===antidote load

# CUSTOM PROMPT
eval "$(starship init zsh)"

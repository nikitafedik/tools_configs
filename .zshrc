# If you come from bash you might have to change your $PATH.
# created/modified by FNS (nikitafedik@gmail.com)
# === PATH ===
export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$HOME/soft:$HOME/soft/scripts:$HOME/.local/share/gem/ruby/3.2.0/bin:$PATH

unsetopt AUTO_NAME_DIRS
# hash -d -r

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
# hash -r # remove hashed dirs to declutter hash table; needed for custom bookmark functionality

function virtualenv_info() {
    if [[ -n "$VIRTUAL_ENV" ]]; then
        echo "($(basename $VIRTUAL_ENV)) "
    fi
}

# # autoload -Uz compinit && compinit
# fpath=(~/.zsh/functions/bookmarks $fpath)
# 
# # Autoload the common function and the bookmark functions.
# autoload -Uz init_bookmarks ba br b
# 
# # Source the common file to ensure BOOKMARK_FILE and BOOKMARKS_LOADED are set.
# source ~/.zsh/functions/bookmarks/bookmark_common
# 
# # Initialize bookmarks on shell startup.
# init_bookmarks



# FUZZY FINDER for HISTORY
[ -f /usr/share/doc/fzf/examples/key-bindings.zsh ] && source /usr/share/doc/fzf/examples/key-bindings.zsh

# FZF completion
[ -f /usr/share/doc/fzf/examples/completion.zsh ] && source /usr/share/doc/fzf/examples/completion.zsh


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
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=238' #works best with black bg
source ${ZIM_HOME}/init.zsh
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=238'
# === END ZIMFW ===


precmd () { echo -n "\x1b]1337;CurrentDir=$(pwd)\x07" }

# # Completer chain: expand aliases, complete files/dirs, handle typos
# zstyle ':completion:*' completer _expand _complete _ignored _approximate
# 
# # Highlight files and directories using LS_COLORS
# eval "$(dircolors -b)"
# zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
# 
# File and directory behavior
zstyle ':completion:*:cd:*' tag-order local-directories directory-stack path-directories
zstyle ':completion:*:vim:*' file-patterns '*.txt' '*.md' '*.py' '*.sh'
zstyle ':completion:*:files' file-sort modification
zstyle ':completion:*' users
zstyle ':completion:*:named-directories' format '%d -> %p'
zstyle ':completion:*:hashed-directories' format '%d -> %p'
# Include hidden files in completions
setopt globdots

# Enable menu selection with custom scrolling prompt
zstyle ':completion:*' menu select
zstyle ':completion:*' select-prompt '%SScrolling... currently at %p%s'
zstyle ':completion:*:*:*:users' ignored-patterns '*'
#Case-insensitive matching for completions
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'

# Partial path matching for more intuitive navigation
zstyle ':completion:*' expand prefix suffix

# CUSTOM PROMPT
eval "$(starship init zsh)"

export EDITOR="~/soft/scripts/m"
export VISUAL="~/soft/scripts/m"

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$('/home/nfedik/soft/miniconda3/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "/home/nfedik/soft/miniconda3/etc/profile.d/conda.sh" ]; then
        . "/home/nfedik/soft/miniconda3/etc/profile.d/conda.sh"
    else
        export PATH="/home/nfedik/soft/miniconda3/bin:$PATH"
    fi
fi
unset __conda_setup
# <<< conda initialize <<<


eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
export DISABLE_AUTOUPDATER=1

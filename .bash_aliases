# Local aliases loaded by ~/.bashrc

# Modern terminal tools
if command -v eza >/dev/null 2>&1; then
  alias ls='eza --icons=auto --group-directories-first'
  alias ll='eza --icons=auto --group-directories-first --git -lah'
  alias la='eza --icons=auto --group-directories-first -a'
  alias l='eza --icons=auto --group-directories-first -F'
  alias lt='eza --icons=auto --group-directories-first --tree --level=2'
fi

if command -v bat >/dev/null 2>&1; then
  alias cat='bat --paging=never'
fi

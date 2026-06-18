#!/usr/bin/env bash
set -euo pipefail

echo "── tmux modern setup ──"

# Install tpm (tmux plugin manager)
if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
  echo "Installing tpm..."
  git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
else
  echo "tpm already installed, updating..."
  cd ~/.tmux/plugins/tpm && git pull && cd -
fi

# Backup existing config
if [ -f "$HOME/.tmux.conf" ]; then
  backup="$HOME/.tmux.conf.bak-$(date +%s)"
  cp ~/.tmux.conf "$backup"
  echo "Backed up existing config to $backup"
fi

# Copy new config
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cp "$SCRIPT_DIR/tmux.conf" ~/.tmux.conf
echo "Installed tmux.conf to ~/.tmux.conf"

# Install plugins (works even outside tmux)
echo "Installing plugins..."
~/.tmux/plugins/tpm/bin/install_plugins

echo ""
echo "── Done! ──"
echo ""
echo "Quick start:"
echo "  tmux                        → new session"
echo "  tmux new -s work            → named session"
echo "  tmux attach -t work         → reattach"
echo ""
echo "Inside tmux:"
echo "  Prefix = Ctrl+b"
echo "  Prefix + |       → split vertical"
echo "  Prefix + -       → split horizontal"
echo "  Prefix + c       → new tab"
echo "  Ctrl+←/→         → switch tabs"
echo "  Alt+n / Alt+p    → switch tabs"
echo "  Alt+0 / Alt+w    → choose window"
echo "  Alt+←/→/↑/↓      → switch panes"
echo "  Ctrl+↑/↓         → resize panes"
echo "  Mouse             → click panes, drag to resize, scroll"
echo "  Prefix + r       → reload config"
echo ""

# Shell Configs

Portable shell, Git, tmux, prompt, preview, and terminal helper config.

## Laptop Bootstrap

```bash
git clone https://github.com/nikitafedik/tools_configs.git ~/github/shell-configs
bash ~/github/shell-configs/install.sh
```

The installer backs up existing files before copying replacements. It syncs:

- zsh, zim, Git, Conda, Starship, Zellij config
- tmux config plus tmux pane-status helpers
- local aliases for Codex/tmux helpers
- `codex-plot-preview` helpers for WSL/Windows plot previews

Optional installs such as `tmux`, `zellij`, and `tpm` are prompted.

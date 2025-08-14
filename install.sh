#!/usr/bin/env bash
# Minimal per-component installer. Requirements:
# 1) If target already exists -> skip.
# 2) Failures are reported; script continues.
# 3) Ask before EACH install (no upfront batch questions).
# 4) Keep it short & easy to read.

set -e
REPO_ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR=${INSTALL_DIR:-"$HOME/soft"}
mkdir -p "$INSTALL_DIR" "$HOME/.config" >/dev/null 2>&1 || true

ask() { read -r -p "$1 [y/N]: " _r; [[ $_r =~ ^[Yy]$ ]]; }
note() { printf '[%s] %s\n' "$1" "$2"; }
ok() { note OK "$1"; }
warn() { note WARN "$1" >&2; }
fail() { note FAIL "$1" >&2; }

# MICRO -----------------------------------------------------------------
micro_dir="$INSTALL_DIR/micro"
if [ -d "$micro_dir" ] && [ -x "$micro_dir/micro" ]; then
    ok "micro already installed -> $micro_dir (skip)"
else
    if ask "Install micro editor?"; then
        mkdir -p "$micro_dir" || true
        if ( cd "$micro_dir" && curl -fsSL https://getmic.ro | bash ); then
            ln -sfn "$micro_dir/micro" "$HOME/bin/micro" 2>/dev/null || true
            ok "micro installed"
        else
            fail "micro install failed"
        fi
    else
        warn "micro skipped by user"
    fi
fi

# RANGER ----------------------------------------------------------------
ranger_cfg="$HOME/.config/ranger"
if command -v ranger >/dev/null 2>&1 && [ -d "$ranger_cfg" ]; then
    ok "ranger already present (skip)"
else
    if ask "Install ranger (pip --user)?"; then
        py=""; for c in python3 python; do command -v "$c" >/dev/null 2>&1 && py="$c" && break; done
        if [ -z "$py" ]; then fail "python not found"; else
            if ! command -v pip3 >/dev/null 2>&1 && ! command -v pip >/dev/null 2>&1; then "$py" -m ensurepip --user >/dev/null 2>&1 || true; fi
            (pip3 install --user ranger-fm 2>/dev/null || pip install --user ranger-fm 2>/dev/null) && ok "ranger installed" || warn "ranger pip install issue"
            [ -d "$ranger_cfg" ] || mkdir -p "$ranger_cfg"
            cp -a "$REPO_ROOT_DIR/ranger/"* "$ranger_cfg/" 2>/dev/null || true
        fi
    else
        warn "ranger skipped by user"
    fi
fi

# ZELLIJ ----------------------------------------------------------------
zellij_cfg="$HOME/.config/zellij"
if command -v zellij >/dev/null 2>&1 && [ -f "$zellij_cfg/config.kdl" ]; then
    ok "zellij already present (skip)"
else
    if ask "Install zellij (cargo)?"; then
        if command -v cargo >/dev/null 2>&1; then
            if cargo install --locked zellij >/dev/null 2>&1; then ok "zellij installed"; else warn "cargo zellij install failed"; fi
        else
            warn "cargo not found (skip zellij)"
        fi
        [ -d "$zellij_cfg" ] || mkdir -p "$zellij_cfg"
        cp -a "$REPO_ROOT_DIR/.config/zellij/config.kdl" "$zellij_cfg/config.kdl" 2>/dev/null || true
    else
        warn "zellij skipped by user"
    fi
fi

# STARSHIP ---------------------------------------------------------------
starship_cfg="$HOME/.config/starship.toml"
if command -v starship >/dev/null 2>&1 && [ -f "$starship_cfg" ]; then
    ok "starship already present (skip)"
else
    if ask "Install starship prompt?"; then
        tmp=/tmp/starship-inst.sh
        if curl -fsSL https://starship.rs/install.sh -o "$tmp" && chmod +x "$tmp" && "$tmp" -y -b "$HOME/.local/bin" >/dev/null 2>&1; then
            ok "starship installed"
        else
            warn "starship install failed"
        fi
        cp -a "$REPO_ROOT_DIR/starship.toml" "$starship_cfg" 2>/dev/null || true
    else
        warn "starship skipped by user"
    fi
fi

# ALIASES ---------------------------------------------------------------
alias_src="$REPO_ROOT_DIR/alias_scripts"
alias_dst="$INSTALL_DIR/aliases"
if [ -d "$alias_dst" ]; then
    ok "aliases already exist (skip)"
else
    if [ -d "$alias_src" ]; then
        mkdir -p "$alias_dst"
        cp -a "$alias_src/"* "$alias_dst/" 2>/dev/null || true
        ok "aliases copied -> $alias_dst (add to PATH if needed)"
    fi
fi

echo
echo "Done. Suggested PATH addition:"
echo "  export PATH=\"$HOME/bin:$HOME/.local/bin:$alias_dst:\$PATH\""
echo
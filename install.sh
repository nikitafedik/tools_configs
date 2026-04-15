#!/usr/bin/env bash
# Shell environment installer. Syncs zsh, starship, zellij, and dotfiles.
# Asks before each install. Backs up existing files before overwriting.
# Usage: install.sh [-v] [-c]

set -e
set -o pipefail

VERBOSE=0
CHECK_EXISTING=0

usage() {
    cat <<EOF
Usage: $(basename "$0") [options]

Options:
  -v, --verbose           Show each shell command
  -c, --check-existing    Verify existing installs before skipping
  -h, --help              Show this help
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        -v|--verbose)        VERBOSE=1 ;;
        -c|--check-existing) CHECK_EXISTING=1 ;;
        -h|--help)           usage; exit 0 ;;
        *)                   printf 'Unknown option: %s\n' "$1" >&2; usage >&2; exit 1 ;;
    esac
    shift
done

[ "$VERBOSE" -eq 1 ] && export PS4='[CMD] ' && set -x

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="${INSTALL_DIR:-$HOME/soft}"
mkdir -p "$INSTALL_DIR" "$HOME/.config" "$HOME/bin" "$HOME/.local/bin"

# ── Output helpers ──────────────────────────────────────────────────

section() { printf '\n\033[1;34m── %s ──\033[0m\n' "$1"; }
ok()      { printf '  \033[32m+\033[0m %s\n' "$1"; }
info()    { printf '  \033[2m>\033[0m %s\n' "$1"; }
warn()    { printf '  \033[33m!\033[0m %s\n' "$1" >&2; }
fail()    { printf '  \033[31mx\033[0m %s\n' "$1" >&2; }

ask() {
    printf '\n  \033[1m?\033[0m %s [y/N] ' "$1"
    read -r _r
    [[ $_r =~ ^[Yy]$ ]]
}

# ── Helpers ─────────────────────────────────────────────────────────

APT_UPDATED=0
install_package() {
    local pkg="$1"
    if command -v apt-get >/dev/null 2>&1; then
        if [ "$APT_UPDATED" -eq 0 ]; then
            info "Updating apt package index"
            if sudo apt-get update -qq; then APT_UPDATED=1; else warn "apt-get update failed"; return 1; fi
        fi
        info "Installing $pkg via apt"
        sudo apt-get install -y -qq "$pkg"
    elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y "$pkg"
    elif command -v pacman >/dev/null 2>&1; then
        sudo pacman -S --needed --noconfirm "$pkg"
    elif command -v brew >/dev/null 2>&1; then
        brew install "$pkg"
    else
        warn "No supported package manager found"; return 1
    fi
}

sync_config() {
    local src="$1" dst="$2" label="${3:-config}"
    if [ ! -f "$src" ]; then
        warn "$label: source missing ($src)"
        return 1
    fi
    mkdir -p "$(dirname "$dst")"
    if [ -f "$dst" ] && cmp -s "$src" "$dst"; then
        ok "$label: already up to date"
        return 0
    fi
    if [ -f "$dst" ]; then
        local backup="${dst}.bak-$(date +%s)"
        cp "$dst" "$backup" && info "$label: backed up to $backup"
    fi
    cp "$src" "$dst" && ok "$label: synced -> $dst"
}

skip_if_installed() {
    local name="$1"; shift
    if [ "$CHECK_EXISTING" -eq 1 ] && [ $# -gt 0 ]; then
        if "$@" >/dev/null 2>&1; then
            ok "$name: already installed (verified)"
            return 0
        else
            warn "$name: installed but verification failed"
            return 1
        fi
    fi
    ok "$name: already installed"
    return 0
}

is_ubuntu() {
    [ -r /etc/os-release ] && grep -qE '^ID="?ubuntu"?$|^ID_LIKE=.*ubuntu' /etc/os-release
}

# ── 1. ZSH + ZIMFW ─────────────────────────────────────────────────

section "Zsh + Zimfw"

if command -v zsh >/dev/null 2>&1; then
    skip_if_installed "zsh" zsh --version
else
    if ask "Install zsh?"; then
        install_package zsh && ok "zsh installed" || fail "zsh install failed"
    else
        warn "zsh: skipped"
    fi
fi

# Ubuntu needs skip_global_compinit to avoid conflict with zimfw
if is_ubuntu; then
    local_zshenv="$HOME/.zshenv"
    if [ -f "$local_zshenv" ] && grep -qx 'skip_global_compinit=1' "$local_zshenv"; then
        ok "zshenv: skip_global_compinit already set"
    else
        info "Ubuntu detected: setting skip_global_compinit=1"
        sync_config "$REPO_ROOT/.zshenv" "$local_zshenv" "zshenv"
    fi
fi

# ── 2. STARSHIP ─────────────────────────────────────────────────────

section "Starship prompt"

if command -v starship >/dev/null 2>&1; then
    skip_if_installed "starship" starship --version
else
    if ask "Install starship prompt?"; then
        tmp=/tmp/starship-inst.sh
        if curl -fsSL --retry 3 https://starship.rs/install.sh -o "$tmp" && chmod +x "$tmp"; then
            "$tmp" -y -b "$HOME/.local/bin" && ok "starship installed" || fail "starship install failed"
        else
            fail "starship: download failed"
        fi
    else
        warn "starship: skipped"
    fi
fi

# ── 3. FRESH EDITOR ─────────────────────────────────────────────────

section "Fresh editor"

if command -v fresh >/dev/null 2>&1; then
    ok "fresh: found at $(command -v fresh)"
else
    warn "fresh: not found"
    info "Install with: sudo apt install fresh-editor"
    info "Or check: https://sinelaw.github.io/fresh/"
fi

# ── 4. ZELLIJ (optional) ────────────────────────────────────────────

section "Zellij (optional)"

if command -v zellij >/dev/null 2>&1; then
    skip_if_installed "zellij" zellij --version
else
    info "Zellij is a terminal multiplexer (like tmux). Skip if you don't need one."
    if ask "Install zellij via cargo? (slow, ~5min compile)"; then
        if command -v cargo >/dev/null 2>&1; then
            cargo install --locked zellij && ok "zellij installed" || fail "zellij: cargo install failed"
        else
            info "Cargo not found. Install Rust first: curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
            warn "zellij: skipped (no cargo)"
        fi
    else
        warn "zellij: skipped"
    fi
fi

# Sync zellij config if installed
if command -v zellij >/dev/null 2>&1; then
    sync_config "$REPO_ROOT/.config/zellij/config.kdl" "$HOME/.config/zellij/config.kdl" "zellij config"
fi

# ── 5. DOTFILES ──────────────────────────────────────────────────────

section "Dotfiles"

sync_config "$REPO_ROOT/.zshrc"            "$HOME/.zshrc"            "zshrc"
sync_config "$REPO_ROOT/.zimrc"            "$HOME/.zimrc"            "zimrc"
sync_config "$REPO_ROOT/.zshenv"           "$HOME/.zshenv"           "zshenv"
sync_config "$REPO_ROOT/.gitconfig"        "$HOME/.gitconfig"        "gitconfig"
sync_config "$REPO_ROOT/.condarc"          "$HOME/.condarc"          "condarc"
sync_config "$REPO_ROOT/starship.toml"     "$HOME/.config/starship.toml"  "starship config"
sync_config "$REPO_ROOT/.config/git/ignore" "$HOME/.config/git/ignore"    "global gitignore"

# Patch hardcoded /home/nfedik/ paths to current user
if [ "$HOME" != "/home/nfedik" ]; then
    for f in "$HOME/.zshrc" "$HOME/.gitconfig"; do
        if grep -q '/home/nfedik/' "$f" 2>/dev/null; then
            sed -i "s|/home/nfedik/|$HOME/|g" "$f"
            info "Patched home paths in $(basename "$f")"
        fi
    done
fi

# ── TIPS ──────────────────────────────────────────────────────────────

section "Done"

printf '\n'
printf '  \033[1mTools\033[0m\n'
printf '  %-12s %s\n' "fresh"    "Terminal editor (EDITOR/VISUAL are set in .zshrc)"
printf '  %-12s %s\n' "starship" "Prompt theme   (config: ~/.config/starship.toml)"
printf '  %-12s %s\n' "zimfw"    "Zsh plugins    (update: zimfw update)"
if command -v zellij >/dev/null 2>&1; then
printf '  %-12s %s\n' "zellij"   "Multiplexer    (start: zellij, lock mode: Ctrl+g)"
fi
printf '\n'
printf '  \033[1mPATH\033[0m (already in .zshrc):\n'
printf '  export PATH="$HOME/bin:$HOME/.local/bin:$HOME/soft:$PATH"\n'
printf '\n'

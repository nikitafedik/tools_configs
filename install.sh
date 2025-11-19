#!/usr/bin/env bash
# Minimal per-component installer. Requirements:
# 1) If target already exists -> skip.
# 2) Failures are reported; script continues.
# 3) Ask before EACH install (no upfront batch questions).
# 4) Keep it short & easy to read.

set -e
set -o pipefail

SCRIPT_PREFIX="INSTALL"
VERBOSE=0
CHECK_EXISTING=0

usage() {
    local script_name
    script_name="$(basename "$0")"
    cat <<EOF
Usage: $script_name [options]

Options:
  -v, --verbose               Show each shell command with a [CMD] prefix
  -c, --check-existing        Verify existing installs before skipping them
      --skip-existing         Alias for --check-existing
  -h, --help                  Show this help text and exit
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        -v|--verbose)
            VERBOSE=1
            ;;
        -c|--check-existing|--skip-existing)
            CHECK_EXISTING=1
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            printf '[%s/ERR] Unknown option: %s\n' "$SCRIPT_PREFIX" "$1" >&2
            usage >&2
            exit 1
            ;;
    esac
    shift
done

if [ "$VERBOSE" -eq 1 ]; then
    export PS4='[CMD] '
    set -x
fi

REPO_ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR=${INSTALL_DIR:-"$HOME/soft"}
mkdir -p "$INSTALL_DIR" "$HOME/.config" || true

ask() {
    printf '==== [%s/ASK] %s ====\n' "$SCRIPT_PREFIX" "$1"
    read -r -p "[y/N]: " _r
    [[ $_r =~ ^[Yy]$ ]]
}
note() { printf '==== [%s/%s] %s ====\n' "$SCRIPT_PREFIX" "$1" "$2"; }
ok() { note OK "$1"; }
warn() { note WARN "$1" >&2; }
fail() { note FAIL "$1" >&2; }
run_with_sudo() {
    if command -v sudo >/dev/null 2>&1; then
        sudo "$@"
    else
        "$@"
    fi
}

APT_UPDATED=0
install_package() {
    local pkg="$1"
    if command -v apt-get >/dev/null 2>&1; then
        if [ "$APT_UPDATED" -eq 0 ]; then
            note INFO "Updating apt package index"
            if run_with_sudo apt-get update; then
                APT_UPDATED=1
            else
                warn "apt-get update failed"
                return 1
            fi
        fi
        note INFO "Installing $pkg via apt-get"
        run_with_sudo apt-get install -y "$pkg"
        return $?
    elif command -v dnf >/dev/null 2>&1; then
        note INFO "Installing $pkg via dnf"
        run_with_sudo dnf install -y "$pkg"
        return $?
    elif command -v yum >/dev/null 2>&1; then
        note INFO "Installing $pkg via yum"
        run_with_sudo yum install -y "$pkg"
        return $?
    elif command -v pacman >/dev/null 2>&1; then
        note INFO "Installing $pkg via pacman"
        run_with_sudo pacman -S --needed --noconfirm "$pkg"
        return $?
    elif command -v brew >/dev/null 2>&1; then
        note INFO "Installing $pkg via brew"
        brew install "$pkg"
        return $?
    fi
    warn "No supported package manager available to install $pkg"
    return 1
}

skip_if_verified() {
    local component="$1"
    shift
    if [ "$CHECK_EXISTING" -eq 1 ] && [ $# -gt 0 ]; then
        if "$@"; then
            ok "$component already installed (verified) -> skip"
            return 0
        else
            warn "$component installed but verification failed; reinstalling"
            return 1
        fi
    fi
    ok "$component already installed -> skip"
    return 0
}

sync_config() {
    local src="$1"
    local dst="$2"
    local label="${3:-config}"
    if [ ! -f "$src" ]; then
        warn "$label source missing -> $src"
        return 1
    fi
    local dst_dir
    dst_dir="$(dirname "$dst")"
    [ -d "$dst_dir" ] || mkdir -p "$dst_dir"
    if [ -f "$dst" ] && cmp -s "$src" "$dst"; then
        ok "$label already up to date -> $dst"
        return 0
    fi
    if [ -f "$dst" ]; then
        local backup="${dst}.bak-$(date +%s)"
        if cp "$dst" "$backup"; then
            note INFO "Backup created for $label -> $backup"
        else
            warn "Failed to backup $label -> $dst"
        fi
    fi
    if cp "$src" "$dst"; then
        ok "$label synced -> $dst"
        return 0
    fi
    warn "Failed to copy $label -> $dst"
    return 1
}

is_ubuntu() {
    if [ -r /etc/os-release ]; then
        if grep -Eq '^ID="?ubuntu"?$' /etc/os-release; then
            return 0
        fi
        if grep -Eq '^ID_LIKE=.*ubuntu' /etc/os-release; then
            return 0
        fi
    fi
    return 1
}

ensure_ubuntu_zshenv() {
    if ! is_ubuntu; then
        return 0
    fi
    local zshenv="$HOME/.zshenv"
    note INFO "Ubuntu detected -> ensuring skip_global_compinit=1 in $zshenv"
    if [ -f "$zshenv" ] && grep -qx 'skip_global_compinit=1' "$zshenv"; then
        ok "$zshenv already sets skip_global_compinit=1"
        return 0
    fi
    if [ -f "$zshenv" ]; then
        local backup="${zshenv}.bak-$(date +%s)"
        if cp "$zshenv" "$backup"; then
            note INFO "Backup created for zshenv -> $backup"
        else
            warn "Failed to backup existing $zshenv"
        fi
    fi
    if printf 'skip_global_compinit=1\n' > "$zshenv"; then
        ok "Configured skip_global_compinit=1 in $zshenv"
        return 0
    fi
    warn "Failed to update $zshenv"
    return 1
}

# MICRO -----------------------------------------------------------------
micro_dir="$INSTALL_DIR/micro"
if [ -e "$micro_dir" ] && [ ! -d "$micro_dir" ]; then
    mv "$micro_dir" "${micro_dir}.old-$(date +%s)" || true
fi
micro_skip=0
if [ -d "$micro_dir" ] && [ -x "$micro_dir/micro" ]; then
    if skip_if_verified "micro" "$micro_dir/micro" --version; then
        micro_skip=1
    fi
fi
if [ "$micro_skip" -eq 0 ]; then
    if ask "Install micro editor?"; then
        mkdir -p "$micro_dir" || true
        if ( cd "$micro_dir" && curl -fsSL --retry 3 --retry-delay 2 https://getmic.ro | bash ); then
            ln -sfn "$micro_dir/micro" "$HOME/bin/micro" || true
            ok "micro installed"
        else
            fail "micro install failed"
        fi
    else
        warn "micro skipped by user"
    fi
fi

# ZSH -------------------------------------------------------------------
zsh_cfg="$HOME/.zshrc"
zsh_skip=0
if command -v zsh >/dev/null 2>&1; then
    if skip_if_verified "zsh" zsh --version; then
        zsh_skip=1
    fi
fi
if [ "$zsh_skip" -eq 0 ]; then
    if ask "Install zsh shell via package manager?"; then
        if install_package zsh; then
            ok "zsh installed"
        else
            warn "zsh installation failed"
        fi
    else
        warn "zsh installation declined"
    fi
fi
sync_config "$REPO_ROOT_DIR/.zshrc" "$zsh_cfg" "zsh rc"
sync_config "$REPO_ROOT_DIR/.zimrc" "$HOME/.zimrc" "zim config"
ensure_ubuntu_zshenv

# RANGER ----------------------------------------------------------------
ranger_cfg="$HOME/.config/ranger"
ranger_skip=0
if command -v ranger >/dev/null 2>&1 && [ -d "$ranger_cfg" ]; then
    if skip_if_verified "ranger" ranger --version; then
        ranger_skip=1
    fi
fi
if [ "$ranger_skip" -eq 0 ]; then
    if ask "Install ranger (pipx)?"; then
        if ! command -v pipx >/dev/null 2>&1; then
            warn "pipx not detected. Install pipx (https://pipx.pypa.io) and re-run (ranger skipped)"
        else
            if pipx install --force ranger-fm; then
                ok "ranger installed via pipx"
                [ -d "$ranger_cfg" ] || mkdir -p "$ranger_cfg"
                cp -a "$REPO_ROOT_DIR/ranger/"* "$ranger_cfg/" || true
            else
                warn "pipx ranger install failed"
            fi
        fi
    else
        warn "ranger skipped by user"
    fi
fi

# CARGO (on-demand) -----------------------------------------------------
ensure_cargo() {
    if command -v cargo >/dev/null 2>&1; then return 0; fi
    if ask "Install Rust toolchain (cargo)?"; then
        if curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y; then
            # shellcheck disable=SC1091
            [ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"
            if command -v cargo >/dev/null 2>&1; then
                ok "cargo installed"
                return 0
            else
                fail "cargo install failed"
                return 1
            fi
        else
            fail "cargo install failed (network or script error)"
            return 1
        fi
    else
        warn "cargo install declined"
        return 1
    fi
}

# ZELLIJ ----------------------------------------------------------------
zellij_cfg="$HOME/.config/zellij"
zellij_skip=0
if command -v zellij >/dev/null 2>&1 && [ -f "$zellij_cfg/config.kdl" ]; then
    if skip_if_verified "zellij" zellij --version; then
        zellij_skip=1
    fi
fi
if [ "$zellij_skip" -eq 0 ]; then
    if ask "Install zellij (cargo)?"; then
        if command -v cargo >/dev/null 2>&1 || ensure_cargo; then
            if cargo install --locked zellij; then ok "zellij installed"; else warn "cargo zellij install failed"; fi
        else
            warn "Skipping zellij (cargo unavailable)"
        fi
        [ -d "$zellij_cfg" ] || mkdir -p "$zellij_cfg"
        cp -a "$REPO_ROOT_DIR/.config/zellij/config.kdl" "$zellij_cfg/config.kdl" || true
    else
        warn "zellij skipped by user"
    fi
fi

# STARSHIP ---------------------------------------------------------------
starship_cfg="$HOME/.config/starship.toml"
starship_skip=0
if command -v starship >/dev/null 2>&1; then
    if skip_if_verified "starship" starship --version; then
        starship_skip=1
    fi
fi
if [ "$starship_skip" -eq 0 ]; then
    if ask "Install starship prompt?"; then
        tmp=/tmp/starship-inst.sh
        if curl -fsSL --retry 3 --retry-delay 2 https://starship.rs/install.sh -o "$tmp" && chmod +x "$tmp" && "$tmp" -y -b "$HOME/.local/bin"; then
            ok "starship installed"
        else
            warn "starship install failed"
        fi
    else
        warn "starship skipped by user"
    fi
fi
sync_config "$REPO_ROOT_DIR/starship.toml" "$starship_cfg" "starship config"

# ALIASES ---------------------------------------------------------------
alias_src="$REPO_ROOT_DIR/alias_scripts"
alias_dst="$INSTALL_DIR/aliases"
aliases_ready=0
if [ -d "$alias_dst" ]; then
    if skip_if_verified "aliases" test -x "$alias_dst/rng"; then
        aliases_ready=1
    fi
fi
if [ "$aliases_ready" -eq 0 ]; then
    if [ -d "$alias_src" ]; then
        mkdir -p "$alias_dst"
        cp -a "$alias_src/"* "$alias_dst/" || true
        ok "aliases copied -> $alias_dst (add to PATH if needed)"
        # Add rng alias wrapper if not present
        if [ ! -f "$alias_dst/rng" ]; then
            printf '#!/usr/bin/env bash
ranger "$@"
' > "$alias_dst/rng" && chmod +x "$alias_dst/rng"
            ok "added rng alias"
        fi
    fi
fi

printf '\n'
note INFO "Done. Suggested PATH addition:"
note INFO "  export PATH=\"$HOME/bin:$HOME/.local/bin:$alias_dst:\$PATH\""
printf '\n'
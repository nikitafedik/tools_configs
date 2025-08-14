#!/usr/bin/env bash

# Simplified installer (no system package managers) for:
#   micro (via curl https://getmic.ro | bash)
#   ranger (pip --user install ranger-fm)
#   zellij (cargo install --locked zellij)
#   starship (optional via official script)
# Plus repository configs: ranger/, .config/zellij/config.kdl, starship.toml, alias_scripts/*
#
# FOCUS: Safe backups & simplicity. We do NOT manage multiple versions.
# Existing configs are preserved with timestamped backup copies BEFORE replacement.
#
# Usage:
#   bash install.sh          # interactive
#   bash install.sh -y       # non-interactive (install all)
#   bash install.sh --dry-run
#
# Env toggles (true|false): MICRO_INSTALL, RANGER_INSTALL, ZELLIJ_INSTALL, STARSHIP_INSTALL
# INSTALL_DIR (default: ~/soft)

set -euo pipefail
IFS=$'\n\t'

REPO_ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_INSTALL_DIR="${INSTALL_DIR:-$HOME/soft}"
DRY_RUN=false
ASSUME_YES=false

while (( "$#" )); do
    case "$1" in
        -n|--dry-run) DRY_RUN=true; shift ;;
        -y|--yes) ASSUME_YES=true; shift ;;
        -h|--help) grep '^# ' "$0" | sed 's/^# //' | sed '1,2d'; exit 0 ;;
        *) echo "Unknown arg: $1" >&2; exit 1 ;;
    esac
done

log() { printf '[INFO] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*" >&2; }
err() { printf '[ERROR] %s\n' "$*" >&2; }
run() { if $DRY_RUN; then printf '[DRY] %s\n' "$*"; else eval "$@"; fi }
timestamp() { date +%Y%m%d-%H%M%S; }

prompt_default() { local p="$1" d="$2" v; $ASSUME_YES && { printf '%s\n' "$d"; return; }; read -r -p "$p [$d]: " v || true; [ -z "$v" ] && printf '%s\n' "$d" || printf '%s\n' "$v"; }
confirm() { local m="$1" def=${2:-false} pr="y/N"; $def && pr="Y/n"; $ASSUME_YES && return 0; read -r -p "$m [$pr] " a || true; $def && [[ "$a" =~ ^([Yy]|)$ ]] && return 0; [[ "$a" =~ ^[Yy]$ ]]; }

backup_item() {
    local path="$1"
    [ -e "$path" ] || return 0
    local ts="$(timestamp)" base="$(basename "$path")" dir="$(dirname "$path")" bak="$dir/.${base}.bak-${ts}"
    run "cp -a '$path' '$bak'"
    log "Backup: $path -> $bak"
}

install_dir="$(prompt_default 'Installation directory' "$DEFAULT_INSTALL_DIR")"
run "mkdir -p '$install_dir'"
run "mkdir -p '$HOME/bin' '$HOME/.local/bin' '$HOME/.config'"

MICRO_INSTALL=${MICRO_INSTALL:-true}
RANGER_INSTALL=${RANGER_INSTALL:-true}
ZELLIJ_INSTALL=${ZELLIJ_INSTALL:-true}
STARSHIP_INSTALL=${STARSHIP_INSTALL:-true}

if ! $ASSUME_YES; then
    $MICRO_INSTALL && confirm "Install micro?" true || MICRO_INSTALL=false
    $RANGER_INSTALL && confirm "Install ranger (pip --user)?" true || RANGER_INSTALL=false
    $ZELLIJ_INSTALL && confirm "Install zellij (cargo)?" true || ZELLIJ_INSTALL=false
    $STARSHIP_INSTALL && confirm "Install starship?" true || STARSHIP_INSTALL=false
fi

install_micro() {
    $MICRO_INSTALL || return 0
    if command -v micro >/dev/null 2>&1; then
        log "micro already on PATH: $(command -v micro) (will overwrite symlink only)"
    fi
    run "mkdir -p '$install_dir/micro'"
    if $DRY_RUN; then
        log "(dry-run) Would: cd '$install_dir/micro' && curl https://getmic.ro | bash"
    else
        ( cd "$install_dir/micro" && curl -fsSL https://getmic.ro | bash ) || { err "micro install failed"; return 1; }
    fi
    local bin_src
    bin_src=$(find "$install_dir/micro" -maxdepth 1 -type f -name micro 2>/dev/null | head -1 || true)
    [ -z "$bin_src" ] && { err "micro binary not found"; return 1; }
    run "ln -sfn '$bin_src' '$HOME/bin/micro'"
    log "micro installed -> $bin_src (symlinked to ~/bin/micro)"
}

install_ranger() {
    $RANGER_INSTALL || return 0
    local py
    for c in python3 python; do command -v "$c" >/dev/null 2>&1 && py="$c" && break; done
    [ -z "${py:-}" ] && { warn "Python not found; skipping ranger"; return 0; }
    if ! command -v pip3 >/dev/null 2>&1 && ! command -v pip >/dev/null 2>&1; then
        log "Bootstrapping pip"
        run "$py -m ensurepip --user || true"
    fi
    log "Installing / upgrading ranger-fm (pip --user)"
    if command -v pip3 >/dev/null 2>&1; then run "pip3 install --user --upgrade ranger-fm"; else run "pip install --user --upgrade ranger-fm"; fi
    if command -v ranger >/dev/null 2>&1; then log "ranger at $(command -v ranger)"; else warn "ranger not on PATH after install"; fi
    local cfg="$HOME/.config/ranger"
    run "mkdir -p '$cfg'"
    [ -d "$cfg" ] && [ "$(ls -A "$cfg" 2>/dev/null | wc -l)" -gt 0 ] && backup_item "$cfg"
    run "cp -a '${REPO_ROOT_DIR}/ranger/'* '$cfg/'"
    log "ranger config deployed"
}

install_zellij() {
    $ZELLIJ_INSTALL || return 0
    if command -v zellij >/dev/null 2>&1; then
        log "zellij already present: $(command -v zellij)"
    elif command -v cargo >/dev/null 2>&1; then
        log "Installing zellij via cargo (locked)"
        run "cargo install --locked zellij" || warn "cargo install zellij failed"
    else
        warn "cargo not found; skipping zellij install"
    fi
    local zcfg="$HOME/.config/zellij"
    run "mkdir -p '$zcfg'"
    [ -f "$zcfg/config.kdl" ] && backup_item "$zcfg/config.kdl"
    run "cp -a '${REPO_ROOT_DIR}/.config/zellij/config.kdl' '$zcfg/config.kdl'"
    log "zellij config deployed"
}

install_starship() {
    $STARSHIP_INSTALL || return 0
    if ! command -v starship >/dev/null 2>&1; then
        log "Installing starship (latest)"
        run "curl -fsSL https://starship.rs/install.sh -o /tmp/starship-install.sh"
        if $DRY_RUN; then
            log "(dry-run) Would run starship installer"
        else
            chmod +x /tmp/starship-install.sh
            /tmp/starship-install.sh -y -b "$HOME/.local/bin"
        fi
    else
        log "starship already present: $(command -v starship)"
    fi
    local scfg="$HOME/.config/starship.toml"
    [ -f "$scfg" ] && backup_item "$scfg"
    [ -f "${REPO_ROOT_DIR}/starship.toml" ] && run "cp -a '${REPO_ROOT_DIR}/starship.toml' '$scfg'" && log "starship config deployed"
}

install_aliases() {
    local src="${REPO_ROOT_DIR}/alias_scripts"; [ -d "$src" ] || return 0
    run "mkdir -p '$HOME/bin'"
    for f in "$src"/*; do
        [ -f "$f" ] || continue
        local base="$(basename "$f")" dest="$HOME/bin/$base"
        [ -e "$dest" ] && backup_item "$dest"
        run "cp -a '$f' '$dest'"; run "chmod +x '$dest'"; log "Alias installed: $base"
    done
}

log "Starting simplified install (dry-run=$DRY_RUN, assume-yes=$ASSUME_YES)"
install_micro
install_ranger
install_zellij
install_starship
install_aliases
log "All tasks complete. Ensure PATH includes ~/bin and ~/.local/bin"
log "Export example: export PATH=\"$HOME/bin:$HOME/.local/bin:$PATH\""
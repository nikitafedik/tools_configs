#!/usr/bin/env bash

# Safe, comprehensive installer for:
#  - micro editor
#  - ranger (file manager)
#  - zellij (terminal workspace)
#  - starship (prompt)
#  - bundled configs in this repository (ranger/, .config/zellij/config.kdl, starship.toml, alias_scripts/*)
#
# Features:
#  * Backs up any existing configs (timestamped) before replacing
#  * Asks (with default) for installation directory (~/soft if empty)
#  * Detects package manager for system packages (ranger / zellij fallback build hints)
#  * Optionally installs each component (interactive toggles or use flags)
#  * Idempotent & defensive; won't overwrite backups
#  * Dry-run support (-n / --dry-run)
#
# Usage examples:
#   bash install.sh                 # interactive
#   bash install.sh -y              # accept defaults non-interactively
#   bash install.sh --dry-run       # show actions only
#   MICRO_VERSION=2.0.14 bash install.sh -y
#
# Environment variables you can override:
#   INSTALL_DIR (default: ~/soft)
#   MICRO_VERSION (default: 2.0.14)
#   STARSHIP_INSTALL (default: true) / MICRO_INSTALL / RANGER_INSTALL / ZELLIJ_INSTALL

set -euo pipefail
IFS=$'\n\t'

REPO_ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_INSTALL_DIR="${INSTALL_DIR:-$HOME/soft}"
MICRO_VERSION="${MICRO_VERSION:-2.0.14}"
DRY_RUN=false
ASSUME_YES=false

while (( "$#" )); do
    case "$1" in
        -n|--dry-run) DRY_RUN=true ; shift ;;
        -y|--yes) ASSUME_YES=true ; shift ;;
        -h|--help)
            grep '^# ' "$0" | sed 's/^# //' | sed '1,2d'; exit 0 ;;
        *) echo "Unknown arg: $1" >&2; exit 1 ;;
    esac
done

log() { printf "[INFO] %s\n" "$*"; }
warn() { printf "[WARN] %s\n" "$*" >&2; }
err() { printf "[ERROR] %s\n" "$*" >&2; }
run() { if $DRY_RUN; then printf "[DRY] %s\n" "$*"; else eval "$@"; fi }

timestamp() { date +%Y%m%d-%H%M%S; }

prompt_default() {
    local prompt="$1"; local default="$2"; local var
    if $ASSUME_YES; then
        printf '%s\n' "$default"
        return 0
    fi
    read -r -p "$prompt [$default]: " var || true
    if [ -z "$var" ]; then printf '%s\n' "$default"; else printf '%s\n' "$var"; fi
}

confirm() {
    local msg="$1"; local default_yes=${2:-false}
    if $ASSUME_YES; then return 0; fi
    local default_prompt="y/N"; $default_yes && default_prompt="Y/n"
    read -r -p "$msg [$default_prompt] " ans || true
    if $default_yes; then [[ "$ans" =~ ^([Yy]|)$ ]] && return 0 || return 1; fi
    [[ "$ans" =~ ^([Yy])$ ]] && return 0 || return 1
}

backup_path() {
    local target="$1"
    if [ ! -e "$target" ]; then return 0; fi
    local ts; ts="$(timestamp)"
    local base; base="$(basename "$target")"
    local dir; dir="$(dirname "$target")"
    local backup="${dir}/.${base}.backup-${ts}"
    while [ -e "$backup" ]; do
        ts="$(timestamp)-$RANDOM"; backup="${dir}/.${base}.backup-${ts}"
    done
    run "cp -a '$target' '$backup'"
    log "Backed up $target -> $backup"
}

install_dir="$(prompt_default 'Enter installation directory' "$DEFAULT_INSTALL_DIR")"
run "mkdir -p '$install_dir'"

detect_pkg_manager() {
    if command -v apt-get >/dev/null 2>&1; then echo apt; return; fi
    if command -v dnf >/dev/null 2>&1; then echo dnf; return; fi
    if command -v yum >/dev/null 2>&1; then echo yum; return; fi
    if command -v pacman >/dev/null 2>&1; then echo pacman; return; fi
    if command -v zypper >/dev/null 2>&1; then echo zypper; return; fi
    if command -v brew >/dev/null 2>&1; then echo brew; return; fi
    echo none
}

PKG_MGR="$(detect_pkg_manager)"
log "Detected package manager: $PKG_MGR"

pkg_install() {
    local pkgs=("$@")
    case "$PKG_MGR" in
        apt) run "sudo apt-get update"; run "sudo apt-get install -y ${pkgs[*]}" ;;
        dnf) run "sudo dnf install -y ${pkgs[*]}" ;;
        yum) run "sudo yum install -y ${pkgs[*]}" ;;
        pacman) run "sudo pacman -Syu --noconfirm ${pkgs[*]}" ;;
        zypper) run "sudo zypper install -y ${pkgs[*]}" ;;
        brew) run "brew install ${pkgs[*]}" ;;
        none) warn "No supported package manager detected; skipping system install for: ${pkgs[*]}" ;;
    esac
}

ensure_deps() {
    local need=()
    for b in curl tar gzip; do command -v "$b" >/dev/null 2>&1 || need+=("$b"); done
    if [ ${#need[@]} -gt 0 ]; then
        log "Installing prerequisite tools: ${need[*]}"
        pkg_install "${need[@]}"
    fi
}
ensure_deps

STARSHIP_INSTALL=${STARSHIP_INSTALL:-true}
MICRO_INSTALL=${MICRO_INSTALL:-true}
RANGER_INSTALL=${RANGER_INSTALL:-true}
ZELLIJ_INSTALL=${ZELLIJ_INSTALL:-true}

if ! $ASSUME_YES; then
    $MICRO_INSTALL && confirm "Install micro editor?" true || MICRO_INSTALL=false
    $RANGER_INSTALL && confirm "Install ranger?" true || RANGER_INSTALL=false
    $ZELLIJ_INSTALL && confirm "Install zellij?" true || ZELLIJ_INSTALL=false
    $STARSHIP_INSTALL && confirm "Install starship prompt?" true || STARSHIP_INSTALL=false
fi

install_micro() {
    if ! $MICRO_INSTALL; then return 0; fi
    local micro_dir="$install_dir/micro-${MICRO_VERSION}"
    if [ -x "$micro_dir/micro" ]; then
        log "micro ${MICRO_VERSION} already present at $micro_dir"
    else
        local os=linux arch
        case "$(uname -m)" in
            x86_64) arch=64bit ;;
            aarch64|arm64) arch=arm64 ;;
            armv7*) arch=arm ;;
            *) arch=64bit; warn "Unknown arch $(uname -m); defaulting to 64bit" ;;
        esac
        local tgz="micro-${MICRO_VERSION}-${os}-${arch}.tar.gz"
        local url="https://github.com/zyedidia/micro/releases/download/v${MICRO_VERSION}/${tgz}"
        log "Downloading micro from $url"
        run "curl -fsSL '$url' -o '$install_dir/$tgz'"
        run "tar -xf '$install_dir/$tgz' -C '$install_dir'"
        run "mv '$install_dir/micro-${MICRO_VERSION}' '$micro_dir' 2>/dev/null || true"
    fi
    # Symlink into ~/bin
    run "mkdir -p '$HOME/bin'"
    if [ ! -e "$HOME/bin/micro" ]; then
        run "ln -sf '$micro_dir/micro' '$HOME/bin/micro'"
    fi
    log "micro installed (ensure ~/bin in PATH)"
}

install_ranger() {
    if ! $RANGER_INSTALL; then return 0; fi
    if ! command -v ranger >/dev/null 2>&1; then
        log "Installing ranger via package manager"
        pkg_install ranger || warn "Could not install ranger automatically."
    else
        log "ranger already installed: $(command -v ranger)"
    fi
    local ranger_cfg_dir="$HOME/.config/ranger"
    run "mkdir -p '$ranger_cfg_dir'"
    # Backup whole directory if exists & not empty
    if [ -d "$ranger_cfg_dir" ] && [ "$(ls -A "$ranger_cfg_dir" 2>/dev/null | wc -l)" -gt 0 ]; then
        backup_path "$ranger_cfg_dir"
    fi
    run "cp -a '${REPO_ROOT_DIR}/ranger/'* '$ranger_cfg_dir/'"
    log "ranger configs deployed"
}

install_zellij() {
    if ! $ZELLIJ_INSTALL; then return 0; fi
    if ! command -v zellij >/dev/null 2>&1; then
        log "Installing zellij via package manager (or building)"
        case "$PKG_MGR" in
            apt) pkg_install zellij || true ;;
            dnf|yum) pkg_install zellij || true ;;
            pacman) pkg_install zellij || true ;;
            zypper) pkg_install zellij || true ;;
            brew) pkg_install zellij || true ;;
            none) warn "No package manager; consider: cargo install --locked zellij" ;;
        esac
    else
        log "zellij already installed: $(command -v zellij)"
    fi
    local z_cfg_dir="$HOME/.config/zellij"
    run "mkdir -p '$z_cfg_dir'"
    if [ -f "$z_cfg_dir/config.kdl" ]; then
        backup_path "$z_cfg_dir/config.kdl"
    fi
    run "cp -a '${REPO_ROOT_DIR}/.config/zellij/config.kdl' '$z_cfg_dir/config.kdl'"
    log "zellij config deployed"
}

install_starship() {
    if ! $STARSHIP_INSTALL; then return 0; fi
    if ! command -v starship >/dev/null 2>&1; then
        log "Installing starship"
        run "curl -fsSL https://starship.rs/install.sh -o /tmp/starship-install.sh"
        if $DRY_RUN; then
            log "(dry-run) Would execute starship installer"
        else
            chmod +x /tmp/starship-install.sh
            /tmp/starship-install.sh -y -b "$HOME/.local/bin"
        fi
    else
        log "starship already installed: $(command -v starship)"
    fi
    local starship_cfg="$HOME/.config/starship.toml"
    run "mkdir -p '$HOME/.config'"
    if [ -f "$starship_cfg" ]; then backup_path "$starship_cfg"; fi
    run "cp -a '${REPO_ROOT_DIR}/starship.toml' '$starship_cfg'"
    log "starship config deployed"
}

install_aliases() {
    local alias_src_dir="${REPO_ROOT_DIR}/alias_scripts"
    [ -d "$alias_src_dir" ] || return 0
    run "mkdir -p '$HOME/bin'"
    for f in "$alias_src_dir"/*; do
        [ -f "$f" ] || continue
        local base="$(basename "$f")"
        local dest="$HOME/bin/$base"
        if [ -e "$dest" ]; then backup_path "$dest"; fi
        run "cp -a '$f' '$dest'"
        run "chmod +x '$dest'"
        log "Installed alias script: $base"
    done
}

deploy_misc() {
    # Future placeholder for additional root-level configs if added
    :
}

log "Starting installation (dry-run=$DRY_RUN, assume-yes=$ASSUME_YES)"
install_micro
install_ranger
install_zellij
install_starship
install_aliases
deploy_misc

log "All selected components processed."
log "Add to shell rc if not present: export PATH=\"$HOME/bin:$HOME/.local/bin:$PATH\""
log "Done." 
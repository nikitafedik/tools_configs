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
# Leave versions blank to auto-resolve latest from GitHub releases (can override via env)
MICRO_VERSION="${MICRO_VERSION:-}"
ZELLIJ_VERSION="${ZELLIJ_VERSION:-}"
STARSHIP_VERSION="${STARSHIP_VERSION:-}"  # blank = latest
INSTALL_MODE="${INSTALL_MODE:-auto}"      # auto|user|system
USE_LATEST="${USE_LATEST:-true}"          # if false and version blank, skip network lookup
DRY_RUN=false
ASSUME_YES=false

while (( "$#" )); do
    case "$1" in
        -n|--dry-run) DRY_RUN=true ; shift ;;
        -y|--yes) ASSUME_YES=true ; shift ;;
        --mode)
            INSTALL_MODE="${2:-user}"; shift 2 ;;
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

have_sudo() { command -v sudo >/dev/null 2>&1 && sudo -n true 2>/dev/null; }

PKG_MGR="$(detect_pkg_manager)"

if [ "$INSTALL_MODE" = auto ]; then
    if have_sudo; then INSTALL_MODE=system; else INSTALL_MODE=user; fi
fi
log "Install mode: $INSTALL_MODE (pkg mgr: $PKG_MGR)"

get_latest_release() {
    # arg: owner/repo ; outputs version without leading v where possible
    local repo="$1" raw tag
    raw=$(curl -fsSL "https://api.github.com/repos/${repo}/releases/latest" 2>/dev/null | grep -m1 'tag_name') || return 1
    tag=$(echo "$raw" | sed -E 's/.*"tag_name" *: *"([^"]+)".*/\1/')
    tag=${tag#v}
    printf '%s' "$tag"
}

pkg_install() {
    if [ "$INSTALL_MODE" != system ]; then
        warn "Skipping system package install (user mode): $*"
        return 0
    fi
    local pkgs=("$@")
    case "$PKG_MGR" in
        apt) run "sudo apt-get update"; run "sudo apt-get install -y ${pkgs[*]}" ;;
        dnf) run "sudo dnf install -y ${pkgs[*]}" ;;
        yum) run "sudo yum install -y ${pkgs[*]}" ;;
        pacman) run "sudo pacman -Syu --noconfirm ${pkgs[*]}" ;;
        zypper) run "sudo zypper install -y ${pkgs[*]}" ;;
        brew) run "brew install ${pkgs[*]}" ;;
        none) warn "No supported package manager detected for: ${pkgs[*]}" ;;
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
    if [ -z "$MICRO_VERSION" ] && $USE_LATEST; then
        MICRO_VERSION=$(get_latest_release zyedidia/micro || true)
        if [ -z "$MICRO_VERSION" ]; then MICRO_VERSION="2.0.14"; warn "Could not fetch latest micro version; using fallback $MICRO_VERSION"; fi
    elif [ -z "$MICRO_VERSION" ]; then
        MICRO_VERSION="2.0.14"; log "Using fallback micro version $MICRO_VERSION (network disabled)";
    fi
    local micro_dir="$install_dir/micro-${MICRO_VERSION}"
    if [ -x "$micro_dir/micro" ]; then
        log "micro ${MICRO_VERSION} already present at $micro_dir"
    else
        local arch_pattern asset url tgz
        case "$(uname -m)" in
            x86_64) arch_pattern='linux64' ;;
            aarch64|arm64) arch_pattern='linux-arm64' ;;
            armv7*|armv6*|armv5*) arch_pattern='linux-arm' ;;
            *) arch_pattern='linux64'; warn "Unknown arch $(uname -m); defaulting to linux64" ;;
        esac
        # Try to discover exact asset name via GitHub API
        asset=""
        if $USE_LATEST || [ -n "$MICRO_VERSION" ]; then
            local release_json
            release_json=$(curl -fsSL "https://api.github.com/repos/zyedidia/micro/releases/tags/v${MICRO_VERSION}" 2>/dev/null || true)
            if [ -n "$release_json" ]; then
                asset=$(echo "$release_json" | grep -E '"name" *: *"micro-' | grep "$arch_pattern" | grep -E '\\.(tar.gz|zip)"' | head -1 | sed -E 's/.*"name" *: *"([^"]+)".*/\1/')
            fi
        fi
        if [ -z "$asset" ]; then
            # Fallback guess patterns (correct known pattern micro-<v>-linux64.tar.gz)
            for guess in "micro-${MICRO_VERSION}-${arch_pattern}.tar.gz" "micro-${MICRO_VERSION}-${arch_pattern}.zip"; do
                # HEAD request to see if exists
                if curl -fsI "https://github.com/zyedidia/micro/releases/download/v${MICRO_VERSION}/${guess}" >/dev/null 2>&1; then asset="$guess"; break; fi
            done
        fi
        if [ -z "$asset" ]; then
            err "Unable to determine micro asset name for version ${MICRO_VERSION} (arch pattern: $arch_pattern)"; return 1
        fi
        url="https://github.com/zyedidia/micro/releases/download/v${MICRO_VERSION}/${asset}"
        log "Downloading micro asset $asset"
        run "curl -fsSL '$url' -o '$install_dir/$asset'"
        if [[ "$asset" == *.zip ]]; then
            run "unzip -o '$install_dir/$asset' -d '$install_dir/micro-${MICRO_VERSION}-unpack'"
            # Find micro binary within unpack
            local bin_path
            bin_path=$(find "$install_dir/micro-${MICRO_VERSION}-unpack" -type f -name micro -maxdepth 3 | head -1 || true)
            if [ -n "$bin_path" ]; then
                run "mkdir -p '$micro_dir'"
                run "cp -a '$bin_path' '$micro_dir/micro'"
            fi
        else
            run "tar -xf '$install_dir/$asset' -C '$install_dir'"
            # Tar usually creates dir micro-${MICRO_VERSION}
            if [ -d "$install_dir/micro-${MICRO_VERSION}" ]; then
                run "mv '$install_dir/micro-${MICRO_VERSION}' '$micro_dir' 2>/dev/null || true"
            fi
        fi
        if [ ! -x "$micro_dir/micro" ]; then
            err "micro binary not found after extraction"; return 1
        fi
    fi
    # Symlink into ~/bin
    run "mkdir -p '$HOME/bin'"
    if [ ! -e "$HOME/bin/micro" ]; then
        run "ln -sf '$micro_dir/micro' '$HOME/bin/micro'"
    fi
        # Maintain a current symlink inside install dir for scripts
        run "ln -sfn '$micro_dir' '$install_dir/micro-current'"
    log "micro installed (ensure ~/bin in PATH)"
}

install_ranger() {
    if ! $RANGER_INSTALL; then return 0; fi
    if ! command -v ranger >/dev/null 2>&1; then
        if [ "$INSTALL_MODE" = system ]; then
            log "Installing ranger via system package manager"
            pkg_install ranger || warn "System install failed; attempting user (pip) install."
        fi
    fi
    if ! command -v ranger >/dev/null 2>&1; then
        log "Attempting user install (pip) for ranger-fm"
        local pybin
        for cand in python3 python; do command -v "$cand" >/dev/null 2>&1 && pybin="$cand" && break; done
        if [ -z "${pybin:-}" ]; then warn "Python not found; cannot install ranger"; else
            if ! command -v pip3 >/dev/null 2>&1 && ! command -v pip >/dev/null 2>&1; then
                log "Bootstrapping pip (ensurepip)"
                run "$pybin -m ensurepip --user || true"
            fi
            if command -v pip3 >/dev/null 2>&1; then run "pip3 install --user --upgrade ranger-fm"; else run "pip install --user --upgrade ranger-fm"; fi
        fi
    fi
    if command -v ranger >/dev/null 2>&1; then
        log "ranger installed at $(command -v ranger)"
    else
        warn "ranger installation not found; continuing with config deployment only"
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
    if [ -z "$ZELLIJ_VERSION" ] && $USE_LATEST; then
        ZELLIJ_VERSION=$(get_latest_release zellij-org/zellij || true)
        if [ -z "$ZELLIJ_VERSION" ]; then ZELLIJ_VERSION="0.40.1"; warn "Could not fetch latest zellij version; using fallback $ZELLIJ_VERSION"; fi
    elif [ -z "$ZELLIJ_VERSION" ]; then
        ZELLIJ_VERSION="0.40.1"; log "Using fallback zellij version $ZELLIJ_VERSION (network disabled)";
    fi
    if ! command -v zellij >/dev/null 2>&1; then
        if [ "$INSTALL_MODE" = system ]; then
            log "Attempting system package install for zellij"
            pkg_install zellij || warn "System install failed or unavailable"
        fi
    fi
    if ! command -v zellij >/dev/null 2>&1; then
        # Try cargo first if available
        if command -v cargo >/dev/null 2>&1; then
            log "Installing zellij via cargo (user)"
            run "cargo install --locked --version ${ZELLIJ_VERSION} zellij || cargo install --locked zellij" || warn "Cargo install failed"
        else
            # Download prebuilt binary
            local arch variant url tgz tmp
            case "$(uname -m)" in
                x86_64) arch=x86_64-unknown-linux-musl ;;
                aarch64|arm64) arch=aarch64-unknown-linux-musl ;;
                *) arch=x86_64-unknown-linux-musl; warn "Unknown arch $(uname -m); using x86_64 binary" ;;
            esac
                    # Try both asset naming schemes (with or without version in filename)
                    run "mkdir -p '$HOME/.local/bin'"
                    for pattern in "zellij-${ZELLIJ_VERSION}-${arch}.tar.gz" "zellij-${arch}.tar.gz" "zellij-${arch}.zip"; do
                        [ -f "$install_dir/$pattern" ] && continue
                        url="https://github.com/zellij-org/zellij/releases/download/v${ZELLIJ_VERSION}/${pattern}"
                        log "Attempting download $url"
                        if run "curl -fsSL '$url' -o '$install_dir/$pattern'"; then
                            if [[ "$pattern" == *.zip ]]; then
                                run "unzip -o '$install_dir/$pattern' -d '$install_dir/zellij-unpack'"
                                run "mv '$install_dir/zellij-unpack/zellij' '$HOME/.local/bin/zellij' 2>/dev/null || true"
                            else
                                run "tar -xf '$install_dir/$pattern' -C '$install_dir'"
                                if [ -f "$install_dir/zellij" ]; then run "mv '$install_dir/zellij' '$HOME/.local/bin/zellij'"; else
                                    tmp=$(tar -tf "$install_dir/$pattern" | head -1 | cut -d/ -f1)
                                    [ -f "$install_dir/$tmp/zellij" ] && run "mv '$install_dir/$tmp/zellij' '$HOME/.local/bin/zellij'"
                                fi
                            fi
                            break
                        fi
                    done
                    run "chmod +x '$HOME/.local/bin/zellij'" || true
        fi
    fi
    if command -v zellij >/dev/null 2>&1; then
        log "zellij installed at $(command -v zellij)"
    else
        warn "zellij not installed (binary missing)"
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
        if [ -z "$STARSHIP_VERSION" ] && $USE_LATEST; then
            STARSHIP_VERSION=$(get_latest_release starship/starship || true)
            if [ -z "$STARSHIP_VERSION" ]; then warn "Could not fetch latest starship version; using installer script"; fi
        fi
        run "mkdir -p '$HOME/.local/bin'"
        if [ -n "$STARSHIP_VERSION" ]; then
            local arch; case "$(uname -m)" in
                x86_64) arch=x86_64-unknown-linux-gnu ;;
                aarch64|arm64) arch=aarch64-unknown-linux-gnu ;;
                *) arch=x86_64-unknown-linux-gnu; warn "Unknown arch; defaulting to x86_64" ;;
            esac
            local file="starship-${arch}.tar.gz"
            local url="https://github.com/starship/starship/releases/download/v${STARSHIP_VERSION}/${file}"
            log "Downloading starship $STARSHIP_VERSION from $url"
            if run "curl -fsSL '$url' -o '$install_dir/$file'"; then
                run "tar -xf '$install_dir/$file' -C '$install_dir'"
                if [ -f "$install_dir/starship" ]; then run "mv '$install_dir/starship' '$HOME/.local/bin/starship'"; fi
                run "chmod +x '$HOME/.local/bin/starship'" || true
            else
                warn "Download failed; falling back to installer script"
            fi
        fi
        if [ ! -x "$HOME/.local/bin/starship" ]; then
            log "Installing starship via official script (latest)"
            run "curl -fsSL https://starship.rs/install.sh -o /tmp/starship-install.sh"
            if $DRY_RUN; then
                log "(dry-run) Would execute starship installer"
            else
                chmod +x /tmp/starship-install.sh
                /tmp/starship-install.sh -y -b "$HOME/.local/bin"
            fi
        fi
    fi
    if command -v starship >/dev/null 2>&1; then
        log "starship installed at $(command -v starship)"
    else
        warn "starship not installed"
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

log "Starting installation (dry-run=$DRY_RUN, assume-yes=$ASSUME_YES, mode=$INSTALL_MODE)"
install_micro
install_ranger
install_zellij
install_starship
install_aliases
deploy_misc

log "All selected components processed."
log "Add to shell rc if not present: export PATH=\"$HOME/bin:$HOME/.local/bin:$PATH\""
log "Done." 
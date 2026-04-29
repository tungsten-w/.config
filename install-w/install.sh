#!/usr/bin/env bash
# install.sh — Tungsten dotfiles installer
#
#                                             /$$
#                                            |__/
# /$$  /$$  /$$  /$$$$$$   /$$$$$$  /$$$$$$$  /$$ /$$$$$$$   /$$$$$$
#| $$ | $$ | $$ |____  $$ /$$__  $$| $$__  $$| $$| $$__  $$ /$$__  $$
#| $$ | $$ | $$  /$$$$$$$| $$  \__/| $$  \ $$| $$| $$  \ $$| $$  \ $$
#| $$ | $$ | $$ /$$__  $$| $$      | $$  | $$| $$| $$  | $$| $$  | $$
#|  $$$$$/$$$$/|  $$$$$$$| $$      | $$  | $$| $$| $$  | $$|  $$$$$$$
# \_____/\___/  \_______/|__/      |__/  |__/|__/|__/  |__/ \____  $$
#                                                           /$$  \ $$
#                                                          |  $$$$$$/
#                                                           \______/
#still in progress
#
start=$SECONDS

show_banner() {
cat << "EOF"
.__                 __         .__  .__             __      __
|__| ____   _______/  |______  |  | |  |           /  \    /  \
|  |/    \ /  ___/\   __\__  \ |  | |  |    ______ \   \/\/   /
|  |   |  \\___ \  |  |  / __ \|  |_|  |__ /_____/  \        /
|__|___|  /____  > |__| (____  /____/____/           \__/\  /
        \/     \/            \/                           \/
dotfiles created by Tungsten \(ovo)/
EOF
}

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$HOME/.config"

set -e

#── Packages ────────────────────────────────────────────
BASE_PACKAGES=(
    hyprland rofi ghostty awww hyprlock
    cava playerctl grim slurp hyprshot nwg-look
    ttf-jetbrains-mono-nerd
)
HYPRPANEL_PACKAGES=(
    hyprpanel
)
NOCTALIA_PACKAGES=(
    noctalia-shell
)

# ── Colors ────────────────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; BLUE='\033[0;34m'; NC='\033[0m'
info()    { echo -e "${GREEN}[✓]${NC} $1"; }
warn()    { echo -e "${YELLOW}[!]${NC} $1"; }
error()   { echo -e "${RED}[✗]${NC} $1"; }

# ── Install packages ────────────────────────────────────
install_packages() {
    if command -v paru &>/dev/null; then
        AUR=paru
    elif command -v yay &>/dev/null; then
        AUR=yay
    else
        error "No AUR found (paru/yay) please install it before"; exit 1
    fi

    info "Installing base packages..."
    local total=${#BASE_PACKAGES[@]}
    local i=0
    for pkg in "${BASE_PACKAGES[@]}"; do
        i=$((i + 1))
        progress_bar "$i" "$total" "$pkg"
        "$AUR" -S --needed --noconfirm "$pkg" &>/dev/null
    done
    printf "\n"

    if [[ "$bar_ans" =~ ^[yY]$ ]]; then
        info "Installing HyprPanel..."
        local bar_pkgs=("${HYPRPANEL_PACKAGES[@]}")
    else
        info "Installing Noctalia..."
        local bar_pkgs=("${NOCTALIA_PACKAGES[@]}")
    fi

    local total2=${#bar_pkgs[@]}
    local j=0
    for pkg in "${bar_pkgs[@]}"; do
        j=$((j + 1))
        progress_bar "$j" "$total2" "$pkg"
        "$AUR" -S --needed --noconfirm "$pkg" &>/dev/null
    done
    printf "\n"
    info "All packages installed."
}
# ── Symlinks ────────────────────────────────────────────
link_config() {
    local src="$DOTFILES_DIR/$1"
    local dst="$CONFIG_DIR/$1"

    if [ ! -e "$src" ]; then
        warn "$src introuvable, ignoré"
        return
    fi
    if [ -e "$dst" ] && [ ! -L "$dst" ]; then
        warn "Backup : $dst → ${dst}.bak"
        mv "$dst" "${dst}.bak"
    fi
    ln -sfn "$src" "$dst"
    info "Linked: $dst"
}

stow_configs() {
    for dir in hypr rofi ghostty awww; do
        link_config "$dir"
    done
    if [[ "$bar_ans" =~ ^[yY]$ ]]; then
        info "Setting up HyprPanel..."
        link_config "hyprpanel"
    else
        info "Setting up Noctalia..."
        link_config "noctalia"
    fi
    ln -sfn "$DOTFILES_DIR/.tmux.conf" "$HOME/.tmux.conf"
}

# ── Scripts ─────────────────────────────────────────────
install_scripts() {
    for script in "$DOTFILES_DIR/.scripts/"*; do
        chmod +x "$script"
    done
    info "Scripts made executable in .scripts/"
}

progress_bar() {
    local current=$1
    local total=$2
    local pkg=$3
    local filled=$(( current * 20 / total ))
    local empty=$(( 20 - filled ))
    local bar=""

    for ((i=0; i<filled; i++)); do bar+="█"; done
    for ((i=0; i<empty; i++));  do bar+="░"; done

    local percent=$(( current * 100 / total ))
    printf "\r  ${GREEN}[${bar}]${NC} %3d%% — %s" "$percent" "$pkg"
}

# ── Help─────────────────────────────────────────────
show_help_info() {
    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  Need help or found a bug?"
    echo -e "  → Open an issue on GitHub:"
    echo -e "  ${BLUE}https://github.com/tungsten-w/.config/issues${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  Need help? Reach me on Discord : ${GREEN}@tungsten.inc${NC}"
    echo ""
    echo -e "  When asking for help, please include :"
    echo -e "  ${YELLOW}·${NC} Your OS and version  (e.g. CachyOS 2025.01)"
    echo -e "  ${YELLOW}·${NC} Your kernel           (uname -r)"
    echo -e "  ${YELLOW}·${NC} Hyprland version      (hyprctl version)"
    echo -e "  ${YELLOW}·${NC} The package involved  (e.g. hyprpanel 0.1.2)"
    echo -e "  ${YELLOW}·${NC} What went wrong / error message"
    echo ""
    echo -e "  I don't have a server — DM only."
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

}

# ── Main ──
show_banner
read -rp "Install AUR packages? [y/N] " ans
read -rp "Use HyprPanel as main status bar? [y/N] (N = Noctalia) " bar_ans

[[ "$ans" =~ ^[yY]$ ]] && install_packages

stow_configs
install_scripts
info "Done in $((SECONDS - start))s — Relaunch Hyprland to apply. Thanks for using these dotfiles ❤"
show_help_info

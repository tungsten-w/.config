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

show_banner() {
cat << "EOF"
_                         _
| |                       | |
| |_ _   _ _ __   __ _ ___| |_ ___ _ __
| __| | | | '_ \ / _` / __| __/ _ \ '_ \
| |_| |_| | | | | (_| \__ \ ||  __/ | | |
\__|\__,_|_| |_|\__, |___/\__\___|_| |_|©
                 __/ |
                |___/
        Tungsten Dotfiles Installer  \(ovo)/

EOF
}

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$HOME/.config"

PACKAGES=(
    hyprland hyprpanel rofi ghostty awww hyprlock
    cava playerctl grim slurp hyprshot nwg-look
    ttf-jetbrains-mono-nerd
)

# ── Couleurs ────────────────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
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
    info "Installation des paquets..."
    $AUR -S --needed --noconfirm "${PACKAGES[@]}"
}

# ── Symlinks ────────────────────────────────────────────
set -e

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
    for dir in hypr hyprpanel rofi ghostty awww; do  # awww cohérent avec PACKAGES
        link_config "$dir"
    done
    ln -sfn "$DOTFILES_DIR/.tmux.conf" "$HOME/.tmux.conf"
}

# ── Scripts ─────────────────────────────────────────────
install_scripts() {
    for script in "$DOTFILES_DIR/.scripts/"*; do
        chmod +x "$script"
    done
    info "Scripts made executable in .scripts/"
}


# ── Main ──
show_banner
read -rp "Install AUR packages? [y/N] " ans
[[ "$ans" =~ ^[yY]$ ]] && install_packages
stow_configs
install_scripts
info "Done! Relaunch Hyprland to apply. Thanks for using these dotfiles ❤"

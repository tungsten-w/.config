#!/usr/bin/env bash

# Fichier config Hyprland à modifier
HYPR_CONF="$HOME/.config/hypr/hyprland.conf"

# Charge les couleurs Pywal
source "$HOME/.cache/wal/colors.sh"

# Enlève le # des codes hex
ACT=${color1#"#"}      # Couleur active (bordure focus)
INACT=${color0#"#"}    # Couleur inactive

# Remplace dans le fichier Hyprland
sed -i \
  -e "s|^col\.active_border.*|col.active_border = rgb($ACT)|" \
  -e "s|^col\.inactive_border.*|col.inactive_border = rgb($INACT)|" \
  "$HYPR_CONF"

# Recharge Hyprland pour appliquer
hyprctl reload

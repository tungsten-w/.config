#!/bin/bash
HYRPPANEL_CONF="$HOME/.config/hyprpanel/config.json"

# Passe le matugen en mode clair
jq '.["theme.matugen_settings.mode"]="light"' "$HYRPPANEL_CONF" > "$HYRPPANEL_CONF.tmp" && mv "$HYRPPANEL_CONF.tmp" "$HYRPPANEL_CONF"

# Redémarre HyprPanel pour appliquer
pkill -x hyprpanel
hyprpanel &

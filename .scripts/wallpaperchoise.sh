#!/bin/bash

# Ton menu
CHOIX=$(echo -e "\n" | rofi -dmenu -p "     Wallpaper theme " -theme ~/.config/rofi/wallpaperchoise.rasi)

case "$CHOIX" in
    "")
        ~/.scripts/wallpaperdark.sh
        ;;
    "")
        ~/.scripts/wallpaperlight.sh
        ;;
    *)
        echo "Annulé"
        ;;
esac

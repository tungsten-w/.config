#!/bin/bash

# Ton menu
CHOIX=$(echo -e "\n\n󱠃" | rofi -dmenu -p "     Wallpaper theme " -theme ~/.config/rofi/wallpaperchoise.rasi)

case "$CHOIX" in
    "")
        .config/.scripts/wallpaperdark.sh
        ;;
    "")
        .config/.scripts/wallpaperlight.sh
        ;;
        "󱠃")
                HEURE=$(date +"%H")
                if [ "$HEURE" -ge 10 ] && [ "$HEURE" -lt 19 ]; then
                    # Jour
                    ~/.config/.scripts/wallpaperday.sh
                elif [ "$HEURE" -ge 19 ] && [ "$HEURE" -lt 22 ]; then
                    # Coucher de soleil
                    ~/.config/.scripts/wallpapersunset.sh
                elif [ "$HEURE" -ge 5 ] && [ "$HEURE" -lt 10 ]; then
                    # Coucher de soleil
                    ~/.config/.scripts/wallpapersunset.sh
                else
                    # Nuit
                    ~/.config/.scripts/wallpapernight.sh
                fi
                ;;
*)
    echo "Annulé"
    ;;
esac

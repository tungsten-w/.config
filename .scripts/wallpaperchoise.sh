#!/bin/bash
nohup "/home/tungsten/.config/.scripts/wallpaperimage0.sh"
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
  if [ "$HEURE" -ge 10 ] && [ "$HEURE" -lt 18 ]; then
    # Jour
    ~/.config/.scripts/wallpaperday.sh
    killall feh
  elif [ "$HEURE" -ge 18 ] && [ "$HEURE" -lt 22 ]; then
    # Coucher de soleil
    ~/.config/.scripts/wallpapersunset.sh
    killall feh
  elif [ "$HEURE" -ge 5 ] && [ "$HEURE" -lt 10 ]; then
    # Coucher de soleil
    ~/.config/.scripts/wallpapersunset.sh
    killall feh
  else
    # Nuit
    ~/.config/.scripts/wallpapernight.sh
    killall feh
  fi
  ;;
*)
  echo "Annulé"
  ;;
esac

killall feh

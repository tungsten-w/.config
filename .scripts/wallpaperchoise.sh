#!/bin/bash
nohup "/home/tungsten/.config/.scripts/wallpaperimage0.sh"

# Fonction pour déterminer la saison
get_saison() {
  MOIS=$(date +%m)  # récupère le mois en numérique (01-12)
  case $MOIS in
    12|01|02) SAISON="hiver" ;;
    03|04|05) SAISON="printemps" ;;
    06|07|08) SAISON="été" ;;
    09|10|11) SAISON="automne" ;;
  esac
  echo $SAISON
}

# Ton menu avec 4 options
CHOIX=$(echo -e "\n\n󱠃\n󱩹" | rofi -dmenu -p "     Wallpaper theme " -theme ~/.config/rofi/wallpaperchoise.rasi)

case "$CHOIX" in
"")
  ~/.config/.scripts/wallpaperdark.sh
  ;;
"")
  ~/.config/.scripts/wallpaperlight.sh
  ;;
"󱠃")
  HEURE=$(date +"%H")
  if [ "$HEURE" -ge 10 ] && [ "$HEURE" -lt 18 ]; then
    ~/.config/.scripts/wallpaperday.sh
    killall feh
  elif [ "$HEURE" -ge 18 ] && [ "$HEURE" -lt 22 ]; then
    ~/.config/.scripts/wallpapersunset.sh
    killall feh
  elif [ "$HEURE" -ge 5 ] && [ "$HEURE" -lt 10 ]; then
    ~/.config/.scripts/wallpapersunrise.sh
    killall feh
  else
    ~/.config/.scripts/wallpapernight.sh
    killall feh
  fi
  ;;
"󱩹")
  SAISON=$(get_saison)
  case "$SAISON" in
    "hiver") ~/.config/.scripts/wallpaper_hiver.sh ;;
    "printemps") ~/.config/.scripts/wallpaper_printemps.sh ;;
    "été") ~/.config/.scripts/wallpaper_ete.sh ;;
    "automne") ~/.config/.scripts/wallpaper_automne.sh ;;
  esac
  killall feh
  ;;
*)
  echo "Annulé"
  ;;
esac

killall feh

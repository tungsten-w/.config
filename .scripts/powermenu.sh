#!/bin/bash

# Menu affiché avec icônes et mots-clés uniques
options=(
  "󰩈 Déconnexion"
  "󰔛 Redémarrer"
  "󰐥 Éteindre"
  " Muter le micro"
  " Activer le micro"
  "󰂯 Bluetooth"
  "󰛧 Veille"
  "󰍁 Verrouiller"
)

# Affichage du menu
selected=$(printf "%s\n" "${options[@]}" | rofi -dmenu -i -p "Home Menu")

# Logique du menu par mot-clé
case "$selected" in
  *Déconnexion*)
    hyprctl dispatch exit
    ;;
  *Redémarrer*)
    systemctl reboot
    ;;
  *Éteindre*)
    systemctl poweroff
    ;;
  *Muter*)
    wpctl set-mute @DEFAULT_SOURCE@ 1
    notify-send -i audio-input-microphone "Micro désactivé" "Le micro est maintenant muet"
    ;;
  *Activer*)
    wpctl set-mute @DEFAULT_SOURCE@ 0
    notify-send -i audio-input-microphone "Micro activé" "Le micro est maintenant actif"
    ;;
  *Bluetooth*)
    if command -v blueberry &> /dev/null; then
      blueberry
    else
      notify-send "Bluetooth" "Blueberry n'est pas installé"
    fi
    ;;
  *Veille*)
    hyprlock & hyprctl dispatch dpms off
    ;;
  *Verrouiller*)
    hyprlock
    ;;
esac

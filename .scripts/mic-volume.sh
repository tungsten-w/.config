#!/bin/bash

# Récupérer le volume actuel du micro (entre 0.0 et 1.0)
current_volume=$(wpctl get-volume @DEFAULT_SOURCE@ | awk '{print $2}')

# Le convertir en pourcentage (entre 0 et 100)
current_percent=$(printf "%.0f" "$(echo "$current_volume * 100" | bc -l)")

# Demander un nouveau volume via Rofi
new_percent=$(seq 0 5 100 | rofi -dmenu -p "🎤 Volume du micro" -a "$((current_percent / 5))")

# Si vide ou annulé
[ -z "$new_percent" ] && exit

# Le convertir en format 0.0 - 1.0
new_volume=$(echo "$new_percent / 100" | bc -l)

# Appliquer le nouveau volume
wpctl set-volume @DEFAULT_SOURCE@ "$new_volume"

# Notification
notify-send -i audio-input-microphone "Volume du micro" "Réglé à ${new_percent}%"

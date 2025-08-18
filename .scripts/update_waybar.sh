#!/bin/bash

# Chemin vers l'image (remplace par ton chemin ou passe un argument)
WALLPAPER="$1"

# Générer les couleurs avec Pywal
wal -i "$WALLPAPER" -q

# Recharger Waybar
pkill waybar
nohup waybar &>/dev/null &

echo "Waybar mis à jour avec les nouvelles couleurs !"

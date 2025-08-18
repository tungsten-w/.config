#!/bin/bash

# Répertoire contenant les images
DIR="/home/tungsten/Pictures/Wallpapers/"

# Sélectionner une image aléatoire (seulement les fichiers .jpg)
RANDOM_IMAGE=$(find "$DIR" -maxdepth 1 -type f -name "*.jpg" | shuf -n 1)

# Mettre à jour la ligne "path =" dans la section "background" du fichier de config
sed -i '/^background {/,/^}/ s|^path = .*|path = '"$RANDOM_IMAGE"'|' ~/.config/hypr/hyprlock.conf

# Lancer Hyprlock
hyprlock

#!/bin/bash
# ~/.config/.scripts/update_cover.sh

COVER_PATH=$(playerctl metadata mpris:artUrl)

# Vérifie si le fichier existe
if [[ -f "$COVER_PATH" ]]; then
    cp "$COVER_PATH" /dev/shm/current_cover.jpg
fi


### MARCHE PAS

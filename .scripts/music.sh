#!/bin/bash

# Récupère l'adresse DBUS de ta session graphique
export DBUS_SESSION_BUS_ADDRESS=$(grep -z DBUS_SESSION_BUS_ADDRESS /proc/$(pgrep -u $USER -n Hyprland)/environ|cut -d= -f2-)

# récupère artiste et titre
song=$(playerctl metadata --format "{{artist}} - {{title}}" 2>/dev/null)

# si rien n'est joué, afficher un texte par défaut
if [ -z "$song" ]; then
    echo "🎵 Rien en lecture"
else
    echo "$song"
fi

#!/bin/bash
# fichier temporaire pour l'historique
HISTFILE="/tmp/clipboard_history.txt"
touch "$HISTFILE"

# récupère le contenu actuel du clipboard
CONTENT=$(wl-paste -n)

# ajoute le contenu s'il est nouveau et non vide
LAST=$(tail -n 1 "$HISTFILE")
if [ "$CONTENT" != "$LAST" ] && [ -n "$CONTENT" ]; then
    echo "$CONTENT" >> "$HISTFILE"
fi

# affiche le menu avec TON Rofi custom
# remplace ~/.config/rofi/mytheme.rasi par le chemin de ton thème
CHOICE=$(tac "$HISTFILE" | rofi -dmenu -i -p "Clipboard" -theme ~/.config/rofi/audio.rasi)

# si rien sélectionné, on quitte
[ -z "$CHOICE" ] && exit

# recolle le contenu sélectionné dans le clipboard
echo -n "$CHOICE" | wl-copy

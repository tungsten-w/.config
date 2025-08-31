#!/usr/bin/env bash
# shim qui prend l'argument (possible avec espaces)
INPUT="$*"
if [ -z "$INPUT" ]; then
  # si vide, récupère via eww get chat_input
  INPUT=$(eww get chat_input)
fi
# met à jour l'input (pour nettoyage si nécessaire)
eww update chat_input=""
# lance le vrai script en background
~/.local/bin/eww-chatgpt.sh "$INPUT" &

#!/usr/bin/env bash

# Liste des modèles
MODELS="󰅒
󰾲

"

# Menu Rofi
CHOICE=$(echo "$MODELS" | rofi -dmenu -p "LLM" | awk '{print $1}')

# Lancer Ollama avec le modèle choisi
case "$CHOICE" in
    󰅒)
        ghostty --title ollama-popup -e "ollama run mistral" &
        ;;
    󰾲)
        ghostty --title ollama-popup -e "ollama run llama3" &
        ;;
    )
        ghostty --title ollama-popup -e "ollama run phi3" &
        ;;
    )
        ghostty --title ollama-popup -e "ollama run codellama" &
        ;;
    *)
        notify-send "LLM annulé "
        ;;
esac

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
        ghostty -e "/usr/local/bin/ollama run llama3.1" &
        ;;
    󰾲)
        ghostty -e "ollama run llama3" &
        ;;
    )
        ghostty -e "ollama run phi3" &
        ;;
    )
        ghostty -e "ollama run codellama" &
        ;;

esac

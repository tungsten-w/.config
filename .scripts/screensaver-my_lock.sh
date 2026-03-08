#!/bin/bash

# Lance l'animation en arrière-plan
while true; do
    clear
    ~/.config/.scripts/ascii-lock.sh
    sleep 0.5
done &

ANIM_PID=$!

# vlock bloque le TTY — demande le password pour déverrouiller
vlock

# Déverrouillé → kill l'animation
kill $ANIM_PID 2>/dev/null

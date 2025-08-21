#!/usr/bin/env bash
# Affiche l'utilisation du GPU RX 7700S (Device 1)
USAGE=$(radeontop -d - -l1 2>/dev/null | awk -F'[:,%]' '/gpu/ {gsub(/ /,""); print $3}')

# Vérifie si les valeurs sont valides, sinon affiche N/A
USAGE=${USAGE:-"N/A"}

printf '󰾲 '"$USAGE"

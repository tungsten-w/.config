#!/bin/bash

# Dossier où sont tes images
TARGET_DIR="$HOME/Pictures/Wallpapers"

# Vérifie que le dossier existe
if [ ! -d "$TARGET_DIR" ]; then
    echo "Erreur : le dossier $TARGET_DIR n'existe pas."
    exit 1
fi

# Va dans le dossier
cd "$TARGET_DIR" || exit 1

# Lance le script de conversion (assure-toi qu'il est exécutable)
"$HOME.config/.scripts/jpg2png.sh"

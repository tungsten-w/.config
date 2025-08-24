#!/bin/bash

# Vérifie qu'on a ImageMagick
if ! command -v mogrify &> /dev/null; then
    echo "Erreur : ImageMagick n'est pas installé."
    exit 1
fi

# Dossier à traiter (par défaut le dossier courant)
DIR="${1:-.}"

echo "Conversion des JPG en PNG dans : $DIR"

# Trouve tous les JPG et convertit
find "$DIR" -type f -iname "*.jpg" | while read -r FILE; do
    echo "Conversion : $FILE"

    # Convertit en PNG
    if mogrify -format png "$FILE"; then
        # Supprime l'ancien JPG seulement si la conversion a réussi
        rm "$FILE"
        echo "Supprimé : $FILE"
    else
        echo "Erreur de conversion : $FILE"
    fi
done

echo "Conversion terminée !"
prime l'ancien JPG seulement

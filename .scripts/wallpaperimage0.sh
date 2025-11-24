#!/bin/bash

# Fichiers temporaires
input="/tmp/caca.png"
output="/tmp/cacae-0.png"

# Redimensionner l'image
magick "$input" -resize 40% "$output" || { echo "magick a échoué"; exit 1; }

# Lancer feh détaché (ne bloque plus le script parent)
# Méthode recommandée : setsid pour créer une nouvelle session, et & pour background
setsid feh --zoom fill --geometry 900x300+827+590 --no-fehbg "$output" >/dev/null 2>&1 &

# Sortie immédiate du script
exit 0

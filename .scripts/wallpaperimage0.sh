#!/bin/bash
current_wallpaper="/tmp/cacae-0.png"


# Lancer feh détaché (ne bloque plus le script parent)
# Méthode recommandée : setsid pour créer une nouvelle session, et & pour background
setsid feh --zoom fill --geometry 900x300+827+590 --no-fehbg "$current_wallpaper" >/dev/null 2>&1 &

# Sortie immédiate du script
exit 0

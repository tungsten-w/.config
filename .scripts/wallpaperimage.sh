#!/bin/bash

output="/tmp/cacae.png"
# Lancer feh détaché (ne bloque plus le script parent)
# Méthode recommandée : setsid pour créer une nouvelle session, et & pour background
setsid feh --geometry 995x300+782+290 --no-fehbg "$output" >/dev/null 2>&1 &

# Sortie immédiate du script
exit 0

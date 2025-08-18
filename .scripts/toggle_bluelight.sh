#!/bin/bash

# Vérifie si wlsunset est en cours d'exécution
if pgrep wlsunset > /dev/null; then
    # Arrête wlsunset
    pkill wlsunset
    echo "OFF"
else
    # Démarre wlsunset avec une température de 4050K
    wlsunset -T 4050 &
    # Attend un court instant pour s'assurer que le processus démarre
    sleep 1
    # Vérifie si wlsunset est bien démarré
    if pgrep wlsunset > /dev/null; then
        echo "ON"
    else
        echo "Échec du démarrage de wlsunset"
    fi
fi

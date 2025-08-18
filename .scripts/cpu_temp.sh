#!/usr/bin/env bash

# Méthode 1 : Lecture depuis /sys/class/hwmon/
temp=$(cat /sys/class/hwmon/hwmon*/temp*_input 2>/dev/null | head -n 1 | awk '{printf "%.1f", $1/1000}')

# Méthode 2 : Fallback avec `sensors` si hwmon échoue
if [ -z "$temp" ]; then
    temp=$(sensors | grep -E '(Core|Tdie|edge)' | sed 's/(.*)//' | grep -E -o '[0-9]+\.[0-9]+°C' | head -n 1 | sed 's/°C//')
fi

# Si aucune donnée, affiche "N/A"
if [ -z "$temp" ]; then
    echo '{"text": "🌡️ N/A", "tooltip": "Capteur non détecté"}'
else
    echo " ${temp}°C"
fi

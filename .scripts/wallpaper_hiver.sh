#!/bin/bash

# Chemin vers le dossier contenant les fonds d'écran
WALLPAPER_DIR="$HOME/Pictures/Wallpapers/hiver"

# Vérifier si le dossier existe
if [ ! -d "$WALLPAPER_DIR" ]; then
    echo "Erreur : Le dossier $WALLPAPER_DIR n'existe pas."
    exit 1
fi

# Récupérer une image aléatoire dans le dossier
WALLPAPER=$(find "$WALLPAPER_DIR" -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.gif" -o -iname "*.webp" \) | shuf -n 1)

if [ -z "$WALLPAPER" ]; then
    echo "Erreur : Aucun fichier image trouvé dans $WALLPAPER_DIR."
    exit 1
fi

# Vérifier si swww-daemon est en cours d'exécution
if ! pgrep -x "swww-daemon" > /dev/null; then
    echo "Démarrage de swww-daemon..."
    swww-daemon &
    sleep 1
fi

# Changer le fond d'écran avec swww
swww img "$WALLPAPER" --transition-type any --transition-fps 60

# Mettre à jour le lien symbolique pour HyprPanel
ln -sf "$WALLPAPER" "$HOME/Pictures/Wallpapers/current_wallpaper.jpg"

# Appliquer les couleurs avec pywal
wal -i "$WALLPAPER" -l -q
if [ $? -eq 0 ]; then
    echo "Couleurs pywal appliquées avec succès : $WALLPAPER"
else
    echo "Erreur lors de l'exécution de pywal."
    exit 1
fi

# Copie dans /tmp (si utile)
cp "$WALLPAPER" /tmp/caca.png

#mettre hyprpanel en mode light
# Passe le matugen en mode clair
HYRPPANEL_CONF="$HOME/.config/hyprpanel/config.json"

jq '.["theme.matugen_settings.mode"]="light"' "$HYRPPANEL_CONF" > "$HYRPPANEL_CONF.tmp" && mv "$HYRPPANEL_CONF.tmp" "$HYRPPANEL_CONF"


hyprpanel -q
hyprpanel &

# Relancer ulauncher
pkill -f ulauncher

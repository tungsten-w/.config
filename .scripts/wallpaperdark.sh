#!/bin/bash
# kill the first image .config/.scripts/wallpaperimage.sh
pkill -f feh

# Chemin vers le dossier contenant les fonds d'écran
WALLPAPER_DIR="$HOME/Pictures/Wallpapers/dark"
THUMBNAIL_DIR="$WALLPAPER_DIR/.thumbnails"

#lancer  le script de ro
nohup .config/.scripts/wallpaper_recognition.sh "$WALLPAPER_DIR" &

# Créer le dossier pour les vignettes s'il n'existe pas
mkdir -p "$THUMBNAIL_DIR"

# Vérifier si le dossier des fonds d'écran existe
#if [ ! -d "$WALLPAPER_DIR" ]; then
#    echo "Erreur : Le dossier $WALLPAPER_DIR n'existe pas."
#    exit 1
#fi

# Vérifier si le dossier contient des images (hors vignettes)
if [ -z "$(find "$WALLPAPER_DIR" -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.gif" -o -iname "*.webp" \) \
    -not -path "$THUMBNAIL_DIR/*")" ]; then
    echo "Erreur : Aucun fichier image (.jpg, .png, .gif ou .webp) trouvé dans $WALLPAPER_DIR."
    exit 1
fi

# Générer des vignettes pour chaque image si elles n'existent pas
while IFS= read -r img; do
    base_name=$(basename "${img%.*}")
    thumb="$THUMBNAIL_DIR/$base_name.png"
    if [ ! -f "$thumb" ]; then
        convert "$img[0]" -resize 100x100 "$thumb" 2>/dev/null \
            || echo "Erreur de conversion pour $img"
    fi
done < <(find "$WALLPAPER_DIR" -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.gif" -o -iname "*.webp" \) \
    -not -path "$THUMBNAIL_DIR/*")

#ouvre le wallpaper actuel en image
nohup "/home/tungsten/.config/.scripts/wallpaperimage.sh"

# Utiliser Rofi pour sélectionner un fond d'écran avec aperçu
declare -A displayed  # Tableau associatif pour suivre nom+extension
WALLPAPER=$(find "$WALLPAPER_DIR" -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.gif" -o -iname "*.webp" \) \
    -not -path "$THUMBNAIL_DIR/*" | sort | while read -r img; do
        base_name=$(basename "${img%.*}")
        ext="${img##*.}"
        key="${base_name}_${ext}"
        if [ -z "${displayed[$key]}" ]; then
            echo -en "$(basename "$img")\0icon\x1f$THUMBNAIL_DIR/$base_name.png\n"
            displayed[$key]=1
        fi
done | rofi -dmenu -p "~ Select a wallpaper ~  ☀︎ " \
           -show-icons -icon-theme "Papirus" \
           -theme ~/.config/rofi/wallpaper.rasi)

# Vérifier si une image a été sélectionnée
if [ -z "$WALLPAPER" ]; then
    echo "Erreur : Aucune image sélectionnée."
    exit 1
fi

# Reconstruire le chemin complet de l'image sélectionnée
WALLPAPER="$WALLPAPER_DIR/$WALLPAPER"

# tuer l'image .config/.scripts/wallpaperimage.sh
pkill -f feh

# Changer le fond d'écran avec swww
swww img "$WALLPAPER" --transition-type any --transition-fps 60

# Appliquer les couleurs avec pywal (inchangé, comme tu veux)
wal -i "$WALLPAPER" -q
if [ $? -eq 0 ]; then
    echo "Couleurs pywal appliquées avec succès : $WALLPAPER"
else
    echo "Erreur lors de l'exécution de pywal."
    exit 1
fi

#faire une copie du wallpaper actuel
cp $WALLPAPER /tmp/caca.png

# Passe le matugen d'HyprPanel en mode sombre
HYRPPANEL_CONF="$HOME/.config/hyprpanel/config.json"
jq '.["theme.matugen_settings.mode"]="dark"' "$HYRPPANEL_CONF" > "$HYRPPANEL_CONF.tmp" && mv "$HYRPPANEL_CONF.tmp" "$HYRPPANEL_CONF"

# suprimer l'image qui casse les couilles
rm -f /tmp/cacae-0.png

# Créer une version PNG du fond d'écran
INPUT="$WALLPAPER"
TMP_MAIN="/tmp/caca.png"
TMP_SMALL="/tmp/cacae.png"

# Si c'est un GIF, ne prendre que la première frame
if [[ "$INPUT" =~ \.gif$ ]]; then
    magick "$INPUT[0]" "$TMP_MAIN" || { echo "Erreur conversion GIF -> PNG"; exit 1; }
else
    cp "$INPUT" "$TMP_MAIN"
fi

# Redimensionner les images PNG
magick "$TMP_MAIN" -resize 30% "$TMP_SMALL" || { echo "Erreur redimensionnement"; exit 1; }

#Relancer HyprPanel
hyprpanel -q
hyprpanel &

# Relancer ulauncher
pkill -f ulauncher

#changer le theme de obsidian en dark
pkill -f -i obsidian || pkill -f "flatpak run md.obsidian.Obsidian" || true; sleep 0.5
VAULT_APP="$HOME/Documents/Obsidian Vault/.obsidian/app.json"; VAULT_APPEAR="$HOME/Documents/Obsidian Vault/.obsidian/appearance.json"
jq '.baseTheme = "dark"' "$VAULT_APP" > "$VAULT_APP.tmp" && mv "$VAULT_APP.tmp" "$VAULT_APP" && jq '.theme = "obsidian"' "$VAULT_APPEAR" > "$VAULT_APPEAR.tmp" && mv "$VAULT_APPEAR.tmp" "$VAULT_APPEAR" && ( nohup flatpak run md.obsidian.Obsidian >/dev/null 2>&1 & ) || ( nohup obsidian >/dev/null 2>&1 & )

# Fichiers temporaires
input="/tmp/caca.png"
output="/tmp/cacae-0.png"

# Redimensionner l'image
magick "$input" -resize 25% "$output" || { echo "magick a échoué"; exit 1; }


#!/bin/bash

gsettings set org.gnome.desktop.interface gtk-theme 'catppuccin-mocha-red-standard+default'
gsettings set org.gnome.desktop.interface icon-theme 'Adwaita'
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'

notify-send "🌙 Thème sombre activé"

#!/bin/bash
#eww open logo
nohup "/home/tungsten/.config/.scripts/wallpaperimage.sh"
# Chemin vers le dossier contenant les fonds d'écran
WALLPAPER_DIR="$HOME/Pictures/Wallpapers/dark"
THUMBNAIL_DIR="$WALLPAPER_DIR/.thumbnails"

# Créer le dossier pour les vignettes s'il n'existe pas
mkdir -p "$THUMBNAIL_DIR"

# Vérifier si le dossier des fonds d'écran existe
if [ ! -d "$WALLPAPER_DIR" ]; then
    echo "Erreur : Le dossier $WALLPAPER_DIR n'existe pas."
    exit 1
fi

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
done | rofi -dmenu -p "Sélectionner un fond d'écran" \
           -show-icons -icon-theme "Papirus" \
           -theme ~/.config/rofi/wallpaper.rasi)

# Vérifier si une image a été sélectionnée
if [ -z "$WALLPAPER" ]; then
    echo "Erreur : Aucune image sélectionnée."
    exit 1
fi

# Reconstruire le chemin complet de l'image sélectionnée
WALLPAPER="$WALLPAPER_DIR/$WALLPAPER"

# Vérifier si swww-daemon est en cours d'exécution
if ! pgrep -x "swww-daemon" > /dev/null; then
    echo "Démarrage de swww-daemon..."
    swww-daemon &
    sleep 1  # Attendre que le démon démarre
fi

# Changer le fond d'écran avec swww
swww img "$WALLPAPER" --transition-type any --transition-fps 60

# Mettre à jour le lien symbolique pour HyprPanel
ln -sf "$WALLPAPER" "$HOME/Pictures/Wallpapers/current_wallpaper.jpg"

# Appliquer les couleurs avec pywal (inchangé, comme tu veux)
wal -i "$WALLPAPER" -q
if [ $? -eq 0 ]; then
    echo "Couleurs pywal appliquées avec succès : $WALLPAPER"
else
    echo "Erreur lors de l'exécution de pywal."
    exit 1
fi

cp $WALLPAPER /tmp/caca.png

# Passe le matugen d'HyprPanel en mode sombre
HYRPPANEL_CONF="$HOME/.config/hyprpanel/config.json"
jq '.["theme.matugen_settings.mode"]="dark"' "$HYRPPANEL_CONF" > "$HYRPPANEL_CONF.tmp" && mv "$HYRPPANEL_CONF.tmp" "$HYRPPANEL_CONF"

#Gérer l'image du menu de gestion des Wallpapers
input="/tmp/caca.png"
outpute="/tmp/cacae.png"
output="/tmp/cacae.png"
magick "$input" -resize 70% "$output" || { echo "magick a échoué"; exit 1; }
magick "$input" -resize 30% "$outpute" || { echo "magick a échoué"; exit 1; }

#Relancer HyprPanel mais finalement on en a pas besoin car matugen fait tout le taf
hyprpanel -q
hyprpanel &


# Relancer ulauncher
pkill -f ulauncher

#changer le theme de obsidian en dark
pkill -f -i obsidian || pkill -f "flatpak run md.obsidian.Obsidian" || true; sleep 0.5
VAULT_APP="$HOME/Documents/Obsidian Vault/.obsidian/app.json"; VAULT_APPEAR="$HOME/Documents/Obsidian Vault/.obsidian/appearance.json"
jq '.baseTheme = "dark"' "$VAULT_APP" > "$VAULT_APP.tmp" && mv "$VAULT_APP.tmp" "$VAULT_APP" && jq '.theme = "obsidian"' "$VAULT_APPEAR" > "$VAULT_APPEAR.tmp" && mv "$VAULT_APPEAR.tmp" "$VAULT_APPEAR" && ( nohup flatpak run md.obsidian.Obsidian >/dev/null 2>&1 & ) || ( nohup obsidian >/dev/null 2>&1 & )

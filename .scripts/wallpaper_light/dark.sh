#!/bin/bash

# ── Choix du mode ──────────────────────────────────────────────────────────────
MODE=$(printf "dark\nlight" | rofi -dmenu -p "~ Theme ~" -theme ~/.config/rofi/wallpaper.rasi)

[ -z "$MODE" ] && exit 0

# ── Variables selon le mode ────────────────────────────────────────────────────
WALLPAPER_DIR="$HOME/Pictures/Wallpapers/$MODE"
THUMBNAIL_DIR="$WALLPAPER_DIR/.thumbnails"

if [ "$MODE" = "dark" ]; then
    WAL_FLAGS="-q"
    MATUGEN_MODE="dark"
    OBS_BASE_THEME="dark"
    OBS_THEME="obsidian"
    RELAUNCH_OBSIDIAN=true
else
    WAL_FLAGS="-l -q"
    MATUGEN_MODE="light"
    OBS_BASE_THEME="light"
    OBS_THEME="moonstone"
    RELAUNCH_OBSIDIAN=false
fi

# ── Init ───────────────────────────────────────────────────────────────────────
pkill -f feh
nohup .config/.scripts/wallpaper_recognition.sh "$WALLPAPER_DIR" &
mkdir -p "$THUMBNAIL_DIR"

# ── Vérification dossier ───────────────────────────────────────────────────────
if [ -z "$(find "$WALLPAPER_DIR" -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.gif" -o -iname "*.webp" \) \
    -not -path "$THUMBNAIL_DIR/*")" ]; then
    echo "Erreur : Aucune image trouvée dans $WALLPAPER_DIR."
    exit 1
fi

# ── Génération des vignettes ───────────────────────────────────────────────────
while IFS= read -r img; do
    base_name=$(basename "${img%.*}")
    thumb="$THUMBNAIL_DIR/$base_name.png"
    if [ ! -f "$thumb" ] || [ "$thumb" -ot "$img" ]; then
        magick "$img[0]" -thumbnail 900x900\> -strip "$thumb" 2>/dev/null \
            || echo "Erreur création vignette pour $img"
    fi
done < <(find "$WALLPAPER_DIR" -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.gif" -o -iname "*.webp" \) \
    -not -path "$THUMBNAIL_DIR/*")

# ── Sélection du wallpaper ─────────────────────────────────────────────────────
WALLPAPER=$(find "$WALLPAPER_DIR" -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.gif" -o -iname "*.webp" \) \
    -not -path "$THUMBNAIL_DIR/*" | sort | while read -r img; do
        base_name=$(basename "${img%.*}")
        echo -en "$(basename "$img")\0icon\x1f$THUMBNAIL_DIR/$base_name.png\n"
done | rofi -dmenu -p "~ Select a wallpaper ~  ⏾ " \
           -show-icons -icon-theme "Papirus" \
           -theme ~/.config/rofi/wallpaper.rasi)

[ -z "$WALLPAPER" ] && exit 0

WALLPAPER="$WALLPAPER_DIR/$WALLPAPER"

# ── Appliquer le wallpaper ─────────────────────────────────────────────────────
pkill -f feh
awww img "$WALLPAPER" --transition-type any --transition-fps 60 --transition-duration 1

# ── Pywal ──────────────────────────────────────────────────────────────────────
wal -i "$WALLPAPER" $WAL_FLAGS || { echo "Erreur pywal."; exit 1; }

# ── Copie du wallpaper actuel ──────────────────────────────────────────────────
cp "$WALLPAPER" /tmp/caca.png

# ── HyprPanel : mode matugen ───────────────────────────────────────────────────
HYPRPANEL_CONF="$HOME/.config/hyprpanel/config.json"
jq ".\"theme.matugen_settings.mode\"=\"$MATUGEN_MODE\"" "$HYPRPANEL_CONF" \
    > "$HYPRPANEL_CONF.tmp" && mv "$HYPRPANEL_CONF.tmp" "$HYPRPANEL_CONF"

# ── Images temporaires ─────────────────────────────────────────────────────────
rm -f /tmp/cacae-0.png

TMP_MAIN="/tmp/caca.png"
TMP_SMALL="/tmp/cacae.png"

if [[ "$WALLPAPER" =~ \.gif$ ]]; then
    magick "$WALLPAPER[0]" "$TMP_MAIN" || { echo "Erreur conversion GIF"; exit 1; }
fi

magick "$TMP_MAIN" -resize 30% "$TMP_SMALL" || { echo "Erreur redimensionnement"; exit 1; }
magick "$TMP_MAIN" -resize 25% /tmp/cacae-0.png || { echo "magick a échoué"; exit 1; }

# ── HyprPanel + ulauncher ──────────────────────────────────────────────────────
hyprpanel -q
hyprpanel &
pkill -f ulauncher

# ── Obsidian ───────────────────────────────────────────────────────────────────
pkill -f -i obsidian || true
sleep 0.5

VAULT_APP="$HOME/Documents/Obsidian Vault/.obsidian/app.json"
VAULT_APPEAR="$HOME/Documents/Obsidian Vault/.obsidian/appearance.json"

jq ".baseTheme = \"$OBS_BASE_THEME\"" "$VAULT_APP" > "$VAULT_APP.tmp" && mv "$VAULT_APP.tmp" "$VAULT_APP"
jq ".theme = \"$OBS_THEME\"" "$VAULT_APPEAR" > "$VAULT_APPEAR.tmp" && mv "$VAULT_APPEAR.tmp" "$VAULT_APPEAR"

if [ "$RELAUNCH_OBSIDIAN" = true ]; then
    ( nohup flatpak run md.obsidian.Obsidian >/dev/null 2>&1 & ) \
        || ( nohup obsidian >/dev/null 2>&1 & )
fi

#!/bin/bash

# ══════════════════════════════════════════════════════════════
# FONCTIONS
# ══════════════════════════════════════════════════════════════

get_saison() {
    case $(date +%m) in
        12|01|02) echo "hiver" ;;
        03|04|05) echo "printemps" ;;
        06|07|08) echo "ete" ;;
        09|10|11) echo "automne" ;;
    esac
}

get_moment_journee() {
    HEURE=$(date +"%H")
    if   [ "$HEURE" -ge 7  ] && [ "$HEURE" -lt 18 ]; then echo "day"
    elif [ "$HEURE" -ge 18 ] && [ "$HEURE" -lt 22 ]; then echo "sunset"
    else echo "night"
    fi
}

# Applique un wallpaper avec rofi picker (dark/light)
pick_with_rofi() {
    local dir="$1"
    local thumb_dir="$dir/.thumbnails"
    mkdir -p "$thumb_dir"

    if [ -z "$(find "$dir" -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.gif" -o -iname "*.webp" \) \
        -not -path "$thumb_dir/*")" ]; then
        echo "Erreur : Aucune image dans $dir."; exit 1
    fi

    # Génération vignettes
    while IFS= read -r img; do
        base_name=$(basename "${img%.*}")
        thumb="$thumb_dir/$base_name.png"
        if [ ! -f "$thumb" ] || [ "$thumb" -ot "$img" ]; then
            magick "$img[0]" -thumbnail 900x900\> -strip "$thumb" 2>/dev/null
        fi
    done < <(find "$dir" -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.gif" -o -iname "*.webp" \) \
        -not -path "$thumb_dir/*")

    # Sélection rofi
    WALLPAPER=$(find "$dir" -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.gif" -o -iname "*.webp" \) \
        -not -path "$thumb_dir/*" | sort | while read -r img; do
            base_name=$(basename "${img%.*}")
            echo -en "$(basename "$img")\0icon\x1f$thumb_dir/$base_name.png\n"
    done | rofi -dmenu -p "~ Select a wallpaper ~  ⏾ " \
               -show-icons -icon-theme "Papirus" \
               -theme ~/.config/rofi/wallpaper.rasi)

    [ -z "$WALLPAPER" ] && exit 0
    echo "$dir/$WALLPAPER"
}

# Applique un wallpaper aléatoire (saisons/heure)
pick_random() {
    local dir="$1"
    if [ ! -d "$dir" ]; then
        echo "Erreur : $dir n'existe pas." >&2; exit 1
    fi

    WALLPAPER=$(find "$dir" -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.gif" -o -iname "*.webp" \) | shuf -n 1)
    [ -z "$WALLPAPER" ] && { echo "Erreur : Aucune image dans $dir." >&2; exit 1; }
    echo "$WALLPAPER"
}

# Applique tout (awww, pywal, hyprpanel, obsidian...)
apply_all() {
    local wallpaper="$1"
    local dark="$2"   # true ou false

    local wal_flags matugen_mode obs_base obs_theme relaunch_obs
    if $dark; then
        wal_flags="-q"; matugen_mode="dark"
        obs_base="dark"; obs_theme="obsidian"; relaunch_obs=true
    else
        wal_flags="-l -q"; matugen_mode="light"
        obs_base="light"; obs_theme="moonstone"; relaunch_obs=false
    fi

    pkill -f feh

    # Wallpaper
    awww img "$wallpaper" --transition-type any --transition-fps 60 --transition-duration 0.7
    ln -sf "$wallpaper" "$HOME/Pictures/Wallpapers/current_wallpaper.jpg"

    # Pywal
    wal -i "$wallpaper" $wal_flags || { echo "Erreur pywal."; exit 1; }

    # Copies /tmp
    cp "$wallpaper" /tmp/caca.png
    rm -f /tmp/cacae-0.png

    if [[ "$wallpaper" =~ \.gif$ ]]; then
        magick "$wallpaper[0]" /tmp/caca.png || { echo "Erreur conversion GIF"; exit 1; }
    fi
    magick /tmp/caca.png -resize 30% /tmp/cacae.png
    magick /tmp/caca.png -resize 25% /tmp/cacae-0.png

    # HyprPanel
    HYPRPANEL_CONF="$HOME/.config/hyprpanel/config.json"
    jq ".\"theme.matugen_settings.mode\"=\"$matugen_mode\"" "$HYPRPANEL_CONF" \
        > "$HYPRPANEL_CONF.tmp" && mv "$HYPRPANEL_CONF.tmp" "$HYPRPANEL_CONF"
    hyprpanel -q; hyprpanel &

    # Ulauncher
    pkill -f ulauncher

    # Obsidian
    pkill -f -i obsidian || true; sleep 0.5
    VAULT_APP="$HOME/Documents/Obsidian Vault/.obsidian/app.json"
    VAULT_APPEAR="$HOME/Documents/Obsidian Vault/.obsidian/appearance.json"
    jq ".baseTheme = \"$obs_base\"" "$VAULT_APP" > "$VAULT_APP.tmp" && mv "$VAULT_APP.tmp" "$VAULT_APP"
    jq ".theme = \"$obs_theme\"" "$VAULT_APPEAR" > "$VAULT_APPEAR.tmp" && mv "$VAULT_APPEAR.tmp" "$VAULT_APPEAR"
    if $relaunch_obs; then
        ( nohup flatpak run md.obsidian.Obsidian >/dev/null 2>&1 & ) \
            || ( nohup obsidian >/dev/null 2>&1 & )
    fi
}

# ══════════════════════════════════════════════════════════════
# MENU PRINCIPAL
# ══════════════════════════════════════════════════════════════

pkill -f feh
nohup ~/.config/.scripts/wallpaper_recognition.sh &

CHOIX=$(echo -e "\n\n󱠃\n󱩹" | rofi -dmenu -theme ~/.config/rofi/wallpaperchoise.rasi)

case "$CHOIX" in
    "")   # Dark — rofi picker
        WP=$(pick_with_rofi "$HOME/Pictures/Wallpapers/dark")
        apply_all "$WP" true
        ;;
    "")   # Light — rofi picker
        WP=$(pick_with_rofi "$HOME/Pictures/Wallpapers/light")
        apply_all "$WP" false
        ;;
    "󱠃")  # Heure — random, dark si soir/nuit
        MOMENT=$(get_moment_journee)
        WP=$(pick_random "$HOME/Pictures/Wallpapers/season-time/$MOMENT")
        [[ "$MOMENT" == "night" || "$MOMENT" == "sunset" ]] && DARK=true || DARK=false
        apply_all "$WP" $DARK
        ;;
    "󱩹")  # Saison — random, light
        SAISON=$(get_saison)
        WP=$(pick_random "$HOME/Pictures/Wallpapers/season-time/$SAISON")
        apply_all "$WP" false
        ;;
    *)
        exit 0
        ;;
esac

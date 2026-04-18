#!/bin/bash

# ── Fonctions ──────────────────────────────────────────────────────────────────
get_moment_journee() {
    HEURE=$(date +"%H")
    if   [ "$HEURE" -ge 7  ] && [ "$HEURE" -lt 18 ]; then echo "day"
    elif [ "$HEURE" -ge 18 ] && [ "$HEURE" -lt 22 ]; then echo "sunset"
    else echo "night"
    fi
}

pick_random() {
    local dir="$1"
    if [ ! -d "$dir" ]; then
        echo "Erreur : $dir n'existe pas." >&2; exit 1
    fi
    WALLPAPER=$(find "$dir" -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.gif" -o -iname "*.webp" \) | shuf -n 1)
    [ -z "$WALLPAPER" ] && { echo "Erreur : Aucune image dans $dir." >&2; exit 1; }
    echo "$WALLPAPER"
}

apply_all() {
    local wallpaper="$1"
    local dark="$2"

    local wal_flags matugen_mode obs_base obs_theme relaunch_obs
    if $dark; then
        wal_flags="-q"; matugen_mode="dark"
        obs_base="dark"; obs_theme="obsidian"; relaunch_obs=true
    else
        wal_flags="-l -q"; matugen_mode="light"
        obs_base="light"; obs_theme="moonstone"; relaunch_obs=false
    fi

    pkill -f feh

    awww img "$wallpaper" --transition-type any --transition-fps 60 --transition-duration 1
    ln -sf "$wallpaper" "$HOME/Pictures/Wallpapers/current_wallpaper.jpg"

    wal -i "$wallpaper" $wal_flags || { echo "Erreur pywal."; exit 1; }

    cp "$wallpaper" /tmp/caca.png
    rm -f /tmp/cacae-0.png

    if [[ "$wallpaper" =~ \.gif$ ]]; then
        magick "$wallpaper[0]" /tmp/caca.png || { echo "Erreur conversion GIF"; exit 1; }
    fi
    magick /tmp/caca.png -resize 30% /tmp/cacae.png
    magick /tmp/caca.png -resize 25% /tmp/cacae-0.png

    HYPRPANEL_CONF="$HOME/.config/hyprpanel/config.json"
    jq ".\"theme.matugen_settings.mode\"=\"$matugen_mode\"" "$HYPRPANEL_CONF" \
        > "$HYPRPANEL_CONF.tmp" && mv "$HYPRPANEL_CONF.tmp" "$HYPRPANEL_CONF"
    hyprpanel -q; hyprpanel &

    pkill -f ulauncher

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

# ── Main ───────────────────────────────────────────────────────────────────────
MOMENT=$(get_moment_journee)
WP=$(pick_random "$HOME/Pictures/Wallpapers/$MOMENT")
[[ "$MOMENT" == "night" || "$MOMENT" == "sunset" ]] && DARK=true || DARK=false
apply_all "$WP" $DARK

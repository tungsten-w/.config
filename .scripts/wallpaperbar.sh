# Changer le wallpaper selon l'heure
HEURE=$(date +"%H")

if [ "$HEURE" -ge 6 ] && [ "$HEURE" -lt 9 ]; then
    ~/.config/.scripts/wallpapersunset.sh
elif [ "$HEURE" -ge 9 ] && [ "$HEURE" -lt 18 ]; then
    ~/.config/.scripts/wallpaperday.sh
elif [ "$HEURE" -ge 18 ] && [ "$HEURE" -lt 21 ]; then
    ~/.config/.scripts/wallpapersunset.sh
else
    ~/.config/.scripts/wallpapernight.sh
fi

killall feh 2>/dev/null

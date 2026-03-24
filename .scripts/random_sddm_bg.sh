#!/bin/bash

WALLPAPER=$(find /home/tungsten/Pictures/Wallpapers/sddm -type f | shuf -n 1)

cp "$WALLPAPER" /usr/share/sddm/themes/glyph/assets/images/background.jpg

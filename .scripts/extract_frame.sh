#!/usr/bin/env bash

# 🔎 Lire le fond d’écran actuel depuis un fichier
WALLPAPER="$(cat ~/.config/hypr/current_wallpaper)"

# ✅ Vérifier que le fichier existe
if [[ ! -f "$WALLPAPER" ]]; then
  echo "❌ Le fond d’écran '$WALLPAPER' est introuvable."
  exit 1
fi

# 📸 Copier le fond vers /tmp/caca.png
cp "$WALLPAPER" /tmp/caca2.png

echo "✅ Fond copié vers /tmp/caca2.png"

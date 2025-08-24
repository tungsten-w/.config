#!/bin/bash

cd ~/.config || exit 1

# Ajout des changements
git add .

# Commit avec date/heure automatique
git commit -m "Auto-commit: $(date '+%Y-%m-%d %H:%M:%S')"

# Push vers ton dépôt
git push

#dire que c ok
/usr/bin/notify-send "Config Backup" " Ta config a été ajoutée a github     "

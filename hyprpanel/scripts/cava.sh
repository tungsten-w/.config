mkdir -p ~/.config/hyprpanel/scripts
cat > ~/.config/hyprpanel/scripts/cava_to_label.sh <<'EOF'
#!/usr/bin/env bash
# Script : lit la sortie raw ascii de cava et renvoie une ligne de barres Unicode.
# Assumes cava is configured to output raw ascii to stdout (see ~/.config/cava/config).

# Start cava (it will write ascii values per frame to stdout)
cava -p "$HOME/.config/cava/config" 2>/dev/null | while read -r line; do
  # line example: "12 34 56 22 0 0 3 5"
  bars=""
  # unicode blocks from empty -> full
  blocks=(" " "▁" "▂" "▃" "▄" "▅" "▆" "▇" "█")
  for v in $line; do
    # v is ascii value from cava. We normalize to 0..8
    # assume v ranges roughly 0..100 (if it's higher, increase scale_max)
    scale_max=100
    n=$(( (v * 8) / scale_max ))
    if [ "$n" -lt 0 ]; then n=0; fi
    if [ "$n" -gt 8 ]; then n=8; fi
    bars="$bars${blocks[$n]}"
  done
  # optional: trim to a max width for HyprPanel
  maxlen=12
  echo "${bars:0:maxlen}"
done
EOF

chmod +x ~/.config/hyprpanel/scripts/cava_to_label.sh

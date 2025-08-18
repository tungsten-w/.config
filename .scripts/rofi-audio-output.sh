#!/bin/bash

choice=$(printf " Changer sortie audio\n Changer micro" | rofi -dmenu -p "Audio")

if [[ $choice == " Changer sortie audio" ]]; then
    # Liste des sorties (sinks)
    SINKS=$(pactl list short sinks | awk '{print $2}')
    CURRENT=$(pactl get-default-sink)
    CHOSEN=$(echo "$SINKS" | rofi -dmenu -p "Sortie audio" -mesg "Actuelle : $CURRENT")

    if [ -n "$CHOSEN" ]; then
        pactl set-default-sink "$CHOSEN"
        # Déplacer tous les flux existants vers la nouvelle sortie
        pactl list short sink-inputs | while read stream; do
            pactl move-sink-input "$(echo $stream | cut -f1)" "$CHOSEN"
        done
    fi

elif [[ $choice == " Changer micro" ]]; then
    # Liste des entrées (sources)
    SOURCES=$(pactl list short sources | awk '{print $2}' | grep -v ".monitor$")
    CURRENT=$(pactl get-default-source)
    CHOSEN=$(echo "$SOURCES" | rofi -dmenu -p "Micro" -mesg "Actuel : $CURRENT")

    if [ -n "$CHOSEN" ]; then
        pactl set-default-source "$CHOSEN"
    fi
fi

#!/bin/bash

status=$(playerctl status 2>/dev/null)

if [ "$status" = "Playing" ]; then
    title=$(playerctl metadata title 2>/dev/null)
    echo "$artist – $title"
else
    echo ""
fi

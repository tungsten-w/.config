#!/usr/bin/env bash

TEMP=$(sensors | grep -m 1 'edge:' | awk '{print $2}' | tr -d '+°C')
echo "{\"text\": \" ${TEMP}°C\", \"tooltip\": \"Température GPU AMD\"}"

#!/bin/bash

HOST="100.86.82.121"

if ping -c 1 -W 1 $HOST &>/dev/null; then
    echo '{"icon":"on","status":"󰣳"}'
else
    echo '{"icon":"off","status":"󰒲"}'
fi

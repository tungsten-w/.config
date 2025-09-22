#!/bin/bash

HOST="100.74.187.3"

if ping -c 1 -W 1 $HOST &>/dev/null; then
    echo '{"icon":"on","status":"󰣳"}'
else
    echo '{"icon":"off","status":"󰒲"}'
fi

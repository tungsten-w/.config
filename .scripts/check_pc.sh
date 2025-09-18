#!/bin/bash

HOST="192.168.1.29"

if ping -c 1 -W 1 $HOST &>/dev/null; then
    echo '{"icon":"on","status":"󰣳"}'
else
    echo '{"icon":"off","status":"󰒲"}'
fi

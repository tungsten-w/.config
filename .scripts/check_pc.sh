#!/bin/bash

#DEFS
HOST1="100.86.82.121"
HOST2="100.67.109.40"
HOST3="100.80.211.22"

#PING
ping1=false
ping2=false
ping3=false

# HOST1
if ping -c 1 -W 1 "$HOST1" &>/dev/null; then
    ping1=true
fi

# HOST2
if ping -c 1 -W 1 "$HOST2" &>/dev/null; then
    ping2=true
fi

# HOST3
if ping -c 1 -W 1 "$HOST2" &>/dev/null; then
    ping3=true
fi

# Display logic
if $ping1 && $ping2 && $ping3 ; then
    echo '{"icon":"both","status":"󰒍"}'   # 3
elif $ping1 && $ping2; then
    echo '{"icon":"both","status":"󰒋"}'   # 2
elif $ping1; then
    echo '{"icon":"host1","status":"󰣳"}' # 1
elif $ping2; then
    echo '{"icon":"host2","status":""}' # 1
else
    echo '{"icon":"off","status":"󰒲"}'   # 0
fi

#replace Host with the ip of your own server ! (0w0)

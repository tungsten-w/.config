#!/bin/bash
#!/bin/bash

HOST1="100.86.82.121"
HOST2="100.86.126.26"

ping1=false
ping2=false

# Test machine 1
if ping -c 1 -W 1 "$HOST1" &>/dev/null; then
    ping1=true
fi

# Test machine 2
if ping -c 1 -W 1 "$HOST2" &>/dev/null; then
    ping2=true
fi

# Logique d'affichage
if $ping1 && $ping2; then
    echo '{"icon":"both","status":"󰒋"}'   # les deux connectées
elif $ping1; then
    echo '{"icon":"host1","status":"󰣳"}' # machine 1 seule
elif $ping2; then
    echo '{"icon":"host2","status":""}' # machine 2 seule
else
    echo '{"icon":"off","status":"󰒲"}'   # aucune
fi

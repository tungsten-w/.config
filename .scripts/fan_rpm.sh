#!/usr/bin/env bash

output=$(sudo fw-ectool pwmgetfanrpm 2>/dev/null)

if [[ "$output" =~ Fan\ 0\ RPM:\ ([0-9]+).*Fan\ 1\ RPM:\ ([0-9]+) ]]; then
    fan0="${BASH_REMATCH[1]}"
    text=" ${fan0} RPM"
else
    text="Fan: N/A"
fi

echo "{\"text\": \"$text\", \"tooltip\": \"Ventilateurs Framework Laptop 16\"}"

#!/bin/bash
upower -i /org/freedesktop/UPower/devices/battery_BAT1 | grep percentage | awk '{print $2}'

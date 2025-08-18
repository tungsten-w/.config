#!/bin/bash
pw-record --target=alsa_output.usb-SteelSeries_SteelSeries_Arctis_1_Wireless-00.analog-stereo.monitor -r 44100 -c 2 --format=s16le /tmp/audio.wav --duration=10
songrec audio-file-to-recognized-song /tmp/audio.wav > /tmp/current_song.json

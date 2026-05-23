#!/usr/bin/env bash

json="$(hyprctl cursorpos -j)"

x="$(jq -r '.x' <<< "$json")"
y="$(jq -r '.y' <<< "$json")"

hyprctl reload
hyprctl dispatch "hl.dsp.cursor.move({x=$x, y=$y})"

pkill quickshell 
hyprctl dispatch 'hl.dsp.exec_cmd("quickshell")'

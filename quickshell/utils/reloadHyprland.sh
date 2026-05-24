#!/usr/bin/env bash

json="$(hyprctl cursorpos -j)"

x="$(jq -r '.x' <<< "$json")"
y="$(jq -r '.y' <<< "$json")"

hyprctl reload
hyprctl dispatch "hl.dsp.cursor.move({x=$x, y=$y})"

/home/miguel/repos/SendaDesktopManager/core/dist/senda shell restart >/tmp/senda-restart.log 2>&1 &

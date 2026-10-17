#!/usr/bin/env bash

json="$(hyprctl cursorpos -j)"

x="$(jq -r '.x' <<< "$json")"
y="$(jq -r '.y' <<< "$json")"

hyprctl reload
hyprctl dispatch "hl.dsp.cursor.move({x=$x, y=$y})"

senda shell restart >/tmp/senda-restart.log 2>&1 &

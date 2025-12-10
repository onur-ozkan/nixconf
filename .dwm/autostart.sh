#!/usr/bin/env bash

# increase cursor speed
xset r rate 200 65

sbs ~/.backgrounds/.firewatch-dark.jpg

dwmblocks &

pipewire &
sleep 2
pipewire-pulse &
sleep 2
wireplumber &

# Trigger volume on dwmblokcs
kill -44 $(pidof dwmblocks)

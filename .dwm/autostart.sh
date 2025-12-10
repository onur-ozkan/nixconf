#!/usr/bin/env bash

# increase cursor speed
xset r rate 200 65

sbs ~/.backgrounds/.firewatch-dark.jpg

dwmblocks &

# Trigger volume on dwmblokcs
kill -44 $(pidof dwmblocks)

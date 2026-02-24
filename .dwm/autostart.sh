#!/usr/bin/env bash

# increase cursor speed
xset r rate 200 65

cache_file="$HOME/.cache/sbs"
backgrounds_dir="$HOME/.backgrounds"
default_bg=".firewatch-dark.jpg"

if [[ -f "$cache_file" ]]; then
  cached_bg="$(head -n 1 "$cache_file")"
else
  cached_bg=""
fi

if [[ -n "$cached_bg" && "$cached_bg" != "NULL" && -f "$backgrounds_dir/$cached_bg" ]]; then
  sbs "$backgrounds_dir/$cached_bg"
elif [[ -f "$backgrounds_dir/$default_bg" ]]; then
  sbs "$backgrounds_dir/$default_bg"
fi

dwmblocks &

# Trigger volume on dwmblokcs
kill -44 $(pidof dwmblocks)

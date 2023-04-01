xrdb -load ~/.Xresources

# Compositor
# xcompmgr -CcfF -I-.015 -O-.03 -D2 -t-1 -l-3 -r4.2 -o.5 &
picom -b

# Override XDG_RUNTIME_DIR
# export XDG_RUNTIME_DIR=/home/nimda/.xdg-override

# Audio
pipewire &
pipewire-pulse &
pipewire-media-session &

# WM
exec dbus-run-session dwm

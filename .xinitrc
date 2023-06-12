xrdb -load ~/.Xresources

# Compositor
# xcompmgr -CcfF -I-.015 -O-.03 -D2 -t-1 -l-3 -r4.2 -o.5 &
picom -b

# Audio
export XDG_RUNTIME_DIR=/home/nimda/.xdg-override

# WM
exec dbus-run-session dwm

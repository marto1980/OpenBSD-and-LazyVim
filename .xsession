# Set encoding for German characters (ü, ä, ö) in terminal
export LC_CTYPE=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8

# Reimport system visual styles (Fixes xconsole colors)
#xrdb -merge /etc/X11/xenodm/Xresources

# Keyboard layout
setxkbmap -layout de,us,bg -option grp:alt_shift_toggle &

# Start XFCE with session management
exec startxfce4

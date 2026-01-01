export LC_CTYPE=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
setxkbmap -layout de,us,bg -option grp:alt_shift_toggle &

exec ck-launch-session startxfce4

#!/bin/sh
# 1. Force the local X11 display context back to the UNIX domain socket on reboot
export DISPLAY=:0.0

# 2. Prevent routing drops: ensure kernel packet forwarding is active
doas sysctl net.inet.ip.forwarding=1 >/dev/null 2>&1

VM_STATUS=$(doas vmctl status debian-worker | grep running)
if [ -z "$VM_STATUS" ]; then
    doas vmctl start debian-worker
    echo "Waiting for guest network to answer ping..."
    while ! ping -c 1 -w 1 100.64.1.3 >/dev/null 2>&1; do
        sleep 1
    done
fi

# 3. Synchronize cookie keys to the guest to prevent authentication drift
scp /home/marto/.sndio/cookie debian@100.64.1.3:/home/debian/.sndio/cookie >/dev/null 2>&1
ssh debian@100.64.1.3 "chmod 600 /home/debian/.sndio/cookie"

# 4. Tear down the restricted global system daemon and any hanging listeners
doas rcctl stop sndiod >/dev/null 2>&1
doas pkill -9 sndiod >/dev/null 2>&1
pkill -9 sndiod >/dev/null 2>&1

# 5. CRITICAL FIX: Launch the host daemon under YOUR user profile (marto) 
# to inherit direct hardware session rights automatically on reboot
sndiod -a off -L 100.64.1.2 -L - >/dev/null 2>&1 &
sleep 2

xhost +127.0.0.1 >/dev/null; xhost +100.64.1.3 >/dev/null

# Direct driver target to completely bypass card 0 fallbacks inside Chrome's sandbox
CHROME_FLAGS="--no-sandbox --test-type --disable-gpu --disable-software-rasterizer --disable-features=AudioServiceSandbox --alsa-output-device=sndio --start-maximized --window-size=1920,1080"

# 6. Vaporize old guest runtimes and stale socket lockfiles via POSIX pkill
ssh debian@100.64.1.3 "pkill -9 google-chrome google-chrome-stable sndiod 2>/dev/null; rm -rf ~/.config/google-chrome/SingletonLock ~/.config/google-chrome/SingletonCookie /tmp/sndio-*"
sleep 1

# 7. Spawn the user proxy cleanly on the guest
ssh debian@100.64.1.3 "sndiod -a off -f snd@100.64.1.2/0 >/dev/null 2>&1 &"

# 8. Polling Loop: Block execution until the guest socket file is physically created
echo "Waiting for guest audio socket to initialize..."
M_RETRY=0
while ! ssh debian@100.64.1.3 "ls -la /tmp/sndio-*/sock0" >/dev/null 2>&1; do
    sleep 1
    M_RETRY=$((M_RETRY + 1))
    if [ $M_RETRY -gt 15 ]; then
        echo "Error: Guest sndiod proxy failed to create an active socket interface."
        exit 1
    fi
done
echo "Audio socket active and verified."

# 9. Execute Chrome safely via SSH X11 forwarding
ssh -X debian@100.64.1.3 "google-chrome $CHROME_FLAGS"


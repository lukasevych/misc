#!/bin/sh

# How to use this:
# 1. Paste the code into a file on the TV (e.g., vi /tmp/update_ts.sh).
# 2. Make it executable: chmod +x /tmp/update_ts.sh
# 3. Run it: /tmp/update_ts.sh
# 4. Start the service: /var/lib/webosbrew/init.d/tailscaled
# 5. Log in: tailscale up

# Version Configuration
TS_VERSION="1.94.2"
TS_ARCH="arm" # Use "arm64" if you are on a very new high-end OLED, but "arm" is standard for most LG TVs
TS_DIST="tailscale_${TS_VERSION}_${TS_ARCH}"
TS_TARBALL="https://pkgs.tailscale.com/stable/${TS_DIST}.tgz"

INSTALL_BINDIR=/media/developer/bin
STATE_DIR=/media/developer/tailscale
INIT_SCRIPT=/var/lib/webosbrew/init.d/tailscaled

# 1. Safety Checks
if [ "$(id -u)" -ne 0 ]; then
    echo "Error: Must be run as root."
    exit 1
fi

if [ ! -f /etc/starfish-release ]; then
    echo "Error: This is not a webOS device."
    exit 1
fi

# 2. Prepare Directories
echo "Preparing directories..."
mkdir -p "$INSTALL_BINDIR"
mkdir -p "$STATE_DIR"

# 3. Download and Extract
echo "Downloading Tailscale v${TS_VERSION}..."
curl -sSL "$TS_TARBALL" | tar -xz -C "$INSTALL_BINDIR" "$TS_DIST/tailscaled" "$TS_DIST/tailscale" --strip-components=1

if [ $? -eq 0 ]; then
    echo "Binaries extracted to $INSTALL_BINDIR"
else
    echo "Download failed!"
    exit 1
fi

# 4. Create the Startup (init.d) Script
echo "Creating init.d script..."
cat <<EOF > "$INIT_SCRIPT"
#!/bin/sh

export PATH=$INSTALL_BINDIR:/usr/sbin:/usr/bin:/sbin:/bin

# Fix DNS (bind-mount resolv.conf so Tailscale can modify it)
if [ ! -f /tmp/resolv.conf ]; then
    cp /etc/resolv.conf /tmp/resolv.conf
    mount -o bind /tmp/resolv.conf /etc/resolv.conf
fi

# Kill any existing instances before starting
killall tailscaled 2>/dev/null

# Start tailscaled with persistent state
$INSTALL_BINDIR/tailscaled \\
    --state=$STATE_DIR/tailscaled.state \\
    --socket=/var/run/tailscale/tailscaled.sock \\
    &> /tmp/tailscaled.log &
EOF

chmod +x "$INIT_SCRIPT"

# 5. Setup PATH in .profile
if ! grep -q "$INSTALL_BINDIR" /home/root/.profile; then
    echo "export PATH=\$PATH:$INSTALL_BINDIR" >> /home/root/.profile
    echo "Added $INSTALL_BINDIR to PATH"
fi

echo "----------------------------------------------------------"
echo "Done! Tailscale v${TS_VERSION} is installed."
echo "1. Start it now: $INIT_SCRIPT"
echo "2. Then log in: tailscale up"
echo "----------------------------------------------------------"
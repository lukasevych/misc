#!/bin/sh

# How to use this:
# 1. Paste the code into a file on the TV (e.g., vi /tmp/update_ts.sh).
# 2. Make it executable: chmod +x /tmp/update_ts.sh
# 3. Run it: /tmp/update_ts.sh
# 4. Start the service: /var/lib/webosbrew/init.d/tailscaled
# 5. Log in: tailscale up
# 6. BONUS:
#   - Force Kills: It runs killall on both the daemon and the client to make sure no files are "busy" during deletion.
#   - Deletes Binaries: It specifically targets the files in /media/developer/bin/ so that only the fresh 1.94.2 versions remain.
#   - Clears Cache: It deletes /home/root/.cache/tailscale-update, which is where your previous manual update attempt stored its files.
#   - Runtime Dir: Added mkdir -p /var/run/tailscale inside the init script. WebOS often clears the /var/run folder on reboot, and without this folder, Tailscale will fail to create its communication socket.

# Version Configuration
TS_VERSION="1.94.2" # UPDATE THIS!
TS_ARCH="arm"
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

# 2. PURGE PREVIOUS INSTALLATION
echo "Cleaning up old Tailscale files..."

# Stop the service if it's running
killall tailscaled 2>/dev/null
killall tailscale 2>/dev/null

# Remove old binaries
rm -f "$INSTALL_BINDIR/tailscale"
rm -f "$INSTALL_BINDIR/tailscaled"

# Remove the update cache from your previous manual update
rm -rf /home/root/.cache/tailscale-update

# Remove old init script to prevent conflicts
rm -f "$INIT_SCRIPT"

echo "Cleanup complete."

# 3. Prepare Directories
echo "Preparing directories..."
mkdir -p "$INSTALL_BINDIR"
mkdir -p "$STATE_DIR"

# 4. Download and Extract
echo "Downloading Tailscale v${TS_VERSION}..."
curl -sSL "$TS_TARBALL" | tar -xz -C "$INSTALL_BINDIR" "$TS_DIST/tailscaled" "$TS_DIST/tailscale" --strip-components=1

if [ $? -eq 0 ]; then
    echo "New binaries (v${TS_VERSION}) placed in $INSTALL_BINDIR"
else
    echo "Download failed! Check your internet connection."
    exit 1
fi

# 5. Create the Modern Startup (init.d) Script
echo "Creating fresh init.d script..."
cat <<EOF > "$INIT_SCRIPT"
#!/bin/sh

export PATH=$INSTALL_BINDIR:/usr/sbin:/usr/bin:/sbin:/bin

# Create required runtime directory
mkdir -p /var/run/tailscale

# Fix DNS (bind-mount resolv.conf so Tailscale can modify it)
if [ ! -f /tmp/resolv.conf ]; then
    cp /etc/resolv.conf /tmp/resolv.conf
    mount -o bind /tmp/resolv.conf /etc/resolv.conf
fi

# Start tailscaled with persistent state on the developer partition
$INSTALL_BINDIR/tailscaled \\
    --state=$STATE_DIR/tailscaled.state \\
    --socket=/var/run/tailscale/tailscaled.sock \\
    &> /tmp/tailscaled.log &
EOF

chmod +x "$INIT_SCRIPT"

# 6. Ensure PATH is set
if ! grep -q "$INSTALL_BINDIR" /home/root/.profile; then
    echo "export PATH=\$PATH:$INSTALL_BINDIR" >> /home/root/.profile
fi

echo "----------------------------------------------------------"
echo "Tailscale has been purged and reinstalled to v${TS_VERSION}"
echo "----------------------------------------------------------"
echo "To start Tailscale now, run:"
echo "$INIT_SCRIPT"
echo ""
echo "Then to log in (if needed), run:"
echo "tailscale up"
echo "----------------------------------------------------------"
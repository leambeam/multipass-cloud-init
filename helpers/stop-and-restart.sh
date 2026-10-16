#!/usr/bin/env bash
#
# Script to run when the multipass daemon gets stuck on macOS

# Stop the daemon
if sudo launchctl print system/com.canonical.multipassd &>/dev/null; then
    sudo launchctl bootout system/com.canonical.multipassd
fi

# Wait for the daemon to exit
while pgrep -x multipassd &>/dev/null; do
    sleep 1
done

# Kill all the Multipass Qemu processes
if pgrep -f 'com.canonical.multipass/bin/qemu-system' &>/dev/null; then
    sudo pkill -9 -f 'com.canonical.multipass/bin/qemu-system'
fi

# Start the daemon
if ! sudo launchctl print system/com.canonical.multipassd &>/dev/null; then
    sudo launchctl bootstrap system /Library/LaunchDaemons/com.canonical.multipassd.plist
fi

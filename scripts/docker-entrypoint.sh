#!/bin/bash
set -e

# Start D-Bus system bus to fix errors like "Failed to connect to the bus"
if [ -f /var/run/dbus/pid ]; then
    rm -f /var/run/dbus/pid
fi
dbus-daemon --system

# Execute the command passed to this script (e.g., supervisord)
exec "$@"


#!/bin/bash
# Main startup script for fingerprint-chromium container

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Set defaults
: "${DISPLAY:=:0}"
: "${WEB_PORT:=6081}"
: "${VNC_PORT:=5901}"
: "${REMOTE_DEBUGGING_PORT:=9222}"
: "${SCREEN_WIDTH:=1280}"
: "${SCREEN_HEIGHT:=800}"
: "${VNC_PASSWORD:=changeme}"
: "${PUID:=1000}"
: "${PGID:=1000}"
: "${UMASK_SET:=022}"

# Set umask
umask "${UMASK_SET}"

log_info "Starting fingerprint-chromium container..."
log_info "Display: ${DISPLAY}"
log_info "Web Port: ${WEB_PORT}"
log_info "VNC Port: ${VNC_PORT}"
log_info "Debug Port: ${REMOTE_DEBUGGING_PORT}"
log_info "Screen: ${SCREEN_WIDTH}x${SCREEN_HEIGHT}"
log_info "PUID: ${PUID}, PGID: ${PGID}"

# Handle PUID/PGID if running as root
if [ "$(id -u)" = "0" ]; then
    log_info "Running as root, handling PUID/PGID..."
    
    if [ "${PUID}" = "0" ]; then
        log_info "PUID=0, running as root user"
        export HOME=/root
        USER_DIR="/root/.chrome-data"
        PROFILE_DIR="/root/.chrome-profiles/default"
        mkdir -p "$USER_DIR" "$PROFILE_DIR"
    else
        log_info "Creating/modifying browser user with PUID=${PUID}, PGID=${PGID}"
        
        # Create group if it doesn't exist
        if ! getent group "${PGID}" >/dev/null 2>&1; then
            groupadd -g "${PGID}" browsergroup
        fi
        
        # Create or modify user
        if id browser >/dev/null 2>&1; then
            usermod -u "${PUID}" -g "${PGID}" browser
        else
            useradd -u "${PUID}" -g "${PGID}" -m -s /bin/bash browser
        fi
        
        # Fix ownership
        chown -R "${PUID}:${PGID}" /home/browser /opt/fingerprint-chromium
        
        # Switch to browser user for the rest of the script
        log_info "Switching to browser user..."
        exec gosu "${PUID}:${PGID}" "$0" "$@"
    fi
fi

# Set environment for VNC
export DISPLAY="${DISPLAY}"
export GEOMETRY="${SCREEN_WIDTH}x${SCREEN_HEIGHT}"

# Start VNC server if not already running
if ! pgrep -f "Xvfb.*${DISPLAY}" >/dev/null; then
    log_info "Starting Xvfb on ${DISPLAY}..."
    Xvfb "${DISPLAY}" -screen 0 "${SCREEN_WIDTH}x${SCREEN_HEIGHT}x24" -ac +extension GLX +render -noreset &
    sleep 2
fi

# Start window manager if not already running
if ! pgrep -f "openbox" >/dev/null; then
    log_info "Starting openbox window manager..."
    openbox &
    sleep 1
fi

# Start VNC server if not already running
if ! pgrep -f "x11vnc.*${DISPLAY}" >/dev/null; then
    log_info "Starting x11vnc server on port ${VNC_PORT}..."
    if [ -n "${VNC_PASSWORD}" ] && [ "${VNC_PASSWORD}" != "changeme" ]; then
        x11vnc -display "${DISPLAY}" -forever -shared -rfbport "${VNC_PORT}" -passwd "${VNC_PASSWORD}" &
    else
        x11vnc -display "${DISPLAY}" -forever -shared -rfbport "${VNC_PORT}" -nopw &
    fi
    sleep 2
fi

# Start noVNC web interface if available
if command -v websockify >/dev/null 2>&1; then
    if ! pgrep -f "websockify.*${WEB_PORT}" >/dev/null; then
        log_info "Starting noVNC web interface on port ${WEB_PORT}..."
        websockify --web=/usr/share/novnc/ "${WEB_PORT}" "localhost:${VNC_PORT}" &
        sleep 2
    fi
else
    log_warning "websockify not available, noVNC web interface will not be started"
fi

# Wait for X server to be ready
log_info "Waiting for X server to be ready..."
for i in {1..30}; do
    if xdpyinfo -display "${DISPLAY}" >/dev/null 2>&1; then
        log_success "X server is ready"
        break
    fi
    if [ $i -eq 30 ]; then
        log_error "X server failed to start"
        exit 1
    fi
    sleep 1
done

# Start fingerprint-chromium
log_info "Starting fingerprint-chromium..."
if [ -x /opt/fingerprint-chromium/start.sh ]; then
    /opt/fingerprint-chromium/start.sh
else
    log_error "fingerprint-chromium start script not found or not executable"
    exit 1
fi

# Keep container running
log_success "All services started successfully!"
log_info "Access methods:"
log_info "  - noVNC web interface: http://localhost:${WEB_PORT}"
log_info "  - VNC client: localhost:${VNC_PORT}"
log_info "  - Chrome DevTools: http://localhost:${REMOTE_DEBUGGING_PORT}"

# Wait for processes
wait

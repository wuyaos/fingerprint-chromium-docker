#!/usr/bin/env bash
set -euo pipefail

# Defaults
: "${DISPLAY:=:0}"
: "${SCREEN_WIDTH:=1280}"
: "${SCREEN_HEIGHT:=800}"
: "${SCREEN_DEPTH:=24}"
: "${REMOTE_DEBUGGING_PORT:=9222}"
: "${VNC_PASSWORD:=changeme}"
: "${FINGERPRINT_SEED:=1000}"
: "${FINGERPRINT_PLATFORM:=linux}"
: "${FINGERPRINT_BRAND:=Chrome}"
: "${FINGERPRINT_BRAND_VERSION:=}"
: "${BROWSER_LANG:=zh-CN}"
: "${ACCEPT_LANG:=zh-CN,zh}"
: "${TIMEZONE:=Asia/Shanghai}"
: "${PROXY_SERVER:=}"
: "${CHROME_EXTRA_ARGS:=}"

XVFB_DISPLAY=${DISPLAY}
CHROME_BIN=${CHROME_BIN:-/opt/fingerprint-chromium/chrome}
USER_DIR=${USER_DIR:-/home/browser/.chrome-data}
PROFILE_BASE_DIR=${PROFILE_BASE_DIR:-/home/browser/.chrome-profiles}
PROFILE_DIR=${PROFILE_DIR:-${PROFILE_BASE_DIR}/default}

# Create user directories with proper permissions step by step
echo "Creating directories..."
mkdir -p "${USER_DIR}" 2>/dev/null || echo "Failed to create ${USER_DIR}"
mkdir -p "${PROFILE_BASE_DIR}" 2>/dev/null || echo "Failed to create ${PROFILE_BASE_DIR}"
mkdir -p "${PROFILE_DIR}" 2>/dev/null || echo "Failed to create ${PROFILE_DIR}"

# Set permissions
chmod 755 "${USER_DIR}" 2>/dev/null || true
chmod 755 "${PROFILE_BASE_DIR}" 2>/dev/null || true
chmod 755 "${PROFILE_DIR}" 2>/dev/null || true

# Test if directories are writable
if ! touch "${USER_DIR}/.test" 2>/dev/null; then
    echo "Warning: ${USER_DIR} is not writable, using fallback directory"
    USER_DIR="/tmp/chrome-data-$$"
    PROFILE_BASE_DIR="/tmp/chrome-profiles-$$"
    PROFILE_DIR="${PROFILE_BASE_DIR}/default"
    mkdir -p "${USER_DIR}" "${PROFILE_DIR}"
    echo "Using fallback directories: ${USER_DIR}, ${PROFILE_DIR}"
fi
rm -f "${USER_DIR}/.test" 2>/dev/null || true

# Create directories with proper permissions (ignore chmod errors for mounted volumes)
mkdir -p "${USER_DIR}" "${PROFILE_DIR}"
chmod 755 "${USER_DIR}" "${PROFILE_DIR}" 2>/dev/null || true

# Create X11 socket directory if it doesn't exist
sudo mkdir -p /tmp/.X11-unix || true
sudo chmod 1777 /tmp/.X11-unix || true

# Start Xvfb with proper permissions
/usr/bin/Xvfb ${XVFB_DISPLAY} -screen 0 ${SCREEN_WIDTH}x${SCREEN_HEIGHT}x${SCREEN_DEPTH} -ac +extension GLX +render -noreset &
XVFB_PID=$!

# Wait for X server to start
sleep 2

# Start window manager (optional but helps rendering)
openbox &

# Start x11vnc for VNC access on :0
x11vnc -display ${XVFB_DISPLAY} -forever -shared -rfbport 5901 -passwd "${VNC_PASSWORD}" -bg -q

# Start noVNC (websockify) serving on 6081 -> connects to VNC 5901
websockify --web=/usr/share/novnc/ 0.0.0.0:6081 127.0.0.1:5901 --daemon

# Setup cache cleanup cron job (runs every 4 hours)
echo "0 */4 * * * /usr/local/bin/cleanup-cache.sh" | crontab -
sudo service cron start

# Build fingerprint-chromium args
FC_ARGS=(
  "--remote-debugging-port=${REMOTE_DEBUGGING_PORT}"
  "--user-data-dir=${USER_DIR}"
  "--lang=${BROWSER_LANG}"
  "--accept-lang=${ACCEPT_LANG}"
  "--fingerprint=${FINGERPRINT_SEED}"
  "--fingerprint-platform=${FINGERPRINT_PLATFORM}"
  "--timezone=${TIMEZONE}"
)

if [[ -n "${FINGERPRINT_BRAND_VERSION}" ]]; then
  FC_ARGS+=("--fingerprint-brand=${FINGERPRINT_BRAND}" "--fingerprint-brand-version=${FINGERPRINT_BRAND_VERSION}")
else
  FC_ARGS+=("--fingerprint-brand=${FINGERPRINT_BRAND}")
fi

if [[ -n "${PROXY_SERVER}" ]]; then
  FC_ARGS+=("--proxy-server=${PROXY_SERVER}")
fi

# Recommended flags for Dockerized Chromium
CHROME_FLAGS=(
  "--no-sandbox"
  "--disable-dev-shm-usage"
  "--disable-gpu"
  "--disable-software-rasterizer"
  "--disable-setuid-sandbox"
  "--disable-background-timer-throttling"
  "--disable-backgrounding-occluded-windows"
  "--disable-renderer-backgrounding"
  "--disable-features=TranslateUI"
  "--disable-ipc-flooding-protection"
  "--no-first-run"
  "--no-default-browser-check"
  "--window-size=${SCREEN_WIDTH},${SCREEN_HEIGHT}"
  "--force-device-scale-factor=1"
)

# Merge extra args
if [[ -n "${CHROME_EXTRA_ARGS}" ]]; then
  # shellcheck disable=SC2206
  EXTRA_ARR=(${CHROME_EXTRA_ARGS})
  CHROME_FLAGS+=("${EXTRA_ARR[@]}")
fi

# Start browser in foreground so container stays alive
exec "${CHROME_BIN}" "${FC_ARGS[@]}" "${CHROME_FLAGS[@]}"
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
USER_DIR=${USER_DIR:-/data}
PROFILE_DIR=${PROFILE_DIR:-/profiles/default}

mkdir -p "${USER_DIR}" "${PROFILE_DIR}"

# Start Xvfb
/usr/bin/Xvfb ${XVFB_DISPLAY} -screen 0 ${SCREEN_WIDTH}x${SCREEN_HEIGHT}x${SCREEN_DEPTH} &
XVFB_PID=$!

# Start window manager (optional but helps rendering)
openbox &

# Start x11vnc for VNC access on :0
x11vnc -display ${XVFB_DISPLAY} -forever -shared -rfbport 5900 -passwd "${VNC_PASSWORD}" -bg -q

# Start noVNC (websockify) serving on 6080 -> connects to VNC 5900
websockify --web=/usr/share/novnc/ 0.0.0.0:6080 127.0.0.1:5900 --daemon

# Build fingerprint-chromium args
FC_ARGS=(
  "--remote-debugging-port=${REMOTE_DEBUGGING_PORT}"
  "--user-data-dir=${USER_DIR}"
  "--lang=${BROWSER_LANG}"
  "--accept-lang=${ACCEPT_LANG}"
  "--fingerprint=${FINGERPRINT_SEED}"
  "--fingerprint-platform=${FINGERPRINT_PLATFORM}"
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
  "--window-size=${SCREEN_WIDTH},${SCREEN_HEIGHT}"
)

# Merge extra args
if [[ -n "${CHROME_EXTRA_ARGS}" ]]; then
  # shellcheck disable=SC2206
  EXTRA_ARR=(${CHROME_EXTRA_ARGS})
  CHROME_FLAGS+=("${EXTRA_ARR[@]}")
fi

# Start browser in foreground so container stays alive
exec "${CHROME_BIN}" "${FC_ARGS[@]}" "${CHROME_FLAGS[@]}"


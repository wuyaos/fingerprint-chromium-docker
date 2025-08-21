# syntax=docker/dockerfile:1.6
# Optimized fingerprint-chromium Docker image based on webvnc

FROM docker.io/xiuxiu10201/webvnc:latest

ARG FC_VERSION=136.0.7103.113
ARG FC_TARBALL="ungoogled-chromium_${FC_VERSION}-1_linux.tar.xz"
ARG FC_URL="https://github.com/adryfish/fingerprint-chromium/releases/download/${FC_VERSION}/${FC_TARBALL}"

# Environment variables
ENV \
    XDG_CONFIG_HOME=/tmp \
    XDG_CACHE_HOME=/tmp \
    HOME=/opt \
    DISPLAY=:0 \
    NOVNC_PORT=6080 \
    VNC_PORT=5900 \
    CHROME_DEBUG_PORT=9222 \
    SCREEN_WIDTH=1280 \
    SCREEN_HEIGHT=800 \
    FINGERPRINT_SEED=1000 \
    FINGERPRINT_PLATFORM=linux \
    FINGERPRINT_BRAND=Chrome \
    FINGERPRINT_BRAND_VERSION="" \
    ACCEPT_LANG="zh-CN,zh" \
    BROWSER_LANG="zh-CN" \
    PROXY_SERVER="" \
    CHROME_EXTRA_ARGS="" \
    PUID=1000 \
    PGID=1000 \
    UMASK_SET=022 \
    TZ=Asia/Shanghai \
    LD_LIBRARY_PATH=/opt/fingerprint-chromium:$LD_LIBRARY_PATH

# Install X11, VNC and runtime dependencies
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        xvfb x11vnc openbox \
        python3 python3-websockify python3-numpy \
        libnss3 libgbm1 libfreetype6 \
        libx11-6 libxcomposite1 libxdamage1 libxi6 libxrandr2 libxrender1 libxtst6 \
        libxext6 libxfixes3 \
        libdrm2 libgl1-mesa-dri libasound2 \
        fonts-dejavu \
        gosu wget \
    && wget -qO- https://github.com/novnc/noVNC/archive/v1.3.0.tar.gz | tar xz -C /opt \
    && mv /opt/noVNC-1.3.0 /opt/novnc \
    && ln -sf /opt/novnc/vnc.html /opt/novnc/index.html \
    && apt-get purge -y wget \
    && apt-get autoremove -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Download and extract fingerprint-chromium in separate step
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl xz-utils \
    && curl -fL "${FC_URL}" -o /tmp/fc.tar.xz \
    && mkdir -p /opt/fingerprint-chromium \
    && tar -xJf /tmp/fc.tar.xz -C /opt/fingerprint-chromium --strip-components=1 \
    && chmod +x /opt/fingerprint-chromium/chrome \
    && apt-get purge -y curl xz-utils \
    && apt-get autoremove -y \
    && apt-get autoclean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /var/cache/apt/archives/*



# Create browser user and setup directories
RUN useradd -m -s /bin/bash browser \
    && echo "browser ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers \
    && mkdir -p /opt/Desktop \
    && mkdir -p /home/browser/.chrome-data \
    && mkdir -p /home/browser/.chrome-profiles/default \
    && mkdir -p /etc/fingerprint-chromium \
    && chmod 755 /home/browser/.chrome-data /home/browser/.chrome-profiles \
    && chmod 777 -R /opt /etc/fingerprint-chromium \
    && chown -R browser:browser /home/browser /opt/fingerprint-chromium

# Create desktop shortcut
RUN echo "[Desktop Entry]" > /opt/Desktop/fingerprint-chromium.desktop \
    && echo "Version=1.0" >> /opt/Desktop/fingerprint-chromium.desktop \
    && echo "Type=Application" >> /opt/Desktop/fingerprint-chromium.desktop \
    && echo "Name=Fingerprint Chromium" >> /opt/Desktop/fingerprint-chromium.desktop \
    && echo "Comment=Privacy-focused Chromium with fingerprint protection" >> /opt/Desktop/fingerprint-chromium.desktop \
    && echo "Exec=/opt/fingerprint-chromium/chrome" >> /opt/Desktop/fingerprint-chromium.desktop \
    && echo "Icon=chromium" >> /opt/Desktop/fingerprint-chromium.desktop \
    && echo "Terminal=false" >> /opt/Desktop/fingerprint-chromium.desktop \
    && echo "Categories=Network;WebBrowser;" >> /opt/Desktop/fingerprint-chromium.desktop \
    && chmod +x /opt/Desktop/fingerprint-chromium.desktop

# Create startup script
RUN echo '#!/bin/bash' > /opt/fingerprint-chromium/start.sh \
    && echo 'set -euo pipefail' >> /opt/fingerprint-chromium/start.sh \
    && echo '' >> /opt/fingerprint-chromium/start.sh \
    && echo '# Handle PUID/PGID' >> /opt/fingerprint-chromium/start.sh \
    && echo 'if [ "${PUID:-1000}" != "$(id -u)" ] || [ "${PGID:-1000}" != "$(id -g)" ]; then' >> /opt/fingerprint-chromium/start.sh \
    && echo '    echo "Adjusting user permissions..."' >> /opt/fingerprint-chromium/start.sh \
    && echo '    if [ "${PUID:-1000}" = "0" ]; then' >> /opt/fingerprint-chromium/start.sh \
    && echo '        USER_DIR="/root/.chrome-data"' >> /opt/fingerprint-chromium/start.sh \
    && echo '        PROFILE_DIR="/root/.chrome-profiles/default"' >> /opt/fingerprint-chromium/start.sh \
    && echo '        mkdir -p "$USER_DIR" "$PROFILE_DIR"' >> /opt/fingerprint-chromium/start.sh \
    && echo '    else' >> /opt/fingerprint-chromium/start.sh \
    && echo '        groupadd -g "${PGID:-1000}" browsergroup 2>/dev/null || true' >> /opt/fingerprint-chromium/start.sh \
    && echo '        usermod -u "${PUID:-1000}" -g "${PGID:-1000}" browser 2>/dev/null || true' >> /opt/fingerprint-chromium/start.sh \
    && echo '        chown -R "${PUID:-1000}:${PGID:-1000}" /home/browser /opt/fingerprint-chromium' >> /opt/fingerprint-chromium/start.sh \
    && echo '        USER_DIR="/home/browser/.chrome-data"' >> /opt/fingerprint-chromium/start.sh \
    && echo '        PROFILE_DIR="/home/browser/.chrome-profiles/default"' >> /opt/fingerprint-chromium/start.sh \
    && echo '    fi' >> /opt/fingerprint-chromium/start.sh \
    && echo 'else' >> /opt/fingerprint-chromium/start.sh \
    && echo '    USER_DIR="/home/browser/.chrome-data"' >> /opt/fingerprint-chromium/start.sh \
    && echo '    PROFILE_DIR="/home/browser/.chrome-profiles/default"' >> /opt/fingerprint-chromium/start.sh \
    && echo 'fi' >> /opt/fingerprint-chromium/start.sh \
    && echo '' >> /opt/fingerprint-chromium/start.sh \
    && echo '# Ensure directories exist' >> /opt/fingerprint-chromium/start.sh \
    && echo 'mkdir -p "$USER_DIR" "$PROFILE_DIR"' >> /opt/fingerprint-chromium/start.sh \
    && echo '' >> /opt/fingerprint-chromium/start.sh \
    && echo '# Build Chrome arguments' >> /opt/fingerprint-chromium/start.sh \
    && echo 'CHROME_ARGS=(' >> /opt/fingerprint-chromium/start.sh \
    && echo '    --test-type' >> /opt/fingerprint-chromium/start.sh \
    && echo '    --disable-backgrounding-occluded-windows' >> /opt/fingerprint-chromium/start.sh \
    && echo '    --user-data-dir="$USER_DIR"' >> /opt/fingerprint-chromium/start.sh \
    && echo '    --profile-directory="default"' >> /opt/fingerprint-chromium/start.sh \
    && echo '    --disable-cache' >> /opt/fingerprint-chromium/start.sh \
    && echo '    --disable-logging' >> /opt/fingerprint-chromium/start.sh \
    && echo '    --disable-notifications' >> /opt/fingerprint-chromium/start.sh \
    && echo '    --no-default-browser-check' >> /opt/fingerprint-chromium/start.sh \
    && echo '    --disable-background-networking' >> /opt/fingerprint-chromium/start.sh \
    && echo '    --enable-features=ParallelDownloading' >> /opt/fingerprint-chromium/start.sh \
    && echo '    --start-maximized' >> /opt/fingerprint-chromium/start.sh \
    && echo '    --no-sandbox' >> /opt/fingerprint-chromium/start.sh \
    && echo '    --ignore-certificate-errors' >> /opt/fingerprint-chromium/start.sh \
    && echo '    --disable-dev-shm-usage' >> /opt/fingerprint-chromium/start.sh \
    && echo '    --no-first-run' >> /opt/fingerprint-chromium/start.sh \
    && echo '    --lang="${BROWSER_LANG:-zh-CN}"' >> /opt/fingerprint-chromium/start.sh \
    && echo '    --accept-lang="${ACCEPT_LANG:-zh-CN,zh}"' >> /opt/fingerprint-chromium/start.sh \
    && echo '    --remote-debugging-address=0.0.0.0' >> /opt/fingerprint-chromium/start.sh \
    && echo '    --remote-debugging-port="${REMOTE_DEBUGGING_PORT:-9222}"' >> /opt/fingerprint-chromium/start.sh \
    && echo ')' >> /opt/fingerprint-chromium/start.sh \
    && echo '' >> /opt/fingerprint-chromium/start.sh \
    && echo '# Add fingerprint protection arguments' >> /opt/fingerprint-chromium/start.sh \
    && echo 'if [ -n "${FINGERPRINT_SEED:-}" ]; then' >> /opt/fingerprint-chromium/start.sh \
    && echo '    CHROME_ARGS+=(--fingerprint-seed="${FINGERPRINT_SEED}")' >> /opt/fingerprint-chromium/start.sh \
    && echo 'fi' >> /opt/fingerprint-chromium/start.sh \
    && echo 'if [ -n "${FINGERPRINT_PLATFORM:-}" ]; then' >> /opt/fingerprint-chromium/start.sh \
    && echo '    CHROME_ARGS+=(--fingerprint-platform="${FINGERPRINT_PLATFORM}")' >> /opt/fingerprint-chromium/start.sh \
    && echo 'fi' >> /opt/fingerprint-chromium/start.sh \
    && echo 'if [ -n "${FINGERPRINT_BRAND:-}" ]; then' >> /opt/fingerprint-chromium/start.sh \
    && echo '    CHROME_ARGS+=(--fingerprint-brand="${FINGERPRINT_BRAND}")' >> /opt/fingerprint-chromium/start.sh \
    && echo 'fi' >> /opt/fingerprint-chromium/start.sh \
    && echo '' >> /opt/fingerprint-chromium/start.sh \
    && echo '# Add proxy if specified' >> /opt/fingerprint-chromium/start.sh \
    && echo 'if [ -n "${PROXY_SERVER:-}" ]; then' >> /opt/fingerprint-chromium/start.sh \
    && echo '    CHROME_ARGS+=(--proxy-server="${PROXY_SERVER}")' >> /opt/fingerprint-chromium/start.sh \
    && echo 'fi' >> /opt/fingerprint-chromium/start.sh \
    && echo '' >> /opt/fingerprint-chromium/start.sh \
    && echo '# Add extra arguments' >> /opt/fingerprint-chromium/start.sh \
    && echo 'if [ -n "${CHROME_EXTRA_ARGS:-}" ]; then' >> /opt/fingerprint-chromium/start.sh \
    && echo '    eval "EXTRA_ARGS=($CHROME_EXTRA_ARGS)"' >> /opt/fingerprint-chromium/start.sh \
    && echo '    CHROME_ARGS+=("${EXTRA_ARGS[@]}")' >> /opt/fingerprint-chromium/start.sh \
    && echo 'fi' >> /opt/fingerprint-chromium/start.sh \
    && echo '' >> /opt/fingerprint-chromium/start.sh \
    && echo '# Start fingerprint-chromium' >> /opt/fingerprint-chromium/start.sh \
    && echo 'echo "Starting fingerprint-chromium with args: ${CHROME_ARGS[*]}"' >> /opt/fingerprint-chromium/start.sh \
    && echo 'cd /opt/fingerprint-chromium' >> /opt/fingerprint-chromium/start.sh \
    && echo 'exec ./chrome "${CHROME_ARGS[@]}" >/tmp/fingerprint-chromium.log 2>&1 &' >> /opt/fingerprint-chromium/start.sh \
    && chmod +x /opt/fingerprint-chromium/start.sh

# Create main run script
COPY run.sh /opt/run.sh
RUN chmod +x /opt/run.sh

# Create data directories and set as volumes for persistence
RUN mkdir -p /data/chrome-data /data/chrome-profiles \
    && chown -R browser:browser /data \
    && ln -sf /data/chrome-data /home/browser/.chrome-data \
    && ln -sf /data/chrome-profiles /home/browser/.chrome-profiles

# Declare volumes for data persistence
VOLUME ["/data/chrome-data", "/data/chrome-profiles"]

# Expose ports
EXPOSE 6080 5900 9222

# Health check (simplified)
HEALTHCHECK --interval=30s --timeout=5s --retries=3 --start-period=10s \
    CMD pgrep -f "chrome" >/dev/null || exit 1

# Set working directory and user
WORKDIR /opt
USER browser

# Start command
CMD ["bash", "/opt/run.sh"]

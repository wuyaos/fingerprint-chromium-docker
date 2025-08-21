# syntax=docker/dockerfile:1.6
# Multi-stage build for optimized fingerprint-chromium image

# -------- Stage 1: Download and extract fingerprint-chromium --------
ARG UBUNTU_VERSION=22.04
FROM ubuntu:${UBUNTU_VERSION} AS downloader

ARG FC_VERSION=136.0.7103.113
# Check the release page for a newer matching Linux tarball name if needed
ARG FC_TARBALL="ungoogled-chromium_${FC_VERSION}-1_linux.tar.xz"
ARG FC_URL="https://github.com/adryfish/fingerprint-chromium/releases/download/${FC_VERSION}/${FC_TARBALL}"

# Install minimal tools for downloading
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl ca-certificates xz-utils \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Download and extract fingerprint-chromium
RUN curl -fL "${FC_URL}" -o /tmp/fc.tar.xz \
    && mkdir -p /opt/fingerprint-chromium \
    && tar -xJf /tmp/fc.tar.xz -C /opt/fingerprint-chromium --strip-components=1 \
    && rm -f /tmp/fc.tar.xz \
    && chmod +x /opt/fingerprint-chromium/chrome

# -------- Stage 2: Runtime image --------
FROM ubuntu:${UBUNTU_VERSION}

# Runtime environment variables
ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8 \
    DISPLAY=:0 \
    SCREEN_WIDTH=1280 \
    SCREEN_HEIGHT=800 \
    SCREEN_DEPTH=24 \
    VNC_PASSWORD=changeme \
    TZ=Asia/Shanghai \
    TIMEZONE=Asia/Shanghai \
    FINGERPRINT_SEED=1000 \
    FINGERPRINT_PLATFORM=linux \
    FINGERPRINT_BRAND=Chrome \
    FINGERPRINT_BRAND_VERSION="" \
    ACCEPT_LANG="zh-CN,zh" \
    BROWSER_LANG="zh-CN" \
    PROXY_SERVER="" \
    CHROME_EXTRA_ARGS="" \
    REMOTE_DEBUGGING_PORT=9222

# Install basic tools first
RUN export DEBIAN_FRONTEND=noninteractive \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        sudo cron locales curl ca-certificates \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install X11 and VNC dependencies
RUN export DEBIAN_FRONTEND=noninteractive \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        xvfb x11vnc openbox \
        novnc websockify \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install fonts
RUN export DEBIAN_FRONTEND=noninteractive \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        fonts-dejavu fonts-liberation fonts-noto-cjk \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install Chromium runtime libraries
RUN export DEBIAN_FRONTEND=noninteractive \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        libnss3 libfreetype6 libharfbuzz0b \
        libx11-6 libxcomposite1 libxdamage1 libxi6 libxrandr2 libxrender1 libxtst6 \
        libxext6 libxfixes3 libxkbcommon0 \
        libdrm2 libgbm1 libgl1-mesa-glx \
        libasound2 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Set timezone and locale
RUN ln -snf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime \
    && echo "Asia/Shanghai" > /etc/timezone \
    && (locale-gen en_US.UTF-8 || echo "locale-gen not available") \
    && mkdir -p /opt /var/log/supervisor

# Copy fingerprint-chromium from downloader stage
COPY --from=downloader /opt/fingerprint-chromium /opt/fingerprint-chromium
RUN ln -sf /opt/fingerprint-chromium/chrome /usr/local/bin/chrome

# Create non-root user and setup directories (single layer)
RUN useradd -m -s /bin/bash browser \
    && echo "browser ALL=(ALL) NOPASSWD: /bin/mkdir, /bin/chmod, /usr/bin/find, /bin/rm" >> /etc/sudoers \
    && mkdir -p /home/browser/Downloads \
    && mkdir -p /home/browser/.chrome-data \
    && mkdir -p /home/browser/.chrome-profiles \
    && mkdir -p /home/browser/.chrome-profiles/default \
    && mkdir -p /tmp/.X11-unix \
    && chmod 1777 /tmp/.X11-unix \
    && chmod 755 /home/browser/.chrome-data \
    && chmod 755 /home/browser/.chrome-profiles \
    && chmod 755 /home/browser/.chrome-profiles/default \
    && chown -R browser:browser /home/browser /opt/fingerprint-chromium

# ------- Copy startup and cleanup scripts -------
COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY docker/cleanup-cache.sh /usr/local/bin/cleanup-cache.sh
RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/cleanup-cache.sh

EXPOSE 9222 5901 6081

HEALTHCHECK --interval=30s --timeout=5s --retries=5 CMD curl -sf http://127.0.0.1:${REMOTE_DEBUGGING_PORT}/json/version >/dev/null || exit 1

USER browser
WORKDIR /home/browser

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]


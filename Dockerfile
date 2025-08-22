# fingerprint-chromium Docker Container with noVNC
# 基于 Debian 构建，集成 fingerprint-chromium 浏览器和 noVNC 服务
FROM debian:bullseye-slim

LABEL maintainer="fingerprint-chromium-docker"
LABEL description="fingerprint-chromium browser with noVNC for DrissionPage automation"

# 环境变量配置
ENV DISPLAY=:0 \
    VNC_RESOLUTION="1280x720" \
    VNC_SHARED=false \
    VNC_PASS="" \
    VNC_TITLE="fingerprint-chromium" \
    NOVNC_PORT=6080 \
    PORT=6080 \
    CHROME_DEBUG_PORT=9222 \
    FINGERPRINT_SEED=1000 \
    FINGERPRINT_PLATFORM=linux \
    TZ="Asia/Shanghai" \
    LANG=zh_CN.UTF-8 \
    LANGUAGE=zh_CN:zh \
    LC_ALL=zh_CN.UTF-8 \
    NO_SLEEP=false

# 安装基础依赖
ARG FC_VERSION=136.0.7103.113
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    # 基础工具
        bash curl wget unzip openssl tzdata ca-certificates locales xz-utils \
        # 安装Chromium以自动处理所有依赖项
    chromium \
    # Supervisor
    supervisor \
    # X11和VNC相关
        xvfb x11vnc websockify openbox fonts-noto-cjk dbus-x11 \
    # Python
    python3 python3-pip python3-requests && \
    # 配置 locales
    sed -i -e 's/# zh_CN.UTF-8 UTF-8/zh_CN.UTF-8 UTF-8/' /etc/locale.gen && \
    locale-gen && \
    # 清理
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/*

# 设置时区
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# 下载并安装fingerprint-chromium
ARG FC_VERSION=136.0.7103.113
RUN mkdir -p /opt/fingerprint-chromium && \
    wget -O /tmp/chromium.tar.xz "https://github.com/adryfish/fingerprint-chromium/releases/download/${FC_VERSION}/ungoogled-chromium_${FC_VERSION}-1_linux.tar.xz" && \
    tar -xf /tmp/chromium.tar.xz -C /opt/fingerprint-chromium --strip-components=1 && \
    rm /tmp/chromium.tar.xz && \
    ln -s /opt/fingerprint-chromium/chrome /usr/local/bin/fingerprint-chrome


# 安装noVNC
RUN mkdir -p /opt/novnc && \
    wget -qO- https://github.com/novnc/noVNC/archive/v1.4.0.tar.gz | tar xz --strip 1 -C /opt/novnc

# 创建用户和目录
RUN useradd --create-home --shell /bin/bash chrome && \
    mkdir -p /home/chrome/.config/chrome /home/chrome/Downloads && \
    chown -R chrome:chrome /home/chrome

# 配置浏览器策略以强制安装扩展
RUN mkdir -p /etc/opt/chrome/policies/managed
COPY config/policies.json /etc/opt/chrome/policies/managed/policies.json

# 创建必要的目录
RUN mkdir -p /var/log/supervisor /etc/supervisor/conf.d /tmp/.X11-unix && \
    chmod 1777 /tmp/.X11-unix

# 将用户配置目录声明为VOLUME，以实现数据持久化
VOLUME /home/chrome/.config/chrome

# 复制配置和脚本文件
COPY config/ /config/
COPY scripts/ /usr/local/bin/
RUN chmod +x /usr/local/bin/*.sh

# 生成SSL证书用于noVNC
RUN openssl req -new -newkey rsa:4096 -days 36500 -nodes -x509 \
    -subj "/C=CN/O=fingerprint-chromium/CN=localhost" \
    -keyout /etc/ssl/novnc.key -out /etc/ssl/novnc.cert > /dev/null 2>&1

# 暴露端口
EXPOSE 5900 6080 9222

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:6080/ || exit 1

# 设置工作目录
WORKDIR /root

# 使用supervisor启动服务
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["supervisord", "-c", "/config/supervisord.conf"]

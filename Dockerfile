# fingerprint-chromium Docker Container with noVNC
# 基于Alpine构建，集成fingerprint-chromium浏览器和noVNC服务
FROM alpine:3.20

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
    LC_ALL=C.UTF-8 \
    NO_SLEEP=false

# 安装基础依赖
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.tuna.tsinghua.edu.cn/g' /etc/apk/repositories
RUN apk update
RUN apk add --no-cache \
    # 基础工具
    bash curl wget unzip openssl tzdata ca-certificates \
    # Supervisor
    supervisor \
    # X11和VNC相关
    xvfb x11vnc websockify openbox ttf-noto-cjk \
    # Python
    python3 py3-pip py3-requests && \
    # 清理
    rm -rf /var/cache/apk/* /tmp/*

# 设置时区
RUN cp /usr/share/zoneinfo/$TZ /etc/localtime && \
    echo $TZ > /etc/timezone

# 下载并安装fingerprint-chromium
RUN mkdir -p /opt/fingerprint-chromium && \
    wget -O /tmp/chromium.tar.xz "https://github.com/adryfish/fingerprint-chromium/releases/download/138.0.7204.183/ungoogled-chromium_138.0.7204.183-1_linux.tar.xz" && \
    tar -xf /tmp/chromium.tar.xz -C /opt/fingerprint-chromium --strip-components=1 && \
    rm /tmp/chromium.tar.xz && \
    ln -s /opt/fingerprint-chromium/chrome /usr/local/bin/fingerprint-chrome

# 安装noVNC
RUN mkdir -p /opt/novnc && \
    wget -qO- https://github.com/novnc/noVNC/archive/v1.4.0.tar.gz | tar xz --strip 1 -C /opt/novnc

# 创建用户和目录
RUN adduser -D -s /bin/bash chrome && \
    mkdir -p /home/chrome/.config/chrome /home/chrome/Downloads && \
    chown -R chrome:chrome /home/chrome

# 创建必要的目录
RUN mkdir -p /var/log/supervisor /etc/supervisor/conf.d /tmp/.X11-unix && \
    chmod 1777 /tmp/.X11-unix

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
ENTRYPOINT ["supervisord", "-l", "/var/log/supervisord.log", "-c"]
CMD ["/config/supervisord.conf"]

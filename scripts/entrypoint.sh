#!/bin/bash
set -e

# 输出启动信息
echo "============================================"
echo "fingerprint-chromium Docker Container"
echo "============================================"
echo "noVNC Web Interface: http://localhost:${NOVNC_PORT}"
echo "Chrome Debug Port: ${CHROME_DEBUG_PORT}"
echo "VNC Port: ${VNC_PORT}"
echo "Fingerprint Seed: ${FINGERPRINT_SEED}"
echo "Platform: ${FINGERPRINT_PLATFORM}"
echo "Timezone: ${TZ}"
echo "============================================"

# 确保目录存在
mkdir -p /var/log/supervisor
mkdir -p /tmp/.X11-unix
mkdir -p /home/chrome/.config/chrome
mkdir -p /home/chrome/Downloads

# 设置权限
chmod 1777 /tmp/.X11-unix
chown -R chrome:chrome /home/chrome

# 创建.Xauthority文件
touch /home/chrome/.Xauthority
chown chrome:chrome /home/chrome/.Xauthority

# 启动Xvfb显示服务器
echo "Starting Xvfb display server..."
Xvfb :0 -screen 0 ${SCREEN_WIDTH}x${SCREEN_HEIGHT}x${SCREEN_DEPTH} \
    -ac -nolisten tcp -dpi 96 +extension GLX +render -noreset &
XVFB_PID=$!

# 等待X服务器启动
sleep 3

# 设置DISPLAY环境变量
export DISPLAY=:0

# 启动窗口管理器
echo "Starting window manager..."
DISPLAY=:0 fluxbox &
sleep 2

# 启动VNC服务器
echo "Starting VNC server..."
if [ -n "$VNC_PASSWORD" ]; then
    mkdir -p /home/chrome/.vnc
    echo "$VNC_PASSWORD" | vncpasswd -f > /home/chrome/.vnc/passwd
    chmod 600 /home/chrome/.vnc/passwd
    chown chrome:chrome /home/chrome/.vnc/passwd
    x11vnc -display :0 -forever -usepw -shared -rfbport $VNC_PORT \
        -rfbauth /home/chrome/.vnc/passwd -xkb -noxrecord -noxfixes \
        -noxdamage -wait 5 &
else
    x11vnc -display :0 -forever -nopw -shared -rfbport $VNC_PORT \
        -xkb -noxrecord -noxfixes -noxdamage -wait 5 &
fi
VNC_PID=$!

# 等待VNC服务器启动
sleep 3

# 启动noVNC
echo "Starting noVNC web interface..."
cd /opt/novnc
python3 utils/novnc_proxy --vnc localhost:$VNC_PORT --listen $NOVNC_PORT \
    --web /opt/novnc &
NOVNC_PID=$!

# 等待noVNC启动
sleep 5

# 启动fingerprint-chrome浏览器
echo "Starting fingerprint-chrome browser..."

# Chrome启动参数
CHROME_ARGS=(
    # 指纹相关参数
    "--fingerprint=${FINGERPRINT_SEED}"
    "--fingerprint-platform=${FINGERPRINT_PLATFORM}"
    "--timezone=${TZ}"
    "--lang=${LANG%.*}"
    
    # 调试端口（用于DrissionPage连接）
    "--remote-debugging-address=0.0.0.0"
    "--remote-debugging-port=${CHROME_DEBUG_PORT}"
    
    # 基础参数
    "--user-data-dir=/home/chrome/.config/chrome"
    "--no-sandbox"
    "--disable-dev-shm-usage"
    "--disable-gpu"
    "--disable-software-rasterizer"
    "--disable-background-timer-throttling"
    "--disable-backgrounding-occluded-windows"
    "--disable-renderer-backgrounding"
    "--disable-features=TranslateUI,VizDisplayCompositor"
    "--disable-ipc-flooding-protection"
    
    # 窗口设置
    "--start-maximized"
    "--window-size=${SCREEN_WIDTH},${SCREEN_HEIGHT}"
    
    # 网络相关
    "--disable-web-security"
    "--disable-extensions-except"
    "--disable-plugins-discovery"
    
    # 其他优化
    "--no-first-run"
    "--no-default-browser-check"
    "--disable-default-apps"
    "--disable-popup-blocking"
    "--disable-translate"
    "--disable-logging"
    "--disable-background-networking"
    
    # 共享内存设置
    "--memory-pressure-off"
    "--max_old_space_size=4096"
)

# 切换到chrome用户并启动浏览器
su - chrome -c "DISPLAY=:0 /usr/local/bin/fingerprint-chrome ${CHROME_ARGS[*]}" &
CHROME_PID=$!

echo "All services started successfully!"
echo "============================================"

# 等待所有进程
wait_for_processes() {
    while true; do
        if ! kill -0 $XVFB_PID 2>/dev/null; then
            echo "Xvfb process died, restarting..."
            exit 1
        fi
        if ! kill -0 $VNC_PID 2>/dev/null; then
            echo "VNC process died, restarting..."
            exit 1
        fi
        if ! kill -0 $NOVNC_PID 2>/dev/null; then
            echo "noVNC process died, restarting..."
            exit 1
        fi
        if ! kill -0 $CHROME_PID 2>/dev/null; then
            echo "Chrome process died, restarting..."
            # 重启Chrome
            su - chrome -c "DISPLAY=:0 /usr/local/bin/fingerprint-chrome ${CHROME_ARGS[*]}" &
            CHROME_PID=$!
        fi
        sleep 10
    done
}

# 设置信号处理
cleanup() {
    echo "Shutting down services..."
    kill $CHROME_PID $NOVNC_PID $VNC_PID $XVFB_PID 2>/dev/null || true
    exit 0
}

trap cleanup SIGTERM SIGINT

# 监控进程
wait_for_processes

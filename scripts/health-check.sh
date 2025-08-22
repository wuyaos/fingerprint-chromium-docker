#!/bin/bash

# 健康检查脚本
# 检查各个服务是否正常运行

check_service() {
    local service_name="$1"
    local check_command="$2"
    
    if eval "$check_command"; then
        echo "✓ $service_name is running"
        return 0
    else
        echo "✗ $service_name is not running"
        return 1
    fi
}

echo "Performing health check..."

# 检查X服务器
check_service "X Server" "pgrep Xvfb > /dev/null"
x_status=$?

# 检查VNC服务器
check_service "VNC Server" "pgrep x11vnc > /dev/null"
vnc_status=$?

# 检查noVNC
check_service "noVNC" "curl -s http://localhost:${NOVNC_PORT}/ > /dev/null"
novnc_status=$?

# 检查Chrome调试端口
check_service "Chrome Debug Port" "curl -s http://localhost:${CHROME_DEBUG_PORT}/json > /dev/null"
chrome_status=$?

# 检查Chrome进程
check_service "Chrome Process" "pgrep chrome > /dev/null"
chrome_process_status=$?

# 总体状态
if [ $x_status -eq 0 ] && [ $vnc_status -eq 0 ] && [ $novnc_status -eq 0 ] && [ $chrome_status -eq 0 ] && [ $chrome_process_status -eq 0 ]; then
    echo "All services are healthy"
    exit 0
else
    echo "Some services are not healthy"
    exit 1
fi

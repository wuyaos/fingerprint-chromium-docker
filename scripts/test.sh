#!/bin/bash
set -e

# fingerprint-chromium Docker容器测试脚本

echo "============================================"
echo "fingerprint-chromium Container Test"
echo "============================================"

# 测试函数
test_service() {
    local service_name="$1"
    local test_command="$2"
    local expected_result="$3"
    
    echo -n "测试 $service_name... "
    
    if eval "$test_command"; then
        echo "✓ 通过"
        return 0
    else
        echo "❌ 失败"
        return 1
    fi
}

# 检查Docker是否运行
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker未运行，请启动Docker服务"
    exit 1
fi

# 检查容器是否存在
if ! docker-compose ps | grep -q "fingerprint-chrome"; then
    echo "❌ fingerprint-chrome容器未启动"
    echo "请先运行: docker-compose up -d"
    exit 1
fi

echo "开始测试服务..."

# 等待服务启动
echo "等待服务启动完成..."
sleep 10

# 测试计数器
total_tests=0
passed_tests=0

# 测试容器状态
total_tests=$((total_tests + 1))
if test_service "容器状态" "docker-compose ps | grep -q 'Up'"; then
    passed_tests=$((passed_tests + 1))
fi

# 测试noVNC Web界面
total_tests=$((total_tests + 1))
if test_service "noVNC Web界面" "curl -s -o /dev/null -w '%{http_code}' http://localhost:6080/ | grep -q '200'"; then
    passed_tests=$((passed_tests + 1))
fi

# 测试VNC端口
total_tests=$((total_tests + 1))
if test_service "VNC端口" "nc -z localhost 5900"; then
    passed_tests=$((passed_tests + 1))
fi

# 测试Chrome调试端口
total_tests=$((total_tests + 1))
if test_service "Chrome调试端口" "curl -s http://localhost:9222/json | jq . > /dev/null"; then
    passed_tests=$((passed_tests + 1))
else
    # 如果jq不可用，使用简单的curl测试
    if test_service "Chrome调试端口(简单)" "curl -s http://localhost:9222/json > /dev/null"; then
        passed_tests=$((passed_tests + 1))
    fi
fi

# 测试Chrome进程
total_tests=$((total_tests + 1))
if test_service "Chrome进程" "docker-compose exec -T fingerprint-chrome pgrep chrome > /dev/null"; then
    passed_tests=$((passed_tests + 1))
fi

# 测试X服务器
total_tests=$((total_tests + 1))
if test_service "X服务器" "docker-compose exec -T fingerprint-chrome pgrep Xvfb > /dev/null"; then
    passed_tests=$((passed_tests + 1))
fi

# 测试健康检查
total_tests=$((total_tests + 1))
if test_service "健康检查" "docker-compose exec -T fingerprint-chrome /usr/local/bin/health-check.sh"; then
    passed_tests=$((passed_tests + 1))
fi

echo ""
echo "============================================"
echo "测试结果汇总"
echo "============================================"
echo "总测试数: $total_tests"
echo "通过测试: $passed_tests"
echo "失败测试: $((total_tests - passed_tests))"

if [ $passed_tests -eq $total_tests ]; then
    echo "✓ 所有测试通过！容器工作正常"
    
    echo ""
    echo "服务访问信息："
    echo "- noVNC Web界面: http://localhost:6080"
    echo "- VNC客户端: localhost:5900"
    echo "- Chrome调试端口: http://localhost:9222"
    echo ""
    echo "可以开始使用DrissionPage进行自动化测试了！"
    
    exit 0
else
    echo "❌ 部分测试失败，请检查容器配置"
    
    echo ""
    echo "故障排除建议："
    echo "1. 查看容器日志: docker-compose logs"
    echo "2. 检查端口占用: netstat -tlnp | grep -E '(6080|5900|9222)'"
    echo "3. 重启容器: docker-compose restart"
    echo "4. 重新构建: docker-compose down && docker-compose up --build -d"
    
    exit 1
fi

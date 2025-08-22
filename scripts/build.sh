#!/bin/bash
set -e

# fingerprint-chromium Docker容器构建脚本

echo "============================================"
echo "fingerprint-chromium Docker Container Build"
echo "============================================"

# 检查Docker是否安装
if ! command -v docker &> /dev/null; then
    echo "❌ Docker未安装，请先安装Docker"
    exit 1
fi

# 检查Docker Compose是否安装
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo "❌ Docker Compose未安装，请先安装Docker Compose"
    exit 1
fi

# 创建必要的目录
echo "创建必要的目录..."
mkdir -p downloads chrome_data logs

# 设置目录权限
chmod 755 downloads chrome_data logs

echo "✓ 目录创建完成"

# 构建Docker镜像
echo "开始构建Docker镜像..."
docker build -t fingerprint-chrome:latest .

if [ $? -eq 0 ]; then
    echo "✓ Docker镜像构建成功"
else
    echo "❌ Docker镜像构建失败"
    exit 1
fi

# 显示镜像信息
echo "镜像信息："
docker images fingerprint-chrome:latest

echo "============================================"
echo "构建完成！"
echo ""
echo "使用方法："
echo "1. 启动容器: docker-compose up -d"
echo "2. 查看日志: docker-compose logs -f"
echo "3. 访问Web界面: http://localhost:6080"
echo "4. Chrome调试端口: http://localhost:9222"
echo "============================================"

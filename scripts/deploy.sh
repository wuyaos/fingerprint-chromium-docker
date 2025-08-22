#!/bin/bash
set -e

# fingerprint-chromium Docker容器部署脚本

echo "============================================"
echo "fingerprint-chromium Docker Container Deploy"
echo "============================================"

# 参数处理
ACTION=${1:-"start"}
COMPOSE_FILE="docker-compose.yml"

case $ACTION in
    "start"|"up")
        echo "启动fingerprint-chrome容器..."
        
        # 创建必要的目录
        mkdir -p downloads chrome_data logs
        chmod 755 downloads chrome_data logs
        
        # 启动容器
        docker-compose up -d
        
        if [ $? -eq 0 ]; then
            echo "✓ 容器启动成功"
            
            # 等待服务启动
            echo "等待服务启动..."
            sleep 10
            
            # 检查容器状态
            docker-compose ps
            
            echo ""
            echo "============================================"
            echo "服务访问信息："
            echo "noVNC Web界面: http://localhost:6080"
            echo "VNC端口: localhost:5900"
            echo "Chrome调试端口: http://localhost:9222"
            echo "============================================"
            
            # 检查服务健康状态
            echo "检查服务健康状态..."
            sleep 5
            
            # 检查noVNC
            if curl -s http://localhost:6080/ > /dev/null; then
                echo "✓ noVNC服务正常"
            else
                echo "⚠️ noVNC服务可能未启动"
            fi
            
            # 检查Chrome调试端口
            if curl -s http://localhost:9222/json > /dev/null; then
                echo "✓ Chrome调试端口正常"
            else
                echo "⚠️ Chrome调试端口可能未启动"
            fi
            
        else
            echo "❌ 容器启动失败"
            exit 1
        fi
        ;;
        
    "stop"|"down")
        echo "停止fingerprint-chrome容器..."
        docker-compose down
        echo "✓ 容器已停止"
        ;;
        
    "restart")
        echo "重启fingerprint-chrome容器..."
        docker-compose down
        sleep 2
        docker-compose up -d
        echo "✓ 容器已重启"
        ;;
        
    "logs")
        echo "查看容器日志..."
        docker-compose logs -f
        ;;
        
    "status")
        echo "容器状态："
        docker-compose ps
        
        echo ""
        echo "服务健康检查："
        
        # 检查容器是否运行
        if docker-compose ps | grep -q "Up"; then
            echo "✓ 容器正在运行"
            
            # 检查各个服务
            if curl -s http://localhost:6080/ > /dev/null; then
                echo "✓ noVNC服务正常 (http://localhost:6080)"
            else
                echo "❌ noVNC服务异常"
            fi
            
            if curl -s http://localhost:9222/json > /dev/null; then
                echo "✓ Chrome调试端口正常 (http://localhost:9222)"
            else
                echo "❌ Chrome调试端口异常"
            fi
            
            if nc -z localhost 5900 2>/dev/null; then
                echo "✓ VNC端口正常 (localhost:5900)"
            else
                echo "❌ VNC端口异常"
            fi
        else
            echo "❌ 容器未运行"
        fi
        ;;
        
    "clean")
        echo "清理fingerprint-chrome相关资源..."
        
        # 停止并删除容器
        docker-compose down -v
        
        # 删除镜像
        if docker images | grep -q "fingerprint-chrome"; then
            docker rmi fingerprint-chrome:latest
            echo "✓ 镜像已删除"
        fi
        
        # 清理数据目录（可选）
        read -p "是否删除数据目录 (chrome_data, downloads)? [y/N]: " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -rf chrome_data downloads logs
            echo "✓ 数据目录已删除"
        fi
        
        echo "✓ 清理完成"
        ;;
        
    "build")
        echo "构建fingerprint-chrome镜像..."
        ./scripts/build.sh
        ;;
        
    "help"|*)
        echo "使用方法: $0 [ACTION]"
        echo ""
        echo "可用操作："
        echo "  start/up    - 启动容器"
        echo "  stop/down   - 停止容器"
        echo "  restart     - 重启容器"
        echo "  logs        - 查看日志"
        echo "  status      - 查看状态"
        echo "  clean       - 清理资源"
        echo "  build       - 构建镜像"
        echo "  help        - 显示帮助"
        echo ""
        echo "示例："
        echo "  $0 start    # 启动容器"
        echo "  $0 logs     # 查看日志"
        echo "  $0 status   # 查看状态"
        ;;
esac

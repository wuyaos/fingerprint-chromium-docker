# 快速开始指南

## [object Object]分钟快速部署

### 1. 准备环境
确保已安装：
- Docker 20.10+
- Docker Compose 2.0+

### 2. 构建和启动
```bash
# 克隆或下载项目到本地
# 进入项目目录

# 一键构建和启动
./scripts/build.sh
./scripts/deploy.sh start
```

### 3. 验证服务
```bash
# 运行测试脚本
./scripts/test.sh
```

### 4. 访问服务
- **Web界面**: http://localhost:6080 （无密码，直接连接）
- **Chrome调试**: http://localhost:9222
- **VNC客户端**: localhost:5900

### 5. DrissionPage连接测试
```bash
# 安装依赖
pip install -r examples/requirements.txt

# 运行示例
python examples/drissionpage_example.py
```

## 🔧 常用命令

```bash
# 查看状态
./scripts/deploy.sh status

# 查看日志
./scripts/deploy.sh logs

# 重启服务
./scripts/deploy.sh restart

# 停止服务
./scripts/deploy.sh stop

# 清理资源
./scripts/deploy.sh clean
```

## 📋 环境变量配置

编辑 `docker-compose.yml` 中的环境变量：

```yaml
environment:
  # 屏幕设置
  - SCREEN_WIDTH=1920
  - SCREEN_HEIGHT=1080
  
  # 指纹配置
  - FINGERPRINT_SEED=1000
  - FINGERPRINT_PLATFORM=linux
  
  # 时区语言
  - TZ=Asia/Shanghai
  - LANG=zh_CN.UTF-8
```

## 🐛 故障排除

### 容器启动失败
```bash
# 查看详细日志
docker-compose logs fingerprint-chrome

# 重新构建
docker-compose down
docker-compose up --build -d
```

### 端口冲突
```bash
# 检查端口占用
netstat -tlnp | grep -E '(6080|5900|9222)'

# 修改docker-compose.yml中的端口映射
ports:
  - "16080:6080"  # 改为其他端口
  - "15900:5900"
  - "19222:9222"
```

### 性能问题
```bash
# 增加共享内存
shm_size: 4gb

# 限制资源使用
deploy:
  resources:
    limits:
      memory: 4G
      cpus: '2.0'
```

## 📞 获取帮助

1. 查看完整文档：[README.md](README.md)
2. 运行测试脚本：`./scripts/test.sh`
3. 查看示例代码：`examples/drissionpage_example.py`

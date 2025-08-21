# Fingerprint Chromium Docker

基于webvnc的全新fingerprint-chromium Docker镜像，提供更好的VNC支持和用户体验。

## 🚀 新版本特性

### 1. **基于成熟的webvnc基础镜像**
- 使用 `xiuxiu10201/webvnc:latest` 作为基础镜像
- 内置完整的VNC和noVNC支持
- 更稳定的X11环境

### 2. **完整的PUID/PGID权限管理**
- 智能处理用户权限
- 支持root用户运行（PUID=0）
- 自动用户创建和权限修复

### 3. **优化的启动流程**
- 多阶段构建减小镜像体积
- 智能服务启动顺序
- 完整的健康检查

### 4. **增强的fingerprint保护**
- 完整的fingerprint-chromium参数支持
- 可配置的指纹保护选项
- 支持代理和自定义参数

## 📦 快速开始

### 构建和测试

```bash
# 一键构建和测试
./build-and-test.sh all

# 或分步执行
./build-and-test.sh build   # 仅构建
./build-and-test.sh test    # 仅测试
./build-and-test.sh clean   # 清理
```

### 使用docker-compose

```bash
# 设置用户权限
export PUID=$(id -u)
export PGID=$(id -g)

# 启动服务
docker-compose -f docker-compose.yml up -d

# 查看日志
docker-compose -f docker-compose.yml logs -f
```

### 直接运行

```bash
# 基础运行
docker run -d --name fpc \
  -p 9222:9222 -p 6081:6081 -p 5901:5901 \
  -e PUID=$(id -u) -e PGID=$(id -g) \
  -e VNC_PASSWORD=changeme \
  -e FINGERPRINT_SEED=2025 \
  fingerprint-chromium:latest

# 带数据持久化（推荐）
docker run -d --name fpc \
  -p 9222:9222 -p 6081:6081 -p 5901:5901 \
  -e PUID=$(id -u) -e PGID=$(id -g) \
  -e FINGERPRINT_SEED=2025 \
  -v $(pwd)/data/chrome-data:/data/chrome-data \
  -v $(pwd)/data/chrome-profiles:/data/chrome-profiles \
  wuyaos/fingerprint-chromium-docker:latest
```

## 🌐 访问方式

启动后可通过以下方式访问：

- **noVNC Web界面**: http://localhost:6081
- **VNC客户端**: localhost:5901 (无密码)
- **Chrome DevTools**: http://localhost:9222
- **健康检查**: http://localhost:9222/json/version

## ⚙️ 环境变量配置

### 基础配置
```bash
DISPLAY=:0                    # X11显示
WEB_PORT=6081                # noVNC web端口
VNC_PORT=5901                # VNC端口
REMOTE_DEBUGGING_PORT=9222   # Chrome调试端口
SCREEN_WIDTH=1280            # 屏幕宽度
SCREEN_HEIGHT=800            # 屏幕高度
# VNC无密码访问
```

### 权限管理
```bash
PUID=1000                    # 用户ID
PGID=1000                    # 组ID
UMASK_SET=022               # 文件权限掩码
```

### Fingerprint配置
```bash
FINGERPRINT_SEED=1000        # 指纹种子
FINGERPRINT_PLATFORM=linux  # 平台标识
FINGERPRINT_BRAND=Chrome     # 浏览器品牌
FINGERPRINT_BRAND_VERSION="" # 品牌版本
BROWSER_LANG=zh-CN          # 浏览器语言
ACCEPT_LANG=zh-CN,zh        # 接受语言
```

### 网络配置
```bash
PROXY_SERVER=""             # 代理服务器
CHROME_EXTRA_ARGS=""        # 额外Chrome参数
```

## 🔧 高级用法

### 1. 无头模式运行
```bash
docker run -d --name fpc-headless \
  -p 9223:9222 \
  -e CHROME_EXTRA_ARGS="--headless --disable-gpu" \
  -e FINGERPRINT_SEED=3000 \
  fingerprint-chromium-new:latest
```

### 2. 使用代理
```bash
docker run -d --name fpc-proxy \
  -p 9222:9222 -p 6081:6081 \
  -e PROXY_SERVER="http://proxy.example.com:8080" \
  -e FINGERPRINT_SEED=4000 \
  fingerprint-chromium-new:latest
```

### 3. 自定义Chrome参数
```bash
docker run -d --name fpc-custom \
  -p 9222:9222 -p 6081:6081 \
  -e CHROME_EXTRA_ARGS="--disable-web-security --allow-running-insecure-content" \
  fingerprint-chromium-new:latest
```

## 📊 镜像对比

| 特性 | 旧版本 | 新版本 |
|------|--------|--------|
| 基础镜像 | Ubuntu 22.04 | webvnc:latest |
| VNC支持 | 手动配置 | 内置完整支持 |
| noVNC | 需要安装 | 开箱即用 |
| 权限管理 | 基础支持 | 完整PUID/PGID |
| 启动脚本 | 简单 | 智能化 |
| 健康检查 | 基础 | 完整 |

## 🛠️ 开发和调试

### 进入容器
```bash
docker-compose -f docker-compose.new.yml exec fingerprint-chromium-new bash
```

### 查看日志
```bash
# 容器日志
docker-compose -f docker-compose.new.yml logs -f

# Chrome日志
docker exec fpc-new cat /tmp/fingerprint-chromium.log
```

### 重启服务
```bash
docker-compose -f docker-compose.new.yml restart
```

## 🔍 故障排除

### 1. 权限问题
确保设置了正确的PUID/PGID：
```bash
export PUID=$(id -u)
export PGID=$(id -g)
```

### 2. VNC连接问题
检查VNC密码和端口：
```bash
docker logs fpc-new | grep vnc
```

### 3. Chrome启动问题
查看Chrome日志：
```bash
docker exec fpc-new cat /tmp/fingerprint-chromium.log
```

## 📝 更新日志

### v2.0.0 (新版本)
- 基于webvnc重构
- 完整的PUID/PGID支持
- 智能启动流程
- 增强的错误处理
- 完整的健康检查

### v1.x (旧版本)
- 基于Ubuntu构建
- 基础VNC支持
- 简单权限管理

## 🤝 贡献

欢迎提交Issue和Pull Request来改进这个项目！

## 📄 许可证

MIT License

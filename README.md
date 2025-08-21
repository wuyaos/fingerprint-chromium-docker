# 基于Docker的fingerprint-chromium浏览器容器

本项目提供基于Ubuntu的优化Docker镜像，集成以下功能：
- fingerprint-chromium (adryfish/fingerprint-chromium) 具备隐身指纹特性
- Xvfb + x11vnc + noVNC 实现实时Web界面查看
- Chrome DevTools Protocol 远程调试端口9222，支持DrissionPage连接
- 中国本地化：默认Asia/Shanghai时区、zh-CN语言、CJK字体支持
- 自动缓存清理：每4小时自动清理浏览器缓存和临时文件
- 支持扩展和插件：可安装Chrome扩展程序和插件

## 功能特性

- 远程调试：9222端口暴露
- VNC/noVNC：通过Web界面6081端口或VNC 5901端口实时查看浏览器
- Alpine基础镜像 + glibc兼容层
- 无硬编码敏感信息，通过环境变量配置
- 基于/json/version的健康检查

## 快速开始

本地构建：

```bash
# Ubuntu版本（推荐，更好的兼容性）
docker build -t wuyaos/fingerprint-chromium-docker:latest .

# Alpine版本（更小的镜像体积）
docker build -f Dockerfile.alpine -t wuyaos/fingerprint-chromium-docker:alpine .
```

运行容器：

```bash
docker run --rm -p 9222:9222 -p 6081:6081 -e VNC_PASSWORD=changeme \
  -e FINGERPRINT_SEED=2025 -e FINGERPRINT_PLATFORM=linux \
  -e FINGERPRINT_BRAND=Chrome -e BROWSER_LANG=zh-CN -e ACCEPT_LANG=zh-CN,zh \
  --name fpc wuyaos/fingerprint-chromium-docker:latest
```

或使用特定版本：

```bash
# Ubuntu版本
docker run --rm -p 9222:9222 -p 6081:6081 -e VNC_PASSWORD=changeme \
  -e FINGERPRINT_SEED=2025 -e FINGERPRINT_PLATFORM=linux \
  -e FINGERPRINT_BRAND=Chrome -e BROWSER_LANG=zh-CN -e ACCEPT_LANG=zh-CN,zh \
  --name fpc wuyaos/fingerprint-chromium-docker:136.0.7103.113

# Alpine版本（更小体积）
docker run --rm -p 9222:9222 -p 6081:6081 -e VNC_PASSWORD=changeme \
  -e FINGERPRINT_SEED=2025 -e FINGERPRINT_PLATFORM=linux \
  -e FINGERPRINT_BRAND=Chrome -e BROWSER_LANG=zh-CN -e ACCEPT_LANG=zh-CN,zh \
  --name fpc wuyaos/fingerprint-chromium-docker:136.0.7103.113-alpine
```

在浏览器中打开noVNC界面：
- <http://localhost:6081>
  - 如有提示，使用VNC_PASSWORD指定的密码

验证远程调试：
- <http://localhost:9222/json/version> 应返回JSON数据

## 与DrissionPage配合使用

Python示例代码，通过CDP连接：

```python
from DrissionPage import Chromium

# 连接到运行中容器的CDP端点
c = Chromium(address='127.0.0.1', port=9222)
# 正常使用，例如打开标签页
c.goto('https://www.example.com')
print(c.title)
```

挂载持久化用户数据目录以保留配置文件和扩展：

```bash
docker run -d --name fpc \
  -p 9222:9222 -p 6081:6081 \
  -e VNC_PASSWORD=changeme \
  -v $(pwd)/chrome-data:/home/browser/.chrome-data \
  -v $(pwd)/chrome-profiles:/home/browser/.chrome-profiles \
  wuyaos/fingerprint-chromium-docker:latest
```

## 扩展和插件支持

容器支持安装和使用Chrome扩展程序：

1. **通过noVNC界面安装**：
   - 访问 http://localhost:6081
   - 在浏览器中访问Chrome Web Store
   - 正常安装扩展程序

2. **数据持久化**：
   - 扩展数据保存在 `/home/browser/.chrome-data` 目录
   - 挂载此目录可保留扩展配置

3. **推荐扩展**：
   - uBlock Origin（广告拦截）
   - Proxy SwitchyOmega（代理切换）
   - User-Agent Switcher（用户代理切换）
   - Cookie Editor（Cookie管理）

## 配置说明

环境变量：
- REMOTE_DEBUGGING_PORT (默认 9222)
- SCREEN_WIDTH (默认 1280)
- SCREEN_HEIGHT (默认 800)
- SCREEN_DEPTH (默认 24)
- VNC_PASSWORD (默认 changeme)
- FINGERPRINT_SEED (默认 1000)
- FINGERPRINT_PLATFORM (linux|windows|macos，默认 linux)
- FINGERPRINT_BRAND (Chrome|Edge|Opera|Vivaldi 或自定义，默认 Chrome)
- FINGERPRINT_BRAND_VERSION (可选)
- BROWSER_LANG (默认 zh-CN)
- ACCEPT_LANG (默认 zh-CN,zh)
- TIMEZONE (默认 Asia/Shanghai)
- PROXY_SERVER (可选，例如 <http://host:port>)
- CHROME_EXTRA_ARGS (可选额外参数)

容器运行Chromium时使用的参数：

- --remote-debugging-port=${REMOTE_DEBUGGING_PORT}
- --user-data-dir=/data
- --lang, --accept-lang
- --fingerprint* 以及Docker友好的参数如 --no-sandbox

端口说明：

- 9222: Chrome DevTools
- 5901: VNC (x11vnc)
- 6081: noVNC (web)

## 安全考虑

- 无硬编码凭据
- 在公共主机上暴露端口时，建议在防火墙/反向代理后运行
- 修改VNC_PASSWORD
- 考虑使用防火墙规则限制对9222端口的访问

## CI/CD (GitHub Actions)

本仓库包含 .github/workflows/docker-build.yml，功能如下：

- 手动触发构建 (workflow_dispatch)，可配置fingerprint-chromium版本和基础镜像
- 支持Ubuntu和Alpine两种基础镜像
- 推送到Docker Hub：`wuyaos/fingerprint-chromium-docker`
- 目标平台：linux/amd64（已移除QEMU以提高构建速度）
- 提供标签：
  - Ubuntu: `latest`, `136.0.7103.113`
  - Alpine: `latest-alpine`, `136.0.7103.113-alpine`

所需的GitHub仓库密钥：

- DOCKERHUB_USERNAME (您的Docker Hub用户名)
- DOCKERHUB_TOKEN (Docker Hub访问令牌)

## 健康检查

容器健康状态基于 <http://127.0.0.1:9222/json/version>。

## 注意事项

- fingerprint-chromium Linux制品在构建时下载；如需更新版本请修改Dockerfile中的FC_VERSION
- 基于Ubuntu 22.04，提供最佳兼容性和稳定性
- 自动缓存清理每4小时运行一次，保持容器性能
- 镜像已优化，移除不必要的包以减小体积

## 镜像优化技术

本项目采用了多种Docker镜像瘦身技术，参考腾讯云的镜像优化最佳实践：

### 1. 多阶段构建
- **构建阶段**：下载和解压fingerprint-chromium
- **运行阶段**：只包含运行时必需的文件
- **效果**：避免构建工具污染最终镜像

### 2. 双基础镜像选择
- **Ubuntu 22.04**：更好的兼容性，推荐用于生产环境
- **Alpine Edge**：极致精简，镜像体积更小
- 使用清华大学镜像源加速下载
- 单层安装，减少镜像层数

### 3. 优化的.dockerignore
- 忽略文档、示例、测试文件
- 排除本地数据目录
- 避免不必要文件进入构建上下文

### 4. 镜像分析和压缩工具
```bash
# 分析镜像层和大小
./scripts/analyze-image.sh [镜像名称]

# 压缩镜像用于传输
./scripts/compress-image.sh [镜像名称] [输出目录]
```

### 5. 运行时优化
- 智能缓存清理（每4小时）
- 最小化权限配置
- 精简Chrome启动参数
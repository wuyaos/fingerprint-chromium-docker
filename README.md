# 基于Docker的fingerprint-chromium浏览器容器

本项目提供基于Alpine的Docker镜像，集成以下功能：
- fingerprint-chromium (adryfish/fingerprint-chromium) 具备隐身指纹特性
- Xvfb + x11vnc + noVNC 实现实时Web界面查看
- Chrome DevTools Protocol 远程调试端口9222，支持DrissionPage连接
- 中国本地化：默认Asia/Shanghai时区、zh-CN语言、CJK字体支持

## 功能特性

- 远程调试：9222端口暴露
- VNC/noVNC：通过Web界面6081端口或VNC 5901端口实时查看浏览器
- Alpine基础镜像 + glibc兼容层
- 无硬编码敏感信息，通过环境变量配置
- 基于/json/version的健康检查

## 快速开始

本地构建：

```bash
# Alpine版本（默认，更小的镜像）
docker build -t wuyaos/fingerprint-chromium-docker:latest .

# Ubuntu版本（更好的兼容性）
docker build -f Dockerfile.ubuntu -t wuyaos/fingerprint-chromium-docker:ubuntu .
```

运行容器：

```bash
docker run --rm -p 9222:9222 -p 6081:6081 -e VNC_PASSWORD=changeme \
  -e FINGERPRINT_SEED=2025 -e FINGERPRINT_PLATFORM=linux \
  -e FINGERPRINT_BRAND=Chrome -e BROWSER_LANG=zh-CN -e ACCEPT_LANG=zh-CN,zh \
  --name fpc wuyaos/fingerprint-chromium-docker:latest
```

或直接使用Docker Hub镜像：

```bash
docker run --rm -p 9222:9222 -p 6081:6081 -e VNC_PASSWORD=changeme \
  -e FINGERPRINT_SEED=2025 -e FINGERPRINT_PLATFORM=linux \
  -e FINGERPRINT_BRAND=Chrome -e BROWSER_LANG=zh-CN -e ACCEPT_LANG=zh-CN,zh \
  --name fpc wuyaos/fingerprint-chromium-docker:latest
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

挂载持久化用户数据目录以保留配置文件：

```bash
docker run -d --name fpc \
  -p 9222:9222 -p 6081:6081 \
  -e VNC_PASSWORD=changeme \
  -v $(pwd)/data:/data \
  wuyaos/fingerprint-chromium-docker:latest
```

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
- 支持Alpine和Ubuntu两种基础镜像
- 推送到Docker Hub：`wuyaos/fingerprint-chromium-docker`
- 目标平台：linux/amd64（已移除QEMU以提高构建速度）
- 提供标签：latest（Alpine）、latest-ubuntu（Ubuntu）、git标签、sha

所需的GitHub仓库密钥：

- DOCKERHUB_USERNAME (您的Docker Hub用户名)
- DOCKERHUB_TOKEN (Docker Hub访问令牌)

## 健康检查

容器健康状态基于 <http://127.0.0.1:9222/json/version>。

## 注意事项

- fingerprint-chromium Linux制品在构建时下载；如需更新版本请修改Dockerfile中的FC_VERSION
- Alpine使用musl，我们通过sgerrand包安装glibc以满足Chromium运行时要求
- Ubuntu版本提供更好的兼容性，但镜像体积较大
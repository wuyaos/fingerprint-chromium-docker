# fingerprint-chromium Docker Container

基于Docker的fingerprint-chromium浏览器容器，集成noVNC服务，专为DrissionPage自动化测试设计。

## 🌟 功能特性

- **指纹伪装**: 集成fingerprint-chromium浏览器，具备强大的指纹伪装功能
- **远程调试**: 开放Chrome调试端口(9222)，支持DrissionPage远程连接
- **Web界面**: 集成noVNC服务，可通过Web浏览器实时查看自动化操作过程
- **无密码访问**: 默认无密码配置，便于开发测试使用
- **数据持久化**: 支持Chrome用户数据和下载文件持久化存储
- **健康检查**: 内置健康检查机制，确保服务稳定运行

## 📋 系统要求

- Docker 20.10+
- Docker Compose 2.0+
- 至少2GB可用内存
- 至少5GB可用磁盘空间

## 🚀 快速开始

### 1. 克隆或下载项目文件

确保你有以下文件结构：
```
fingerprint-chrome-docker/
├── Dockerfile
├── docker-compose.yml
├── README.md
├── config/
│   └── supervisord.conf
└── scripts/
    ├── entrypoint.sh
    └── health-check.sh
```

### 2. 使用Docker Compose启动（推荐）

```bash
# 创建必要的目录
mkdir -p downloads chrome_data

# 启动容器
docker-compose up -d

# 查看日志
docker-compose logs -f
```

### 3. 使用Docker命令启动

```bash
# 构建镜像
docker build -t fingerprint-chrome .

# 运行容器
docker run -d \
  --name fingerprint-chrome \
  -p 6080:6080 \
  -p 5900:5900 \
  -p 9222:9222 \
  --shm-size=2g \
  -v $(pwd)/downloads:/home/chrome/Downloads \
  -v $(pwd)/chrome_data:/home/chrome/.config/chrome \
  fingerprint-chrome
```

## 🔧 环境变量配置

| 变量名 | 默认值 | 说明 |
|--------|--------|------|
| `SCREEN_WIDTH` | 1280 | 屏幕宽度 |
| `SCREEN_HEIGHT` | 720 | 屏幕高度 |
| `SCREEN_DEPTH` | 24 | 颜色深度 |
| `VNC_PORT` | 5900 | VNC端口 |
| `NOVNC_PORT` | 6080 | noVNC Web端口 |
| `CHROME_DEBUG_PORT` | 9222 | Chrome调试端口 |
| `VNC_PASSWORD` | 空 | VNC密码（空则无密码） |
| `FINGERPRINT_SEED` | 1000 | 指纹种子 |
| `FINGERPRINT_PLATFORM` | linux | 指纹平台 |
| `TZ` | Asia/Shanghai | 时区 |
| `LANG` | zh_CN.UTF-8 | 语言 |

## 🌐 访问方式

### Web界面访问（noVNC）
- URL: http://localhost:6080
- 无需密码，直接点击"连接"即可查看浏览器界面

### VNC客户端访问
- 地址: localhost:5900
- 密码: 默认无密码（可通过VNC_PASSWORD环境变量设置）

### Chrome调试端口
- 地址: http://localhost:9222
- 用于DrissionPage等自动化工具连接

## 🐍 DrissionPage连接示例

```python
from DrissionPage import ChromiumPage, ChromiumOptions

# 配置Chrome选项
co = ChromiumOptions()
co.set_local_port(9222)  # 连接到容器的调试端口

# 创建页面对象
page = ChromiumPage(co)

# 现在可以正常使用DrissionPage进行自动化操作
page.get('https://www.example.com')
print(page.title)
```

## 📁 目录挂载说明

- `./downloads`: 浏览器下载目录，文件会保存到宿主机
- `./chrome_data`: Chrome用户数据目录，保存浏览器配置和缓存
- `/dev/shm`: 共享内存，提高性能

## 🔍 指纹配置

### 基本指纹设置
通过环境变量配置指纹参数：

```yaml
environment:
  - FINGERPRINT_SEED=2024        # 指纹种子，影响多项指纹特征
  - FINGERPRINT_PLATFORM=windows # 操作系统平台
  - TZ=America/New_York          # 时区设置
```

### 支持的指纹特征
- User-Agent和平台信息
- 操作系统版本
- CPU核心数和内存信息
- 音频指纹
- WebGL图像和元数据
- Canvas指纹
- 字体列表
- WebRTC配置
- 语言和时区

## 🛠️ 故障排除

### 容器无法启动
```bash
# 检查容器状态
docker-compose ps

# 查看详细日志
docker-compose logs fingerprint-chrome
```

### 无法访问Web界面
1. 确认端口映射正确：`docker port fingerprint-chrome`
2. 检查防火墙设置
3. 确认容器健康状态：`docker-compose ps`

### DrissionPage连接失败
1. 确认9222端口已开放
2. 检查Chrome调试接口：`curl http://localhost:9222/json`
3. 确认容器内Chrome进程正常运行

### 性能优化
1. 增加共享内存大小：`shm_size: 4gb`
2. 调整屏幕分辨率以降低资源消耗
3. 限制容器资源使用：
```yaml
deploy:
  resources:
    limits:
      memory: 4G
      cpus: '2.0'
```

## 📊 监控和日志

### 健康检查
容器内置健康检查，监控以下服务：
- X Server (Xvfb)
- VNC Server
- noVNC Web服务
- Chrome调试端口
- Chrome进程

### 日志查看
```bash
# 查看实时日志
docker-compose logs -f

# 查看特定服务日志
docker-compose logs fingerprint-chrome

# 进入容器查看详细日志
docker-compose exec fingerprint-chrome bash
tail -f /var/log/supervisor/*.log
```

## 🔒 安全考虑

1. **生产环境建议**：
   - 设置VNC密码
   - 限制网络访问
   - 使用防火墙规则

2. **网络安全**：
   - 仅在可信网络中使用
   - 考虑使用VPN或SSH隧道

3. **数据安全**：
   - 定期备份用户数据
   - 避免在浏览器中保存敏感信息

## 🚀 自动化部署

### 使用构建脚本
```bash
# 构建镜像
./scripts/build.sh

# 部署容器
./scripts/deploy.sh start

# 查看状态
./scripts/deploy.sh status

# 查看日志
./scripts/deploy.sh logs

# 停止容器
./scripts/deploy.sh stop
```

### 使用示例代码
```bash
# 安装Python依赖
pip install -r examples/requirements.txt

# 运行DrissionPage连接测试
python examples/drissionpage_example.py
```

## 📁 项目结构

```
fingerprint-chrome-docker/
├── Dockerfile                    # Docker镜像构建文件
├── docker-compose.yml           # Docker Compose配置
├── README.md                    # 项目文档
├── config/                      # 配置文件目录
│   └── supervisord.conf        # Supervisor配置
├── scripts/                     # 脚本目录
│   ├── entrypoint.sh           # 容器启动脚本
│   ├── health-check.sh         # 健康检查脚本
│   ├── build.sh                # 构建脚本
│   └── deploy.sh               # 部署脚本
├── examples/                    # 示例代码
│   ├── drissionpage_example.py # DrissionPage连接示例
│   └── requirements.txt        # Python依赖
├── downloads/                   # 浏览器下载目录（自动创建）
├── chrome_data/                # Chrome数据目录（自动创建）
└── logs/                       # 日志目录（自动创建）
```

## 🔧 高级配置

### 自定义指纹参数
```yaml
# docker-compose.yml
environment:
  - FINGERPRINT_SEED=2024
  - FINGERPRINT_PLATFORM=windows
  - TZ=America/New_York
  - SCREEN_WIDTH=1920
  - SCREEN_HEIGHT=1080
```

### 代理设置
在Chrome启动参数中添加代理：
```bash
# 修改entrypoint.sh中的Chrome启动参数
"--proxy-server=http://proxy:port"
```

### 性能优化
```yaml
# docker-compose.yml
deploy:
  resources:
    limits:
      memory: 4G
      cpus: '2.0'
shm_size: 4gb
```

## 📝 更新日志

- v1.0.0: 初始版本，集成fingerprint-chromium和noVNC
- 支持Chrome 138版本
- 完整的指纹伪装功能
- DrissionPage远程连接支持
- 集成noVNC Web界面
- 自动化构建和部署脚本

## 🤝 贡献

欢迎提交Issue和Pull Request来改进这个项目。

### 开发指南
1. Fork本项目
2. 创建功能分支：`git checkout -b feature/new-feature`
3. 提交更改：`git commit -am 'Add new feature'`
4. 推送分支：`git push origin feature/new-feature`
5. 提交Pull Request

## 📞 支持

如果您在使用过程中遇到问题，请：
1. 查看[故障排除](#-故障排除)部分
2. 搜索已有的[Issues](https://github.com/your-repo/issues)
3. 创建新的Issue并提供详细信息

## 📄 许可证

本项目基于MIT许可证开源。fingerprint-chromium基于BSD-3-Clause许可证。

## 🙏 致谢

- [fingerprint-chromium](https://github.com/adryfish/fingerprint-chromium) - 提供指纹浏览器
- [noVNC](https://github.com/novnc/noVNC) - 提供Web VNC客户端
- [DrissionPage](https://github.com/g1879/DrissionPage) - 提供自动化测试框架

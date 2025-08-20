# GitHub Actions 自动构建设置指南

本文档说明如何配置GitHub Actions自动构建和发布Docker镜像。

## 前置条件

1. 将代码推送到GitHub仓库
2. 确保仓库包含本项目的所有文件

## 配置步骤

### 1. 启用GitHub Container Registry (GHCR)

GHCR是免费的，无需额外配置。工作流会自动推送到：
```
ghcr.io/你的用户名/仓库名:latest
```

### 2. 配置Docker Hub（可选）

如果要同时推送到Docker Hub，需要设置以下仓库密钥：

#### 2.1 在Docker Hub创建仓库
1. 登录 [Docker Hub](https://hub.docker.com)
2. 点击 "Create Repository"
3. 输入仓库名，例如：`fingerprint-chromium-drission`
4. 设置为Public或Private

#### 2.2 获取Docker Hub访问令牌
1. 在Docker Hub，点击右上角头像 → Account Settings
2. 选择 "Security" → "New Access Token"
3. 输入描述，选择权限（建议Read, Write, Delete）
4. 复制生成的令牌

#### 2.3 在GitHub仓库设置密钥
1. 进入GitHub仓库页面
2. 点击 "Settings" → "Secrets and variables" → "Actions"
3. 点击 "New repository secret"，添加以下密钥：

| 密钥名 | 值 | 示例 |
|--------|-----|------|
| `DOCKERHUB_REPO` | Docker Hub仓库完整名称 | `docker.io/yourname/fingerprint-chromium-drission` |
| `DOCKERHUB_USERNAME` | Docker Hub用户名 | `yourname` |
| `DOCKERHUB_TOKEN` | 步骤2.2中获取的访问令牌 | `dckr_pat_xxxxx...` |

## 触发构建

### 手动触发
1. 进入GitHub仓库页面
2. 点击 "Actions" 标签
3. 选择 "Build and Publish Docker Image" 工作流
4. 点击 "Run workflow"
5. 输入fingerprint-chromium版本（例如：`136.0.7103.113`）
6. 点击 "Run workflow" 确认

### 可用的fingerprint-chromium版本

参考 [adryfish/fingerprint-chromium releases](https://github.com/adryfish/fingerprint-chromium/releases) 页面，选择有Linux制品的版本：

- `138.0.7204.183`
- `136.0.7103.113`
- `135.0.7049.95`
- `134.0.6998.165`
- `133.0.6943.126`
- `132.0.6834.159`

## 构建结果

成功构建后，镜像将推送到：

### GitHub Container Registry (总是推送)
```bash
# 拉取最新版本
docker pull ghcr.io/你的用户名/仓库名:latest

# 拉取特定版本（如果通过git tag触发）
docker pull ghcr.io/你的用户名/仓库名:v1.0.0
```

### Docker Hub (如果配置了密钥)
```bash
# 拉取最新版本
docker pull docker.io/yourname/fingerprint-chromium-drission:latest

# 拉取特定版本
docker pull docker.io/yourname/fingerprint-chromium-drission:v1.0.0
```

## 使用构建的镜像

```bash
# 使用GHCR镜像
docker run -d --name fpc \
  -p 9222:9222 -p 6081:6081 \
  -e VNC_PASSWORD=changeme \
  ghcr.io/你的用户名/仓库名:latest

# 使用Docker Hub镜像
docker run -d --name fpc \
  -p 9222:9222 -p 6081:6081 \
  -e VNC_PASSWORD=changeme \
  docker.io/yourname/fingerprint-chromium-drission:latest
```

## 故障排除

### 构建失败
1. 检查工作流日志中的错误信息
2. 确认fingerprint-chromium版本存在对应的Linux制品
3. 检查网络连接问题

### 推送到Docker Hub失败
1. 验证DOCKERHUB_*密钥是否正确设置
2. 确认Docker Hub访问令牌权限足够
3. 检查仓库名格式是否正确

### 权限问题
1. 确保GitHub仓库有Actions权限
2. 检查GITHUB_TOKEN是否有packages:write权限（通常默认有）

## 高级配置

### 自动触发构建
如果希望在代码推送时自动构建，可以修改 `.github/workflows/docker-build.yml`：

```yaml
on:
  push:
    branches: [ main, master ]
    tags:
      - 'v*.*.*'
  workflow_dispatch:
    # ... 保持现有配置
```

### 多架构构建
如果需要支持ARM64，可以修改platforms配置：

```yaml
platforms: linux/amd64,linux/arm64
```

注意：ARM64构建时间较长，且fingerprint-chromium可能不支持ARM64。

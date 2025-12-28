# Linux Docker 运行指南

本指南说明如何在 Linux 上使用 Docker 运行 rust-srec 项目。

## 前置要求

### 1. 安装 Docker 和 Docker Compose

```bash
# 更新软件包索引
sudo apt-get update

# 安装必要的依赖
sudo apt-get install -y ca-certificates curl gnupg

# 添加 Docker 官方 GPG 密钥
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# 添加 Docker 仓库
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# 安装 Docker Engine
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 将当前用户添加到 docker 组（避免每次使用 sudo）
sudo usermod -aG docker $USER

# 重新登录或使用以下命令使组更改生效
newgrp docker

# 验证安装
docker --version
docker compose version
```

对于其他 Linux 发行版（如 Fedora、CentOS 等），请参考 [Docker 官方文档](https://docs.docker.com/engine/install/)。

## 快速启动（使用预构建镜像）

> **重要提示**: 本指南将下载路径配置为 `/root/downloads`。所有通过应用下载的流媒体文件将保存在该目录中。

### 1. 进入项目目录

```bash
cd rust-srec/rust-srec
```

### 2. 创建环境变量文件

```bash
# 复制示例配置文件
cp .env.example .env

# 编辑环境变量（重要：必须设置 JWT_SECRET）
nano .env
```

**.env 文件配置示例：**

```bash
# 版本（可选，默认使用 latest）
VERSION=latest

# 端口配置
API_PORT=8080
FRONTEND_PORT=80

# 数据目录
DATA_DIR=./data
CONFIG_DIR=./config
OUTPUT_DIR=/root/downloads

# 数据库配置
DATABASE_URL=sqlite:///app/data/rust-srec.db

# JWT 配置（必须设置）
JWT_SECRET=change-this-to-a-strong-random-secret-at-least-32-characters-long
JWT_ISSUER=rust-srec
JWT_AUDIENCE=rust-srec-api

# Token 过期时间
ACCESS_TOKEN_EXPIRATION_SECS=3600       # 1小时
REFRESH_TOKEN_EXPIRATION_SECS=604800    # 7天

# 密码策略
MIN_PASSWORD_LENGTH=8

# 日志级别
RUST_LOG=info

# 资源限制
CPU_LIMIT=4
MEMORY_LIMIT=4G
CPU_RESERVATION=1
MEMORY_RESERVATION=512M

# 后端 URL（前端使用）
BACKEND_URL=http://rust-srec:8080
```

### 3. 创建必要的目录

```bash
# 创建数据和配置目录
mkdir -p data config

# 创建下载目录（需要 root 权限）
sudo mkdir -p /root/downloads
sudo chmod 755 /root/downloads
```

### 4. 启动服务

```bash
# 使用 docker compose 启动
docker compose up -d

# 查看日志
docker compose logs -f

# 查看服务状态
docker compose ps
```

### 5. 访问应用

- **前端界面**: http://localhost:80
- **后端 API**: http://localhost:8080
- **健康检查**: http://localhost:8080/api/health/ready
- **下载文件位置**: /root/downloads （主机）→ /app/output （容器内）

### 6. 管理服务

```bash
# 停止服务
docker compose stop

# 启动服务
docker compose start

# 重启服务
docker compose restart

# 停止并删除容器
docker compose down

# 停止并删除容器及数据卷
docker compose down -v

# 查看实时日志
docker compose logs -f

# 只查看后端日志
docker compose logs -f rust-srec

# 只查看前端日志
docker compose logs -f frontend
```

## 本地构建（从源码构建镜像）

### 1. 构建后端镜像

```bash
# 在项目根目录
cd /home/user/rust-srec

# 构建后端镜像
docker build -f rust-srec/Dockerfile -t rust-srec:local .
```

### 2. 构建前端镜像

```bash
# 构建前端镜像
cd rust-srec/frontend
docker build -t rust-srec-frontend:local .
```

### 3. 修改 docker-compose.yml 使用本地镜像

创建一个 `docker-compose.local.yml` 覆盖文件：

```yaml
services:
  rust-srec:
    image: rust-srec:local
    build:
      context: ../..
      dockerfile: rust-srec/Dockerfile

  frontend:
    image: rust-srec-frontend:local
    build:
      context: .
      dockerfile: Dockerfile
```

### 4. 使用本地镜像启动

```bash
cd rust-srec
docker compose -f docker-compose.yml -f docker-compose.local.yml up -d --build
```

## 仅运行后端（CLI 工具）

如果你只需要运行后端服务或使用 CLI 工具：

### 方式一：构建并运行后端容器

```bash
# 构建镜像
docker build -f rust-srec/Dockerfile -t rust-srec:local .

# 运行容器
docker run -d \
  --name rust-srec \
  -p 8080:8080 \
  -v $(pwd)/data:/app/data \
  -v /root/downloads:/app/output \
  -e JWT_SECRET="your-secret-key-at-least-32-characters-long" \
  -e DATABASE_URL="sqlite:///app/data/rust-srec.db" \
  -e RUST_LOG=info \
  rust-srec:local
```

### 方式二：使用 Docker 运行 CLI 工具

```bash
# 运行 strev-cli
docker run --rm -it \
  -v $(pwd):/data \
  rust-srec:local \
  /app/rust-srec --help

# 运行 mesio-cli 下载流媒体
docker run --rm -it \
  -v $(pwd)/downloads:/downloads \
  rust-srec:local \
  mesio --progress -o /downloads https://example.com/stream.flv
```

## 常见问题

### 1. 端口冲突

如果端口 80 或 8080 已被占用，修改 `.env` 文件中的端口：

```bash
API_PORT=8088
FRONTEND_PORT=8000
```

### 2. 权限问题

如果遇到文件权限问题：

```bash
# 更改数据目录所有者
sudo chown -R $USER:$USER data config

# 或者设置适当的权限
chmod -R 755 data config

# 下载目录权限（/root/downloads 需要 root 权限）
sudo chmod -R 755 /root/downloads
# 如果需要让普通用户也能访问
sudo chown -R root:$USER /root/downloads
sudo chmod -R 775 /root/downloads
```

### 3. 数据库初始化

首次运行时，数据库会自动创建在 `data/rust-srec.db`。

### 4. 查看容器内部

```bash
# 进入后端容器
docker compose exec rust-srec sh

# 进入前端容器
docker compose exec frontend sh
```

### 5. 清理 Docker 资源

```bash
# 停止并删除所有容器
docker compose down

# 删除未使用的镜像
docker image prune -a

# 删除未使用的卷
docker volume prune

# 完整清理（谨慎使用）
docker system prune -a --volumes
```

## 生产环境建议

### 1. 使用更强的 JWT Secret

```bash
# 生成随机 JWT secret
openssl rand -base64 64
```

### 2. 配置反向代理

建议使用 Nginx 或 Traefik 作为反向代理，并启用 HTTPS。

### 3. 数据备份

定期备份 `data` 目录：

```bash
# 创建备份
tar -czf backup-$(date +%Y%m%d).tar.gz data/

# 恢复备份
tar -xzf backup-20231215.tar.gz
```

### 4. 监控和日志

```bash
# 限制日志大小（已在 docker-compose.yml 中配置）
# 查看资源使用情况
docker stats
```

## 项目架构说明

该项目包含以下组件：

- **rust-srec**: 后端 API 服务（Rust）
  - 提供 RESTful API
  - 流媒体下载和处理
  - 用户认证和授权
  - 包含 `strev-cli` 和 `mesio-cli` 工具

- **frontend**: Web 前端（Node.js + Nuxt）
  - 用户界面
  - 与后端 API 通信

- **依赖服务**:
  - FFmpeg（媒体处理）
  - Streamlink（流媒体提取）
  - SQLite（数据库）

## 更新版本

```bash
# 拉取最新镜像
docker compose pull

# 重启服务
docker compose up -d

# 查看版本
docker compose exec rust-srec ./rust-srec --version
```

## 开发模式

如果你想进行开发并实时看到更改：

```bash
# 使用卷挂载源代码
docker compose -f docker-compose.yml -f docker-compose.dev.yml up
```

## 获取帮助

如遇问题，请查看：

- GitHub Issues: https://github.com/hua0512/rust-srec/issues
- 项目文档: https://github.com/hua0512/rust-srec

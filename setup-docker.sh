#!/bin/bash

# rust-srec Docker 快速设置脚本
# 此脚本将帮助您快速配置并启动 rust-srec 服务

set -e

echo "==================================="
echo "rust-srec Docker 快速设置向导"
echo "==================================="
echo ""

# 检查 Docker 是否已安装
if ! command -v docker &> /dev/null; then
    echo "错误: 未检测到 Docker，请先安装 Docker"
    echo "请参考文档: LINUX_DOCKER_SETUP.md"
    exit 1
fi

if ! command -v docker compose &> /dev/null; then
    echo "错误: 未检测到 Docker Compose，请先安装 Docker Compose"
    echo "请参考文档: LINUX_DOCKER_SETUP.md"
    exit 1
fi

# 进入项目目录
cd "$(dirname "$0")/rust-srec"

# 创建必要的目录
echo "1. 创建必要的目录..."
mkdir -p data config

# 创建下载目录
DOWNLOAD_DIR="/root/downloads"
echo "2. 创建下载目录: $DOWNLOAD_DIR"
if [ ! -d "$DOWNLOAD_DIR" ]; then
    sudo mkdir -p "$DOWNLOAD_DIR"
    sudo chmod 755 "$DOWNLOAD_DIR"
    echo "   ✓ 下载目录已创建"
else
    echo "   ✓ 下载目录已存在"
fi

# 检查 .env 文件
if [ -f ".env" ]; then
    echo ""
    echo "检测到现有的 .env 文件。"
    read -p "是否要重新生成 .env 文件? (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "保留现有 .env 文件"
    else
        rm .env
    fi
fi

# 创建或更新 .env 文件
if [ ! -f ".env" ]; then
    echo "3. 创建环境配置文件..."

    # 生成随机 JWT secret
    JWT_SECRET=$(openssl rand -base64 48 | tr -d "=+/" | cut -c1-64)

    cat > .env << EOF
# Docker 配置
VERSION=latest

# 端口配置
API_PORT=8080
FRONTEND_PORT=80

# 数据目录
DATA_DIR=./data
CONFIG_DIR=./config
OUTPUT_DIR=$DOWNLOAD_DIR

# 数据库配置
DATABASE_URL=sqlite:///app/data/rust-srec.db

# JWT 配置（自动生成）
JWT_SECRET=$JWT_SECRET
JWT_ISSUER=rust-srec
JWT_AUDIENCE=rust-srec-api

# Token 过期时间
ACCESS_TOKEN_EXPIRATION_SECS=3600
REFRESH_TOKEN_EXPIRATION_SECS=604800

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
EOF

    echo "   ✓ .env 文件已创建"
    echo "   ✓ JWT_SECRET 已自动生成"
else
    echo "3. 使用现有的 .env 文件"
fi

echo ""
echo "4. 环境配置摘要:"
echo "   - API 端口: $(grep API_PORT .env | cut -d'=' -f2)"
echo "   - 前端端口: $(grep FRONTEND_PORT .env | cut -d'=' -f2)"
echo "   - 下载目录: $DOWNLOAD_DIR"
echo "   - 数据目录: ./data"
echo "   - 配置目录: ./config"
echo ""

# 询问是否立即启动
read -p "5. 是否现在启动服务? (Y/n): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Nn]$ ]]; then
    echo ""
    echo "设置完成！您可以稍后运行以下命令启动服务:"
    echo "  cd rust-srec"
    echo "  docker compose up -d"
    exit 0
fi

# 拉取最新镜像
echo ""
echo "正在拉取 Docker 镜像..."
docker compose pull

# 启动服务
echo ""
echo "正在启动服务..."
docker compose up -d

# 等待服务启动
echo ""
echo "等待服务启动..."
sleep 5

# 检查服务状态
echo ""
echo "6. 服务状态:"
docker compose ps

echo ""
echo "==================================="
echo "✓ 设置完成！"
echo "==================================="
echo ""
echo "访问地址:"
echo "  - 前端界面: http://localhost:$(grep FRONTEND_PORT .env | cut -d'=' -f2)"
echo "  - 后端 API: http://localhost:$(grep API_PORT .env | cut -d'=' -f2)"
echo "  - 下载位置: $DOWNLOAD_DIR"
echo ""
echo "常用命令:"
echo "  查看日志: docker compose logs -f"
echo "  停止服务: docker compose stop"
echo "  重启服务: docker compose restart"
echo "  停止并删除: docker compose down"
echo ""
echo "详细文档请参考: LINUX_DOCKER_SETUP.md"

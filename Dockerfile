# docker-compose.yml —— 便捷启动方式（等价于下面的 docker run 命令）
# 用法：
#   1) 在本目录先准备好 config.yaml（cp config.yaml.sample config.yaml 并填写）
#   2) 把整个项目目录作为当前目录，执行：docker compose up -d
#
# 说明：
#   - ./ 挂载到容器 /app：源码、config.yaml、data/、logs/ 全部在宿主机
#   - node_modules 用命名卷保留镜像内预编译好的依赖（不会被宿主机挂载覆盖）

services:
  cloudflare-mail-server:
    image: ghcr.io/YOUR_GITHUB_USERNAME/cloudflare-mail-server:latest
    container_name: cloudflare-mail-server
    ports:
      - "3116:3116"
    volumes:
      - ./:/app
      - node_modules:/app/node_modules
    restart: unless-stopped

volumes:
  node_modules:

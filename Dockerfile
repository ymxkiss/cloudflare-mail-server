syntax=docker/dockerfile:1
============================================================
cloudflare-mail-server — Multi-arch Docker image
支持 linux/amd64 与 linux/arm64（如树莓派、Apple Silicon、ARM 服务器）
设计：把"整个项目目录"通过绑定挂载(bind mount)挂到容器的 /app，
配置(config.yaml)、数据库(data/)、日志(logs/) 全部落在宿主机，
仅 node_modules 用命名卷保留镜像内预编译好的版本。
============================================================
---------- 构建阶段 ----------
FROM node:18-bookworm-slim AS builder
WORKDIR /app

安装原生模块编译工具作为兜底（sqlite3 等若缺少预编译包可在此编译）
RUN apt-get update && apt-get install -y --no-install-recommends
python3 make g++
&& rm -rf /var/lib/apt/lists/*

先装依赖，利用 Docker 层缓存
COPY package.json ./
RUN npm install

再复制源码（构建上下文已通过 .dockerignore 排除 node_modules/data/logs/config.yaml）
COPY . .

---------- 运行阶段 ----------
FROM node:18-bookworm-slim AS runtime
WORKDIR /app
ENV NODE_ENV=production
TZ=Asia/Shanghai

从构建阶段复制已装好依赖的完整应用
COPY --from=builder /app /app

兜底：若宿主机未提供 config.yaml，则使用 sample 生成一份（含默认 admin/admin123，需尽快修改）
RUN cp -n config.yaml.sample config.yaml 2>/dev/null || true
&& mkdir -p /app/data /app/logs

端口以 config.yaml 中 server.port 为准（sample 默认 3116，README 的 3001 已过时）
EXPOSE 3116

以 root 运行，保证绑定挂载的宿主机目录（data/logs/config）可写。
如需加固：自行创建非 root 用户并 chown 你的挂载目录，再去掉下面这行。
USER root

CMD ["node", "server.js"]

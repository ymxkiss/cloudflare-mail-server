# syntax=docker/dockerfile:1
# CloudflareMailServer (Express + SQLite + IMAP/Resend) 多架构镜像
# 构建阶段：安装依赖（sqlite3 为原生模块，需编译工具兜底）
FROM node:20-bookworm-slim AS builder
WORKDIR /build
RUN apt-get update \
 && apt-get install -y --no-install-recommends python3 make g++ ca-certificates \
 && rm -rf /var/lib/apt/lists/*
COPY package.json ./
RUN npm install --omit=dev --no-audit --no-fund \
 && npm cache clean --force
COPY . .
# 配置文件和运行数据不进镜像
RUN rm -rf config.yaml data logs .git .github test

# 运行阶段
FROM node:20-bookworm-slim
ARG APP_VERSION=dev
ENV NODE_ENV=production \
    TZ=Asia/Shanghai \
    APP_DIR=/app \
    APP_SRC=/opt/cloudflare-mail-server \
    AUTO_UPDATE=true
RUN apt-get update \
 && apt-get install -y --no-install-recommends tini tzdata ca-certificates \
 && rm -rf /var/lib/apt/lists/*
# 镜像内保存一份“干净”的程序，启动时同步到挂载目录 /app
COPY --from=builder /build ${APP_SRC}
RUN echo "${APP_VERSION}" > ${APP_SRC}/.image-version
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh && mkdir -p ${APP_DIR}
WORKDIR /app
VOLUME ["/app"]
EXPOSE 3116
# 程序只处理 SIGINT 做优雅退出
STOPSIGNAL SIGINT
ENTRYPOINT ["/usr/bin/tini", "--", "docker-entrypoint.sh"]
CMD ["node", "server.js"]

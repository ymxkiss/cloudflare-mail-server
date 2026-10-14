# syntax=docker/dockerfile:1
# Debian 12 slim + Node.js 22 LTS，构建阶段的编译工具不会进入最终运行镜像。
FROM debian:12-slim AS node-base
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl gnupg \
    && mkdir -p /usr/share/keyrings \
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
       | gpg --dearmor -o /usr/share/keyrings/nodesource.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main" \
       > /etc/apt/sources.list.d/nodesource.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends nodejs \
    && apt-get purge -y --auto-remove curl gnupg \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/*

FROM node-base AS build
WORKDIR /app
# sqlite3 含原生扩展；若无预编译包则在此阶段从源码构建。
RUN apt-get update \
    && apt-get install -y --no-install-recommends python3 make g++ \
    && rm -rf /var/lib/apt/lists/*

# 显式复制运行所需文件，避免把宿主机 config.yaml、data 或 logs 打进镜像。
COPY package.json ./
RUN npm install --omit=dev --no-audit --no-fund
COPY server.js ./server.js
COPY config.yaml.sample ./config.yaml.sample
COPY api/ ./api/
COPY public/ ./public/
COPY routes/ ./routes/
COPY utils/ ./utils/
COPY views/ ./views/

FROM node-base AS runtime
ENV NODE_ENV=production
WORKDIR /app
RUN groupadd --system --gid 10001 app \
    && useradd --system --uid 10001 --gid app --home-dir /app --shell /usr/sbin/nologin app \
    && mkdir -p /app/data /app/logs \
    && chown -R 10001:10001 /app
COPY --from=build --chown=10001:10001 /app /app

# 将 stdout/stderr 同时写入 logs/server.log 和 Docker 日志。
# Docker stop 发来的 SIGTERM 会被转发成 SIGINT，以调用应用的连接清理逻辑。
RUN cat > /usr/local/bin/docker-entrypoint.sh <<'EOF'
#!/bin/sh
set -u
cd /app
mkdir -p /app/data /app/logs
if [ -d /app/config.yaml ]; then
    echo "错误：/app/config.yaml 是目录；请先在宿主机创建 config.yaml 文件再挂载。" >&2
    exit 1
fi
if [ ! -f /app/config.yaml ]; then
    cp /app/config.yaml.sample /app/config.yaml
    echo "未发现 config.yaml，已从 config.yaml.sample 创建默认配置；请编辑宿主机配置后重启。"
fi

log_pipe=/tmp/cloudflare-mail-server-log
rm -f "$log_pipe"
mkfifo "$log_pipe"
tee -a /app/logs/server.log < "$log_pipe" &
tee_pid=$!
node /app/server.js > "$log_pipe" 2>&1 &
app_pid=$!
trap 'kill -INT "$app_pid" 2>/dev/null || true' TERM INT
wait "$app_pid"
app_status=$?
wait "$tee_pid" || true
exit "$app_status"
EOF
RUN chmod 0755 /usr/local/bin/docker-entrypoint.sh \
    && chown -R 10001:10001 /app/data /app/logs

USER 10001:10001
EXPOSE 3116
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

#!/bin/sh
set -e
APP_DIR="${APP_DIR:-/app}"
APP_SRC="${APP_SRC:-/opt/cloudflare-mail-server}"
NEW_VER="$(cat "$APP_SRC/.image-version" 2>/dev/null || echo unknown)"
OLD_VER="$(cat "$APP_DIR/.image-version" 2>/dev/null || echo none)"

mkdir -p "$APP_DIR"

# 1. 首次启动（挂载目录为空）：把整个项目复制到挂载目录
if [ ! -f "$APP_DIR/server.js" ]; then
  echo "[entrypoint] 初始化项目到 $APP_DIR (版本 $NEW_VER)"
  cp -a "$APP_SRC"/. "$APP_DIR"/
# 2. 换了新镜像：更新程序代码，保留 config.yaml / data / logs
elif [ "$AUTO_UPDATE" = "true" ] && [ "$NEW_VER" != "$OLD_VER" ]; then
  echo "[entrypoint] 更新程序 $OLD_VER -> $NEW_VER（保留 config.yaml、data、logs）"
  rm -rf "$APP_DIR/node_modules"
  cp -a "$APP_SRC"/. "$APP_DIR"/
fi

# 3. 依赖缺失时补齐
[ -d "$APP_DIR/node_modules" ] || cp -a "$APP_SRC/node_modules" "$APP_DIR/"

# 4. 没有配置文件时用样例生成
if [ ! -f "$APP_DIR/config.yaml" ]; then
  cp "$APP_DIR/config.yaml.sample" "$APP_DIR/config.yaml"
  echo "[entrypoint] 已生成 $APP_DIR/config.yaml，请填写 Cloudflare / IMAP / Resend 配置后重启容器"
fi

mkdir -p "$APP_DIR/data/attachments" "$APP_DIR/logs"
cd "$APP_DIR"
exec "$@"

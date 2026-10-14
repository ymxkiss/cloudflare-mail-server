cloudflare-mail-server Docker 化部署
项目分析
技术栈：Node.js ≥18 + Express + EJS + SQLite（sqlite3 原生模块），v2.0.2；不是 Workers 项目，是普通 Node 服务。
收信：Cloudflare Email Routing 把 *@你的域名 转发到一个真实邮箱（如 Gmail），程序用 IMAP 定时拉取（默认 10 分钟），按收件人分发到各账号。
发信：走 Resend API，以 name@你的域名 发出。
运行时文件（都相对项目根目录）：
config.yaml：固定读项目根目录，缺失时程序会自己写一份默认的
data/database.sqlite、data/attachments/：数据库和附件
logs/
端口：样例配置 3116（环境变量 PORT 可覆盖）。
注意：程序只捕获 SIGINT 做优雅退出，所以镜像设了 STOPSIGNAL SIGINT；默认管理员 admin/admin123，JWT 密钥要改。

mkdir -p /opt/cloudflare-mail-server

docker run -d \
  --name cloudflare-mail-server \
  --restart unless-stopped \
  -p 3116:3116 \
  -e TZ=Asia/Shanghai \
  -e AUTO_UPDATE=true \
  -v /opt/cloudflare-mail-server:/app \
  ghcr.io/ymxkiss/cloudflare-mail-server:latest

# 首次启动后编辑配置，再重启
vi /opt/cloudflare-mail-server/config.yaml
docker restart cloudflare-mail-server


浏览器访问服务器 IP 的 3116 端口，生产环境建议前面套 Nginx/Caddy 上 HTTPS。

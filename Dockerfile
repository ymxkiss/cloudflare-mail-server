# syntax=docker/dockerfile:1
# Node 22 is supported by the upstream project (engines >=18); Bookworm slim is Debian-based.
FROM node:22-bookworm-slim AS build

WORKDIR /opt/cloudflare-mail-server

# sqlite3 may need node-gyp on architectures without a matching prebuilt binary.
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates \
      python3 \
      make \
      g++ \
      pkg-config \
      libsqlite3-dev \
    && rm -rf /var/lib/apt/lists/*

COPY . .

# Defense in depth: remove any literal Cloudflare API-token defaults from the
# runtime copy of utils/config.js. This does not clean Git history; rotate exposed tokens.
RUN python3 - <<'PY'
from pathlib import Path
import re

path = Path("utils/config.js")
if not path.is_file():
    raise SystemExit("Expected utils/config.js in the project build context")
source = path.read_text(encoding="utf-8")
source, count = re.subn(
    r"(\bapiToken\s*:\s*)(?:'[^']*'|\"[^\"]*\"|`[^`]*`)",
    r"\1''",
    source,
)
path.write_text(source, encoding="utf-8")
print(f"Removed {count} apiToken default value(s) from the image source copy.")
PY

# Upstream does not track package-lock.json, so install from package.json.
# Keep dependencies outside /app, which is bind-mounted at runtime.
RUN npm install --omit=dev --no-audit --no-fund \
    && mv node_modules /opt/node_modules

FROM node:22-bookworm-slim AS runtime

ENV NODE_ENV=production \
    PORT=3116 \
    NODE_PATH=/opt/node_modules

RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates \
      libsqlite3-0 \
      libstdc++6 \
    && rm -rf /var/lib/apt/lists/* \
    && install -d -o node -g node /app

COPY --from=build --chown=node:node /opt/cloudflare-mail-server /opt/cloudflare-mail-server
COPY --from=build --chown=node:node /opt/node_modules /opt/node_modules
COPY --chown=node:node docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

RUN chmod 0755 /usr/local/bin/docker-entrypoint.sh

WORKDIR /app
VOLUME ["/app"]
EXPOSE 3116
USER node

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["node", "server.js"]

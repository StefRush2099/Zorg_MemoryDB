FROM node:22-bookworm

LABEL org.opencontainers.image.title="Zorg MemoryDB OpenClaw Template" \
      org.opencontainers.image.description="Self-contained OpenClaw plus PostgreSQL-backed Zorg MemoryDB template" \
      org.opencontainers.image.source="https://github.com/StefRush2099/Zorg_MemoryDB" \
      org.opencontainers.image.vendor="Hyperdine Systems" \
      org.opencontainers.image.licenses="MIT"

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    OPENCLAW_HOME=/home/openclaw/.openclaw \
    OPENCLAW_WORKSPACE=/home/openclaw/.openclaw/workspace \
    PGDATA=/home/openclaw/.openclaw/postgresql/data \
    DB_HOST=127.0.0.1 \
    DB_PORT=5432 \
    DB_NAME=openclaw_memory \
    DB_USER=openclaw_memory \
    OPENCLAW_GATEWAY_PORT=18789 \
    OPENCLAW_GATEWAY_BIND=lan \
    LAN_CHAT_PORT=3001 \
    ENABLE_LAN_CHAT_INTERNAL=true

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
      bash \
      ca-certificates \
      curl \
      git \
      gosu \
      postgresql \
      postgresql-client \
      python3 \
      python3-pip \
      python3-venv \
      tini \
    && rm -rf /var/lib/apt/lists/*

ARG OPENCLAW_VERSION=latest
RUN npm install -g openclaw@${OPENCLAW_VERSION}

WORKDIR /opt/zorg-memorydb
COPY . /opt/zorg-memorydb
RUN chmod +x /opt/zorg-memorydb/scripts/*.sh /opt/zorg-memorydb/scripts/openclaw-db-memory /opt/zorg-memorydb/docker/entrypoint.sh \
    && cd /opt/zorg-memorydb/lan-chat \
    && npm ci \
    && npm run build

EXPOSE 18789 3001
ENTRYPOINT ["/usr/bin/tini", "--", "/opt/zorg-memorydb/docker/entrypoint.sh"]
CMD ["gateway"]

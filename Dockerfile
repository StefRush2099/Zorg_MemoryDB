FROM node:22-bookworm

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
    DB_PASSWORD=openclaw_memory \
    OPENCLAW_GATEWAY_PORT=18789 \
    OPENCLAW_GATEWAY_BIND=lan \
    OPENCLAW_GATEWAY_AUTH=token

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
RUN chmod +x /opt/zorg-memorydb/scripts/*.sh /opt/zorg-memorydb/scripts/openclaw-db-memory /opt/zorg-memorydb/docker/entrypoint.sh

EXPOSE 18789
ENTRYPOINT ["/usr/bin/tini", "--", "/opt/zorg-memorydb/docker/entrypoint.sh"]
CMD ["gateway"]

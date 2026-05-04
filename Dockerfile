FROM node:22-bookworm

ENV DEBIAN_FRONTEND=noninteractive \
    OPENCLAW_HOME=/home/openclaw/.openclaw \
    OPENCLAW_WORKSPACE=/home/openclaw/.openclaw/workspace \
    DB_HOST=postgres \
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
      python3 \
      python3-pip \
      python3-venv \
      postgresql-client \
      tini \
    && rm -rf /var/lib/apt/lists/*

RUN npm install -g openclaw@latest

WORKDIR /opt/zorg-memorydb
COPY . /opt/zorg-memorydb
RUN chmod +x /opt/zorg-memorydb/scripts/*.sh /opt/zorg-memorydb/scripts/openclaw-db-memory /opt/zorg-memorydb/docker/entrypoint.sh

EXPOSE 18789
ENTRYPOINT ["/usr/bin/tini", "--", "/opt/zorg-memorydb/docker/entrypoint.sh"]
CMD ["gateway"]

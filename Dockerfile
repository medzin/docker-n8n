ARG NODE_VERSION=24.16.0

FROM dhi.io/node:${NODE_VERSION}-alpine3.24-dev

ARG N8N_RELEASE_TYPE=stable
ARG N8N_USER_FOLDER=/data
ARG N8N_VERSION=stable

ENV N8N_RELEASE_TYPE=${N8N_RELEASE_TYPE}
ENV N8N_USER_FOLDER=${N8N_USER_FOLDER}
ENV NODE_ENV=production
ENV NODE_PATH=/usr/local/lib/node_modules
ENV SHELL=/bin/sh

RUN apk add --no-cache busybox-binsh && \
    apk --no-cache add --virtual .build-deps-fonts msttcorefonts-installer fontconfig && \
    update-ms-fonts && \
    fc-cache -f && \
    apk del .build-deps-fonts && \
    find /usr/share/fonts/truetype/msttcorefonts/ -type l -exec unlink {} \; && \
    apk add --no-cache \
    git \
    openssh \
    openssl \
    graphicsmagick \
    tini \
    tzdata \
    ca-certificates \
    su-exec \
    shadow \
    libc6-compat \
    python3 \
    py3-setuptools \
    make \
    g++ && \
    rm -rf /tmp/* /root/.npm /root/.cache/node /opt/yarn*

# Alpine 3.24 ships node at /usr/bin; symlink it to /usr/local/bin so the path
# matches what the cloud launch and AppArmor profile expect.
RUN mkdir -p /usr/local/bin && ln -sf /usr/bin/node /usr/local/bin/node

WORKDIR ${N8N_USER_FOLDER}

RUN npm install -g n8n@${N8N_VERSION} && \
    rm -rf /root/.npm /tmp/*

RUN cd ${NODE_PATH}/n8n && \
    npm rebuild sqlite3 && \
    mkdir -p ${N8N_USER_FOLDER}/.n8n && \
    chown -R node:node ${N8N_USER_FOLDER} && \
    rm -rf /root/.npm /tmp/*

COPY docker-entrypoint.sh /

EXPOSE 5678/tcp

HEALTHCHECK --interval=30s --timeout=5s --start-period=30s \
    CMD wget -qO- http://127.0.0.1:5678/healthz || exit 1

ENTRYPOINT ["tini", "--", "/docker-entrypoint.sh"]

LABEL org.opencontainers.image.title="n8n" \
      org.opencontainers.image.description="Workflow Automation Tool" \
      org.opencontainers.image.source="https://github.com/medzin/docker-n8n" \
      org.opencontainers.image.url="https://n8n.io" \
      org.opencontainers.image.version=${N8N_VERSION}

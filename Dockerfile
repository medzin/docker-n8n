ARG NODE_VERSION=22.22.0

FROM dhi.io/node:${NODE_VERSION}-alpine3.22-dev

ARG N8N_USER_FOLDER=/data
ARG N8N_VERSION=stable

ENV N8N_USER_FOLDER=${N8N_USER_FOLDER}
ENV NODE_ENV=production
ENV NODE_ICU_DATA=/usr/local/lib/node_modules/full-icu
ENV NODE_PATH=/opt/nodejs/node-v${NODE_VERSION}/lib/node_modules
ENV SHELL=/bin/sh

RUN apk add --no-cache busybox-binsh && \
    apk --no-cache add --virtual .build-deps-fonts msttcorefonts-installer fontconfig && \
    update-ms-fonts && \
    fc-cache -f && \
    apk del .build-deps-fonts && \
    find /usr/share/fonts/truetype/msttcorefonts/ -type l -exec unlink {} \; && \
    apk update && \
    apk upgrade --no-cache && \
    apk add --no-cache \
    git \
    openssh \
    openssl \
    graphicsmagick=1.3.45-r0 `# pinned to avoid ghostscript-fonts (AGPL)` \
    tini \
    tzdata \
    ca-certificates \
    su-exec \
    shadow \
    libc6-compat && \
    rm -rf /tmp/* /root/.npm /root/.cache/node /opt/yarn*

WORKDIR ${N8N_USER_FOLDER}

RUN npm install -g n8n@${N8N_VERSION}

COPY docker-entrypoint.sh /

RUN cd ${NODE_PATH}/n8n && \
    npm rebuild sqlite3 && \
    ln -s ${NODE_PATH}/n8n/bin/n8n /usr/local/bin/n8n && \
    mkdir -p ${N8N_USER_FOLDER}/.n8n && \
    chown -R node:node ${N8N_USER_FOLDER} && \
    rm -rf /root/.npm /tmp/*

EXPOSE 5678/tcp

ENTRYPOINT ["tini", "--", "/docker-entrypoint.sh"]

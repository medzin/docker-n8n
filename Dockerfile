# n8n ships as a Docker image built from a pnpm-locked monorepo. Installing it
# with `npm install -g n8n` resolves a fresh (lockfile-less) dependency tree
# that is broken for some releases (see https://github.com/n8n-io/n8n/issues/33370),
# so we build ON TOP of the official image instead of reinstalling n8n.
ARG N8N_VERSION=latest

# The apk binary must come from the SAME base n8n builds on, otherwise its
# musl/library linkage won't match. Keep this in sync with the FROM line in
# n8n's docker/images/n8n-base/Dockerfile whenever n8n bumps its base image.
ARG N8N_BASE_IMAGE=dhi.io/node:24.16.0-alpine3.24-dev

# Source stage: only used to lift the apk binary the official image strips out.
FROM ${N8N_BASE_IMAGE} AS apk-src

FROM n8nio/n8n:${N8N_VERSION}

# Re-declare in this stage so it is in scope for the LABEL below.
ARG N8N_VERSION
ARG N8N_USER_FOLDER=/data
ENV N8N_USER_FOLDER=${N8N_USER_FOLDER}

# The entrypoint remaps the runtime user and drops privileges, so it must start
# as root (the official image runs as the non-root `node` user).
USER root

# The official image runs `apk del apk-tools` but keeps /etc/apk and the package
# DB, so restoring just the binary re-enables the package manager without
# disturbing the installed set. We need it for the entrypoint's privilege drop
# (su-exec) and user remap (shadow), and for runtime setup hooks such as the
# Unraid Tailscale integration.
COPY --from=apk-src /sbin/apk /sbin/apk
RUN apk add --no-cache su-exec shadow && \
    # Point node's home at the data volume. su-exec derives HOME from the passwd
    # entry, so this is what makes os.homedir() writes land on the writable,
    # persistent volume rather than the ephemeral /home/node.
    usermod -d "${N8N_USER_FOLDER}" node

COPY docker-entrypoint.sh /

RUN mkdir -p "${N8N_USER_FOLDER}/.n8n" && chown -R node:node "${N8N_USER_FOLDER}"

WORKDIR ${N8N_USER_FOLDER}

EXPOSE 5678/tcp

HEALTHCHECK --interval=30s --timeout=5s --start-period=30s \
    CMD wget -qO- http://127.0.0.1:5678/healthz || exit 1

ENTRYPOINT ["tini", "--", "/docker-entrypoint.sh"]

LABEL org.opencontainers.image.title="n8n" \
      org.opencontainers.image.description="Workflow Automation Tool" \
      org.opencontainers.image.source="https://github.com/medzin/docker-n8n" \
      org.opencontainers.image.url="https://n8n.io" \
      org.opencontainers.image.version=${N8N_VERSION}

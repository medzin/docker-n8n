#!/bin/sh

echo "Starting n8n..."

export UMASK=${UMASK:-022}
umask $UMASK
echo "UMASK set to $UMASK"

PUID=${PUID:-1000}
PGID=${PGID:-1000}
echo "PUID set to $PUID"
echo "PGID set to $PGID"

if [ "$(id -u node)" != "$PUID" ] || [ "$(id -g node)" != "$PGID" ]; then
    echo "Updating node user id to $PUID and group id to $PGID..."
    groupmod -o -g "$PGID" node
    usermod -o -u "$PUID" node
fi

echo "Fixing permissions for $N8N_USER_FOLDER..."
chown -R node:node "$N8N_USER_FOLDER"

if [ -d /opt/custom-certificates ]; then
  echo "Trusting custom certificates from /opt/custom-certificates."
  export NODE_OPTIONS="--use-openssl-ca $NODE_OPTIONS"
  export SSL_CERT_DIR=/opt/custom-certificates
  c_rehash /opt/custom-certificates
fi

if [ "$#" -gt 0 ]; then
  echo "Executing n8n with arguments: $@"
  exec su-exec node n8n "$@"
else
  echo "Executing n8n..."
  exec su-exec node n8n
fi

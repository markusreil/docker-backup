#!/bin/sh
# First start creates the repository, a self-signed TLS cert (persisted in
# the repo volume), and the client conduit user; restarts reuse all three.
# Prints the cert fingerprint for client clusters to pin in their .env.
set -eu

export KOPIA_PASSWORD="${KOPIA_REPOSITORY_PASSWORD:?KOPIA_REPOSITORY_PASSWORD not set}"
REPO=/repo
CERT_DIR="$REPO/certs"
CERT="$CERT_DIR/kopia.cert"
KEY="$CERT_DIR/kopia.key"
FP_FILE="$CERT_DIR/fingerprint"

mkdir -p "$REPO" "$CERT_DIR"

if [ ! -f "$REPO/kopia.repository.f" ]; then
  kopia repository create filesystem --path "$REPO"
fi
kopia repository status >/dev/null 2>&1 \
  || kopia repository connect filesystem --path "$REPO"

kopia server users add "${KOPIA_CLIENT_USER:?}@${KOPIA_CLIENT_HOST:?}" \
  --user-password "${KOPIA_CLIENT_PASSWORD:?KOPIA_CLIENT_PASSWORD not set}" 2>/dev/null \
  || echo "[server] client user exists, keeping stored password"

if [ ! -f "$CERT" ]; then
  openssl req -x509 -newkey rsa:4096 -nodes \
    -keyout "$KEY" -out "$CERT" -days 3650 \
    -subj "/CN=kopia-server" >/dev/null 2>&1
fi
openssl x509 -in "$CERT" -noout -fingerprint -sha256 \
  | cut -d= -f2 | tr -d : | tr 'A-Z' 'a-z' > "$FP_FILE"
echo "[server] cert fingerprint: $(cat "$FP_FILE")"

exec kopia server start \
  --address 0.0.0.0:51515 \
  --tls-cert-file "$CERT" \
  --tls-key-file "$KEY" \
  --server-username "${KOPIA_SERVER_USER:?}" \
  --server-password "${KOPIA_SERVER_PASSWORD:?KOPIA_SERVER_PASSWORD not set}" \
  --server-control-username "${KOPIA_SERVER_USER:?}" \
  --server-control-password "${KOPIA_SERVER_PASSWORD:?KOPIA_SERVER_PASSWORD not set}"

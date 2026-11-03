#!/bin/sh
# Merged backup agent: connect to the central kopia server once, then run
# docker-gen in the background (renders /state/volumes.yaml from the local
# daemon's container labels) while the snapshot loop below backs up every
# listed volume from its explicit /mnt/<volume> mount.
set -eu

export KOPIA_PASSWORD="${KOPIA_CLIENT_PASSWORD:?KOPIA_CLIENT_PASSWORD not set}"
# Persist for later `exec` sessions (kopia needs the user password on every
# invocation); root-only, never leaves the container.
printf '%s' "$KOPIA_PASSWORD" > /etc/backup-agent/repo-password
chmod 600 /etc/backup-agent/repo-password
CONFIG="$HOME/.config/kopia/repository.config"

if [ ! -f "$CONFIG" ]; then
  echo "[agent] connecting to $KOPIA_SERVER_URL ..."
  until kopia repository connect server \
      --url "${KOPIA_SERVER_URL:?KOPIA_SERVER_URL not set}" \
      --server-cert-fingerprint "${KOPIA_SERVER_FINGERPRINT:?KOPIA_SERVER_FINGERPRINT not set}" \
      >/dev/null 2>&1; do
    sleep 5
  done
  echo "[agent] connected"
fi

docker-gen -config /etc/backup-agent/docker-gen.cfg &
GEN_PID=$!

STATE=/state/volumes.yaml
INTERVAL=${AGENT_INTERVAL:-3600}
echo "[agent] waiting for $STATE ..."
while [ ! -f "$STATE" ]; do sleep 5; done

while true; do
  count=$(yq -r '.volumes // [] | length' "$STATE")
  i=0
  while [ "$i" -lt "$count" ]; do
    vol=$(yq -r ".volumes[$i].volume" "$STATE")
    if [ -d "/mnt/$vol" ]; then
      kopia snapshot create "/mnt/$vol" >/dev/null \
        && echo "[agent] snapshotted $vol" \
        || echo "[agent] snapshot failed for $vol"
    else
      echo "[agent] skip $vol (not mounted at /mnt/$vol)"
    fi
    i=$((i + 1))
  done
  sleep "$INTERVAL"
done

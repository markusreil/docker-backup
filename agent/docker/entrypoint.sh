#!/bin/sh
# Merged backup agent: connect to the central kopia server once, then run
# docker-gen (renders /state/volumes.yaml and /state/crontab from the local
# daemon's container labels) and supercronic (snapshots each listed volume
# from its explicit /mnt/<volume> mount on its cron schedule).
# Scheduling, mounting checks, and snapshot runs live in crontab.tmpl and
# snapshot-volume; this script only starts the two services.
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

echo "[agent] waiting for /state/crontab ..."
while [ ! -f /state/crontab ]; do sleep 5; done

# Fail fast on a bad label or template bug instead of idling with no snaps.
supercronic -test /state/crontab
mkdir -p /tmp/backup-agent
touch /tmp/backup-agent/supercronic-ready
# Become supercronic (PID 1): graceful SIGTERM handling for free, and
# reload-crontab can always find it. A supercronic exit drops the container
# so the restart policy brings both services back together.
exec supercronic /state/crontab

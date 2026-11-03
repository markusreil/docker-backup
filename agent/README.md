# agent

Merged per-cluster backup agent: docker-gen renders the backend-agnostic
volume list from the local daemon, and the snapshot loop backs every listed
volume up to the central kopia server. One container per cluster.

## Build

`FROM kopia/kopia:${KOPIA_VERSION}` plus the `docker-gen`, `yq`, and
`supercronic` binaries (pinned via `DOCKER_GEN_VERSION` / `YQ_VERSION` /
`SUPERCRONIC_VERSION` build args, amd64; the supercronic sha1 is pinned
via `SUPERCRONIC_SHA1SUM`). `BASE_IMAGE` records the upstream image;
`BUILD_DATE` is stamped at build time. No docker-cli: nothing is
restarted, files are re-read.

## Behaviour

The entrypoint connects to the server once (guarded by the config file, so
recreates reconnect), starts docker-gen in the background, then `exec`s
supercronic as PID 1. docker-gen renders two files from container labels:
`/state/volumes.yaml` (the backend-agnostic list, kept for visibility)
and `/state/crontab` — one `<schedule> snapshot-volume --volume <name>`
line per volume — which supercronic serves. Each volume must be mounted
explicitly read-only at `/mnt/<volume>` by the consuming compose file —
the agent never touches the host volume root.

`snapshot-volume` (in `PATH`, also handy for manual runs) takes
`--volume` plus `--keep-<unit>=<N|inherit>` flags: it applies the kopia
retention policy for the path first — absent knobs arrive as `inherit`,
so removing a label resets it instead of leaving a stale value — then
runs `kopia snapshot create /mnt/<volume>`, skipping cleanly when the
mount is missing. Supercronic logs every start, finish, and failure to
the container log, and never overlaps a still-running job. Timing is
strictly schedule-driven: no immediate first snapshot, and minutes
missed while down are skipped, not caught up.

Schedule changes (new labels, added containers) re-render the crontab
and `reload-crontab` (docker-gen `notifycmd`) sends `SIGUSR2` so
supercronic picks them up without a restart. A bad label fails the
`supercronic -test` gate at boot (fail fast); a bad schedule arriving
later is logged and that line never fires.

`kopia-auth` exec wrapper re-exports the persisted user password (root-only
file written by the entrypoint) so `docker compose exec` sessions can run
kopia commands; the entrypoint's own environment is not inherited by exec.

## Identity

kopia 0.22 has no username override flags, so identity is
`root@<container-hostname>`. The consuming compose file sets `hostname:` to
the cluster name; provision the matching `root@<cluster>` user server-side.

## Security

Holds the cluster's docker socket (local only, like the rsync generator)
and the kopia user password (root-only file). No storage credentials — those
live only on the server.

## Env vars (all required unless noted)

- `KOPIA_SERVER_URL` — e.g. `https://server:51515` on the backup network.
- `KOPIA_SERVER_FINGERPRINT` — from the server's `/repo/certs/fingerprint`.
- `KOPIA_CLIENT_PASSWORD` — this cluster's conduit user password.
- `AGENT_SCHEDULE` (optional, default `@daily`) — default cron expression
  for volumes with no `backup.<id>.schedule` label, read from the
  environment by the crontab template. 5-field cron plus `@hourly`,
  `@daily`, `@weekly`, `@monthly`, `@yearly` — supercronic has no
  `@minutely`/`@midnight` (use `* * * * *` / `@daily`).
- `DOCKER_HOST` — the local socket path (default baked into the image).

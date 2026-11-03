# docker-backup

Automatic volume backups for Docker containers, with a central kopia server
(web UI, one-click restore). Containers opt in with `backup.<volume>.*`
labels; a per-cluster agent collects its volumes into a backend-agnostic
file and snapshots them to the server on a schedule.

## How it works

1. **server** (`server/`, own compose project): central kopia repository
   server. Owns the shared `kopia-backup` docker network; holds the only
   copy of the storage credentials and serves the kopia API on `:51515`
   inside the backup network. The web UI is routed through the
   nginx-proxy cluster (`VIRTUAL_HOST`, `VIRTUAL_PROTO: https`).
2. **agent** (`agent/`, one container per cluster): merged docker-gen +
   kopia. Watches the local daemon's container start/stop events, renders
   `/state/volumes.yaml` — the backend-agnostic list of volumes to back
   up — and snapshots each listed volume from its explicit read-only
   `/mnt/<volume>` mount every `AGENT_INTERVAL` seconds. Only containers
   with `backup.<id>.enabled=true` labels appear.

The agnostic list format is deliberately backend-neutral (a `version` plus
a `volumes` list of container/volume/destination/schedule entries), so a
different backend can be added later without touching label collection.

## Label contract

Per container, per volume:

| Label | Meaning |
| --- | --- |
| `backup.<id>.enabled=true` | Back up this volume (only value that opts in) |
| `backup.<id>.schedule=<expr>` | Passthrough to the agnostic file (default `@daily`); informational in v1 |

`<id>` matches a mount by full volume name, by full destination path
(`/<id>` — so id `root/sub/dir` matches a mount at `/root/sub/dir`), or
by the basename of the destination — e.g. id `data` matches a mount at
`/data`. The agent emits the real runtime volume name
(`Mount.Name`), so compose project prefixes (`myproject_data`) resolve
automatically. Labels-only in v1, no env support. Bind mounts (no volume
name) are skipped. A volume claimed by more than one container (or label)
is listed once — first match wins.

Example:

```yaml
labels:
  backup.data.enabled: "true"
  backup.data.schedule: "@daily"
```

## Quickstart

Start the server first (it owns the backup network; it needs the nginx-proxy
cluster's `web-proxy` network to already exist):

```sh
cd server
cp env.example .env   # fill in passwords
docker compose config # fails fast on missing vars
docker compose build
docker compose up -d
docker compose exec server cat /repo/certs/fingerprint
```

Then a client cluster (see `test/cluster/` as the reference blueprint):
pin the fingerprint in its `.env` (`KOPIA_SERVER_FINGERPRINT`), mount each
backed-up volume explicitly at `/mnt/<volume-name>:ro`, join the
`kopia-backup` network as external, and `up -d`. The agent connects,
renders its list, and starts snapshotting.

## Tests

`test/kopia.robot` proves the full path against `test/cluster/`
(demo + agent): snapshot visibility on the server plus a byte-identical
restore. Run with `robot -d test/out-kopia test/kopia.robot` (artifacts go
to gitignored `test/out-kopia/`). The suite spins up the server from the
tracked `server/env.test` fixture (local volume, isolated
`kopia-server-test` project) — your `server/.env` (e.g. NFS) is never
touched. It generates the cluster `.env` itself (fingerprint injection)
— never hand-edit it.

## Operational notes

- `restart: unless-stopped` everywhere, so every service survives daemon restarts.
- Mid-snapshot restarts are safe: kopia snapshots are idempotent and the
  next pass picks up where the last left off.
- Explicit per-volume mounts only — the agent never sees volumes it does
  not back up, and there is no host volume-root coupling.
- The server UI goes through the nginx-proxy cluster (variant-agnostic
  `VIRTUAL_HOST`/`ACME_HOST` contract, `KOPIA_GEN_SELF_SIGNED_CERT`
  opt-in for LAN/self-signed setups). Kopia clients bypass the proxy
  and connect directly over the `kopia-backup` network, since the proxy
  forwards only the UI's HTTPS, not the clients' gRPC stream.
- See `server/README.md` and `agent/README.md` for service details.

## Layout

- `server/` — central kopia server (own compose project + `.env`).
- `agent/` — merged per-cluster backup agent image.
- `test/cluster/` — reference client cluster (demo + agent, fixture `.env`).
- `test/kopia.robot` — snapshot + restore end-to-end proof.

# kopia server cluster

Central backup server for all clusters. Owns the shared `kopia-backup`
docker network (under that exact name) which every client cluster joins as
`external: true`. Start this cluster first.

## Layout

Second compose project in this repo (`server/docker-compose.yml` + its own
`.env`); deliberately separate from the per-cluster stack because it has a
different lifecycle — one server, many client clusters. Split into its own
repo if a second consumer outside this tree ever needs it.

- `kopia/` — extended `kopia/kopia` image: entrypoint only (repo init,
  conduit user provisioning, self-signed cert, server start). No seeding
  beyond first boot; everything persists in the `kopia-repo` volume.
- No published ports: the UI/API serve on `:51515` inside the backup
  network only. The web UI is routed through the nginx-proxy cluster
  (`VIRTUAL_HOST` + `VIRTUAL_PROTO: https`, variant-agnostic with
  `ACME_HOST` and the `KOPIA_GEN_SELF_SIGNED_CERT` opt-in); kopia clients
  keep connecting directly over the backup network, since the proxy only
  forwards the UI's HTTPS, not the clients' gRPC stream.

## First boot vs restarts

The entrypoint creates the filesystem repository, the TLS cert, and the
client conduit user (`root@<host>` from `.env`) only if missing; restarts
reuse all three. The cert fingerprint is printed to the log and persisted at
`/repo/certs/fingerprint` — pin it in each client cluster's
`KOPIA_SERVER_FINGERPRINT`. Rotating a client password: change `.env` and
recreate the user server-side (the entrypoint never overwrites).

## NFS-backed repository

Load `docker-compose.nfs.yml` on top of the base file to keep the
repository on an NFS share instead of a local docker volume. Steering is
via `COMPOSE_FILE` in `.env` (one-variable switch, no `-f` flags):

```sh
COMPOSE_FILE=docker-compose.yml:docker-compose.nfs.yml
```

plus `NFS_ADDR` (NFS server), `NFS_PATH` (export path), and optional
`NFS_OPTS` (default `rw,nfsvers=4`); all documented in `env.example`.
Missing NFS vars fail `docker compose config` fast, and the base file
still validates without them.

NFS notes: export NFSv4 (kopia relies on file locking), and give the
backup host write access as root — the server runs as root, so a
root-squashing export maps its files to `nobody` (`no_root_squash` for
this host, or matching `anonuid`/`anongid`, is cleaner). Removing the
volume (`down -v`) only detaches the mount; the files persist on the
NFS export.

## Env vars

- `KOPIA_VERSION` (required) — upstream kopia release.
- `KOPIA_REPOSITORY_PASSWORD` (required) — encrypts the repository.
- `KOPIA_SERVER_USER` / `KOPIA_SERVER_PASSWORD` (required) — UI/API and
  control credentials.
- `KOPIA_CLIENT_USER` / `KOPIA_CLIENT_HOST` / `KOPIA_CLIENT_PASSWORD`
  (required) — the provisioned conduit identity, kopia `user@host` form.

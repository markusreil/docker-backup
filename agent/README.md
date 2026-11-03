# agent

Merged per-cluster backup agent: docker-gen renders the backend-agnostic
volume list from the local daemon, and the snapshot loop backs every listed
volume up to the central kopia server. One container per cluster.

## Build

`FROM kopia/kopia:${KOPIA_VERSION}` plus the `docker-gen` and `yq` binaries
(pinned via `DOCKER_GEN_VERSION` / `YQ_VERSION` build args, amd64).
`BASE_IMAGE` records the upstream image; `BUILD_DATE` is stamped at build
time. No docker-cli: nothing is restarted, the loop re-reads the file.

## Behaviour

The entrypoint connects to the server once (guarded by the config file, so
recreates reconnect), starts docker-gen in the background rendering
`/state/volumes.yaml`, then loops: for each listed volume, `kopia snapshot
create /mnt/<volume>` every `AGENT_INTERVAL` seconds. Each volume must be
mounted explicitly read-only at `/mnt/<volume>` by the consuming compose
file — the agent never touches the host volume root.

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
- `AGENT_INTERVAL` (optional, default `3600`) — seconds between passes.
- `DOCKER_HOST` — the local socket path (default baked into the image).

# AGENTS.md

Working rules for this repo (compose-spec project: kopia server only).

- `.env` is hidden and never tracked; `env.example` is the tracked source of
  shape. Every required var uses `${VAR:?...}` so
  `docker compose config` fails fast.
- No `container_name:`; `restart: unless-stopped`.
- Named volumes for all state; no bind mounts.
- No `ports:`; the server UI is a variant-agnostic downstream service
  (`VIRTUAL_HOST`, `VIRTUAL_PROTO: https`, `ACME_HOST` plus
  `KOPIA_GEN_SELF_SIGNED_CERT` defaulting to `false`) on the proxy's
  external network, with Homepage labels. Clients bypass the proxy and
  use the backup network directly.
- Server image is built and published from
  https://github.com/markusreil/kopia-backup; this repo only runs it.
- This repo is the central compose project (own file, own `.env`). It owns
  the `kopia-backup` network by exact name; client clusters join it
  `external: true` after the server is up. Client images and agent code live
  at https://github.com/markusreil/kopia-backup.
- Verify with `docker compose config` (include the NFS overlay with NFS vars set when it changes).
- Details live in `README.md` and the service README — keep them in sync.

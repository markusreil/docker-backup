# kopia

## Build

`FROM kopia/kopia:${KOPIA_VERSION}` plus `openssl` for the first-boot
self-signed cert. `BASE_IMAGE` records the upstream image; `BUILD_DATE` is
stamped at build time. Upstream entrypoint is overridden with our own.

## Contents (`docker/`)

- `entrypoint.sh` — creates the repo, connects locally, provisions the
  conduit user (add-or-keep), generates/persists the TLS cert, writes the
  fingerprint file, then `exec`s `kopia server start`.

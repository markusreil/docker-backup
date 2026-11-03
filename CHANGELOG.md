# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0/).

## [Unreleased]

### Added

- Generator service: extended `nginxproxy/docker-gen` image rendering the
  backend-agnostic `/state/volumes.yaml` from `backup.<id>.enabled` labels.
- Runner service (`rsync` profile): rsyncs listed volumes from the host
  volume root to the `backup-data` volume on a `RUNNER_INTERVAL` schedule.
- Restart-on-change: generator `notifycmd` restarts the runner (by
  `backup.runner=true` label) only when the rendered list actually changes.
- Demo fixture service with backup labels for manual and e2e verification.
- Robot Framework end-to-end tests in `test/`.
- Kopia server cluster (`server/`, own compose project, owns `kopia-backup`).
- Merged per-cluster agent (`agent/`, docker-gen + kopia in one image).
- Kopia test cluster (`test/cluster/`) with robot snapshot/restore proof.
- Server UI routed through nginx-proxy (variant-agnostic contract +
  Homepage card); clients still connect directly over `kopia-backup`.
- NFS overlay for the server (`server/docker-compose.nfs.yml`, steered via
  `COMPOSE_FILE`): keeps the kopia repository on an NFS share
  (`NFS_ADDR`/`NFS_PATH`, optional `NFS_OPTS`).
- Tracked `server/env.test` fixture: the robot suite spins up the server
  cluster from it (local volume, isolated `kopia-server-test` project),
  so a deployment `server/.env` (e.g. NFS) never affects tests.

### Fixed

- Server container gets a stable `hostname:` (`kopia.<domain>`) so the Kopia UI shows `root@kopia` instead of the container ID.
- Root `README.md` no longer claims there is no reverse-proxy integration;
  it now documents the nginx-proxy routing and the `web-proxy` prerequisite.

### Removed

- Standalone docker-gen generator service and rsync runner service, with
  their root compose file, root `.env`/`env.example`, and rsync robot
  suite: kopia is the only backend. The backend-agnostic `volumes.yaml`
  format lives on in the agent template, so a runner-style backend can be
  re-added without touching label collection.
- Moved the demo fixture out of the compose file; tests spin up their own
  labeled fixture container in the suite setup and tear it down afterwards.

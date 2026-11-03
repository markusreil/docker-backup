# TODO

- [ ] Machine-generated agent mounts (option C): let docker-gen render a
      `docker-compose.volumes.yml` override with the `/mnt/<volume>` entries
      so consumers only add labels and never hand-write mounts.
      - Constraint: mounts can't be hot-added to a running container, so a
        watcher must `docker compose up -d` the agent when the rendered
        override changes. Missed ticks during recreation are skipped, same
        as today.
      - Keep the static agent as is (supercronic serving, keep-* policies,
        per-minute stamps); this only adds a rendered file plus a
        recreate trigger.
      - The generator resolves runtime (project-prefixed) volume names, so
        consumers stop predicting `/mnt/<project>_<vol>` destinations.
      - Make label-without-mount loud: today's silent `skip` becomes the
        failure mode this removes; keep a visible warning until the
        recreate converges.
      - Prove with robot: add a label to the fixture without a compose
        mount and assert the snapshot still happens after regeneration.

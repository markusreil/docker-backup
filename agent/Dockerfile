ARG KOPIA_VERSION=unknown
FROM kopia/kopia:${KOPIA_VERSION}

ARG DOCKER_GEN_VERSION=unknown \
    YQ_VERSION=unknown \
    SUPERCRONIC_VERSION=unknown \
    SUPERCRONIC_SHA1SUM=unknown \
    BUILD_DATE=unknown
ENV BASE_IMAGE=kopia/kopia \
    BUILD_DATE=${BUILD_DATE}

# docker-gen renders the backend-agnostic volume list and the supercronic
# crontab from container labels. yq stays for ad-hoc inspection via exec
# sessions. No docker-cli: nothing is restarted, files are re-read.
ADD https://github.com/nginx-proxy/docker-gen/releases/download/${DOCKER_GEN_VERSION}/docker-gen-linux-amd64-${DOCKER_GEN_VERSION}.tar.gz /tmp/docker-gen.tar.gz
ADD https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64 /usr/local/bin/yq
ADD https://github.com/aptible/supercronic/releases/download/${SUPERCRONIC_VERSION}/supercronic-linux-amd64 /usr/local/bin/supercronic
RUN tar -xzf /tmp/docker-gen.tar.gz -C /usr/local/bin docker-gen \
    && rm /tmp/docker-gen.tar.gz \
    && echo "${SUPERCRONIC_SHA1SUM}  /usr/local/bin/supercronic" | sha1sum -c - \
    && chmod +x /usr/local/bin/yq /usr/local/bin/docker-gen /usr/local/bin/supercronic

COPY docker/ /etc/backup-agent/
RUN chmod +x /etc/backup-agent/entrypoint.sh /etc/backup-agent/kopia-auth /etc/backup-agent/snapshot-volume /etc/backup-agent/reload-crontab
ENV PATH="/etc/backup-agent:${PATH}"
ENTRYPOINT ["/etc/backup-agent/entrypoint.sh"]

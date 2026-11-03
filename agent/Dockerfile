ARG KOPIA_VERSION=unknown
FROM kopia/kopia:${KOPIA_VERSION}

ARG DOCKER_GEN_VERSION=unknown \
    YQ_VERSION=unknown \
    BUILD_DATE=unknown
ENV BASE_IMAGE=kopia/kopia \
    BUILD_DATE=${BUILD_DATE}

# docker-gen renders the backend-agnostic volume list from container labels;
# yq lets the snapshot loop read it. No docker-cli: nothing is restarted,
# the loop re-reads the file.
ADD https://github.com/nginx-proxy/docker-gen/releases/download/${DOCKER_GEN_VERSION}/docker-gen-linux-amd64-${DOCKER_GEN_VERSION}.tar.gz /tmp/docker-gen.tar.gz
ADD https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64 /usr/local/bin/yq
RUN tar -xzf /tmp/docker-gen.tar.gz -C /usr/local/bin docker-gen \
    && rm /tmp/docker-gen.tar.gz \
    && chmod +x /usr/local/bin/yq /usr/local/bin/docker-gen

COPY docker/ /etc/backup-agent/
RUN chmod +x /etc/backup-agent/entrypoint.sh /etc/backup-agent/kopia-auth
ENV PATH="/etc/backup-agent:${PATH}"
ENTRYPOINT ["/etc/backup-agent/entrypoint.sh"]

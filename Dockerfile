FROM registry.access.redhat.com/ubi8/ubi-minimal:8.10-1179.1741795396

LABEL org.opencontainers.image.authors="Adfinis AG <https://adfinis.com>"
LABEL org.opencontainers.image.vendor="Adfinis"

COPY backup.sh /usr/local/bin/backup.sh

RUN microdnf update -y && rm -rf /var/cache/yum

# hadolint ignore=DL3041
RUN microdnf install -y curl findutils gzip tar \
    && microdnf clean all

RUN curl -O https://dl.min.io/client/mc/release/linux-amd64/mc.rpm \
    && rpm -ih mc.rpm \
    && rm mc.rpm
    
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN /bin/bash -o pipefail -c "\
    curl -L https://github.com/etcd-io/etcd/releases/download/v3.5.15/etcd-v3.5.15-linux-amd64.tar.gz \
    | tar xfz - -C /tmp --strip-components=1 --no-same-owner -- etcd-v3.5.15-linux-amd64/ \
    && mv /tmp/etcdctl /usr/local/bin/ \
    && mv /tmp/etcdutl /usr/local/bin/ \
    && mv /tmp/etcd /usr/local/bin/ \
    "

ENV MC_CONFIG_DIR=/opt/mc/config
RUN mkdir -p $MC_CONFIG_DIR && \
    chown 1000:1000 $MC_CONFIG_DIR

CMD ["/usr/local/bin/backup.sh"]

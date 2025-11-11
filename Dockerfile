FROM registry.access.redhat.com/ubi9-minimal:9.7

LABEL org.opencontainers.image.authors="Adfinis AG <https://adfinis.com>"
LABEL org.opencontainers.image.vendor="Adfinis"

ENV MC_CONFIG_DIR=/opt/mc/config

# hadolint ignore=DL3041
RUN microdnf update -y \
    && microdnf install -y findutils gzip tar \
    && microdnf clean all \
    && curl -O https://dl.min.io/client/mc/release/linux-amd64/mc.rpm \
    && rpm -ih mc.rpm \
    && rm mc.rpm \
    && curl -o /tmp/etcd.tgz -L https://github.com/etcd-io/etcd/releases/download/v3.5.21/etcd-v3.5.21-linux-amd64.tar.gz \
    && mkdir /tmp/etcd \
    && tar xfz /tmp/etcd.tgz -C /tmp/etcd --strip-components=1 --no-same-owner \
    && mv /tmp/etcd/etcdctl /usr/local/bin/ \
    && mv /tmp/etcd/etcdutl /usr/local/bin/ \
    && mv /tmp/etcd/etcd /usr/local/bin/ \
    && rm -rf /tmp/etcd/ /tmp/etcd.tgz \
    && mkdir -p $MC_CONFIG_DIR \
    && chown 1000:1000 $MC_CONFIG_DIR

COPY backup.sh /usr/local/bin/backup.sh

CMD ["/usr/local/bin/backup.sh"]

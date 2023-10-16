FROM registry.access.redhat.com/ubi8-minimal:8.8-1072.1696517598

LABEL org.opencontainers.image.authors="Adfinis AG <https://adfinis.com>"
LABEL org.opencontainers.image.vendor="Adfinis"

COPY backup.sh /usr/local/bin/backup.sh

RUN microdnf update -y && rm -rf /var/cache/yum
RUN microdnf install findutils wget tar gzip -y && microdnf clean all
RUN wget https://github.com/etcd-io/etcd/releases/download/v3.4.27/etcd-v3.4.27-linux-amd64.tar.gz -O /tmp/etcd-v3.4.27-linux-amd64.tar.gz
RUN tar -xvf /tmp/etcd-v3.4.27-linux-amd64.tar.gz -C /tmp/ && mv /tmp/etcd-v3.4.27-linux-amd64/etcdctl /usr/local/bin/etcdctl && rm -rf /tmp/etcd-v3.4.27-linux-amd64*


CMD ["/usr/local/bin/backup.sh"]

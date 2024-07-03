FROM registry.access.redhat.com/ubi8/ubi-minimal:8.10-896.1717584414

LABEL org.opencontainers.image.authors="Adfinis AG <https://adfinis.com>"
LABEL org.opencontainers.image.vendor="Adfinis"

COPY backup.sh /usr/local/bin/backup.sh

RUN microdnf update -y && rm -rf /var/cache/yum
RUN microdnf install findutils curl tar gzip -y && microdnf clean all
RUN curl -L https://github.com/etcd-io/etcd/releases/download/v3.5.11/etcd-v3.5.11-linux-amd64.tar.gz \
	| tar xfz - -C /tmp --strip-components=1 --no-same-owner -- etcd-v3.5.11-linux-amd64/etcdctl \
	&& mv /tmp/etcdctl /usr/local/bin/

CMD ["/usr/local/bin/backup.sh"]

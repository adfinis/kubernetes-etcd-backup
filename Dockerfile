FROM registry.access.redhat.com/ubi8/ubi-minimal:8.9-1029

LABEL org.opencontainers.image.authors="Adfinis AG <https://adfinis.com>"
LABEL org.opencontainers.image.vendor="Adfinis"

COPY backup.sh /usr/local/bin/backup.sh

RUN microdnf update -y && rm -rf /var/cache/yum
RUN microdnf install -y \
	curl-7.61.1-34.el8 \
	findutils-1:4.6.0-22.el8 \
	gzip-1.9-13.el8_5 \
	tar-2:1.30-9.el8 \
	&& microdnf clean all
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN /bin/bash -o pipefail -c "\
	curl -L https://github.com/etcd-io/etcd/releases/download/v3.5.11/etcd-v3.5.11-linux-amd64.tar.gz \
	| tar xfz - -C /tmp --strip-components=1 --no-same-owner -- etcd-v3.5.11-linux-amd64/etcdctl \
	&& mv /tmp/etcdctl /usr/local/bin/ \
	"

CMD ["/usr/local/bin/backup.sh"]

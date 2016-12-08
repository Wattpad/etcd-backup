FROM alpine:3.4

ARG ETCD_VERSION
ENV ETCD_BUILD="etcd-v${ETCD_VERSION}-linux-amd64"

RUN apk --no-cache --virtual build-deps add openssl && \
    wget "https://github.com/coreos/etcd/releases/download/v${ETCD_VERSION}/${ETCD_BUILD}.tar.gz" -O - | \
    tar xzvf - -C /tmp ${ETCD_BUILD}/etcdctl && \
    mv /tmp/${ETCD_BUILD}/* /usr/local/bin && \
    rmdir /tmp/${ETCD_BUILD} && \
    apk del build-deps

RUN apk --no-cache add py-pip

ENV ETCD_DATA_DIR=/var/lib/etcd

# Copy requirements.txt separately so pip install step can be cached
COPY /requirements.txt /opt/etcd-backup/requirements.txt
RUN pip install -r /opt/etcd-backup/requirements.txt

COPY / /opt/etcd-backup
RUN ln -s /opt/etcd-backup/etcd-backup.py /usr/local/bin/etcd-backup

CMD ["etcd-backup"]

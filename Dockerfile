FROM alpine:3.4

ARG ETCD_VERSION
ENV ETCD_BUILD="etcd-v${ETCD_VERSION}-linux-amd64"

RUN apk --no-cache --virtual build-deps add openssl && \
    wget "https://github.com/coreos/etcd/releases/download/v2.3.7/${ETCD_BUILD}.tar.gz" -O - | \
    tar xzvf - -C /tmp ${ETCD_BUILD}/etcdctl ${ETCD_BUILD}/etcd && \
    mv /tmp/${ETCD_BUILD}/* /usr/local/bin && \
    rmdir /tmp/${ETCD_BUILD} && \
    apk del build-deps

RUN apk --no-cache add py-pip

COPY /etcd-backup/requirements.txt /opt/etcd-backup/requirements.txt
RUN pip install -r /opt/etcd-backup/requirements.txt

COPY /etcd-backup /opt/etcd-backup
RUN ln -s /opt/etcd-backup/etcd-backup.py /usr/local/bin/etcd-backup

CMD ["etcd"]

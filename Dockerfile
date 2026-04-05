FROM ubuntu:latest

RUN apt-get update && apt-get install -y --no-install-recommends \
    zutils \
    bash \
    lbzip2 \
    gzip \
    pigz \
    pixz \
    lz4 \
    xz-utils \
    zstd \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /nqpatch /data

COPY zutils.conf /etc/zutils.conf

COPY nqpatch-*.sh /nqpatch/
COPY nqpatch /nqpatch/

RUN chmod +x /nqpatch/*.sh && chmod +x /nqpatch/nqpatch

WORKDIR /data
VOLUME /data

ENTRYPOINT ["/nqpatch/nqpatch"]


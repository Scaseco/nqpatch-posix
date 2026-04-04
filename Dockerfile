FROM alpine:latest

RUN apk add --no-cache zutils bash \
  && mkdir -p /nqpatch /data

COPY nqpatch-*.sh /nqpatch/
COPY nqpatch /nqpatch/

RUN chmod +x /nqpatch/*.sh && chmod +x /nqpatch/nqpatch

WORKDIR /data
VOLUME /data

ENTRYPOINT ["/nqpatch/nqpatch"]

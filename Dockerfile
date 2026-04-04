FROM alpine:latest

RUN apk add --no-cache zutils bash \
  && mkdir -p /rdfpatch /data

COPY rdfpatch-nq-*.sh /rdfpatch/
COPY entrypoint.sh /rdfpatch/

RUN chmod +x /rdfpatch/*.sh

WORKDIR /data
VOLUME /data

ENTRYPOINT ["/rdfpatch/entrypoint.sh"]

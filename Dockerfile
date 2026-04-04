FROM alpine:3.20

ENV APP_UID=0 APP_GID=0

RUN apk add --no-cache zutils bash \
  && mkdir -p /rdfpatch /data

COPY rdfpatch-nq-*.sh /rdfpatch/
COPY entrypoint.sh /rdfpatch/

RUN chmod +x /rdfpatch/*.sh

WORKDIR /data
VOLUME /data

ENTRYPOINT ["/rdfpatch/entrypoint.sh"]

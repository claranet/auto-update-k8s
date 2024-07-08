FROM alpine:latest
RUN apk add --no-cache jq yq curl git glab

COPY auto-update /auto-update

CMD ["/bin/sh"]
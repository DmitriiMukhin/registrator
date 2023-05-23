ARG BASE_IMAGE
FROM ${BASE_IMAGE} AS init

ARG BASE_IMAGE
ARG BUILD_DATE
ARG VERSION

LABEL version="v1.0.0"
LABEL description="Fork of Docker registrator with networks priority."
LABEL org.label-schema.build-date=${BUILD_DATE} \
    org.label-schema.version=${VERSION} \
    org.label-schema.vcs-url="https://gitlab.com/dkr-registrator/registrator" \
    org.opencontainers.image.licenses="MIT" \
    org.opencontainers.image.title="registrator" \
    org.opencontainers.image.vendor="hypolas" \
    license="MIT"
LABEL maintainer="nicolas.hypolite@gmail.com"

RUN find / -name proxy
RUN --mount=type=secret,id=proxy HTTP_PROXY=$(cat /run/secrets/proxy) HTTPS_PROXY=$(cat /run/secrets/proxy) apk add --no-cache ca-certificates
COPY build/registrator /bin/registrator

ENTRYPOINT ["/bin/registrator"]
ARG ARCH
ARG BASE_IMAGE
FROM --platform=${ARCH} ${BASE_IMAGE}

ARG BARCH
ARG BOS
ARG BUILD_DATE
ARG VERSION

LABEL version="${VERSION}"
LABEL description="Fork of Docker registrator with networks priority."
LABEL org.label-schema.build-date=${BUILD_DATE} \
    org.label-schema.version=${VERSION} \
    org.label-schema.vcs-url="https://gitlab.com/dkr-registrator/registrator" \
    org.opencontainers.image.licenses="MIT" \
    org.opencontainers.image.title="registrator" \
    org.opencontainers.image.vendor="hypolas" \
    license="MIT"
LABEL maintainer="nicolas.hypolite@gmail.com"

# RUN find / -name proxy
RUN --mount=type=secret,id=proxy HTTP_PROXY= HTTPS_PROXY= apk add --no-cache ca-certificates
# RUN --mount=type=secret,id=proxy HTTP_PROXY=$(cat /run/secrets/proxy) HTTPS_PROXY=$(cat /run/secrets/proxy) apk add --no-cache ca-certificates
COPY bin/registrator-${BOS}-${BARCH} /bin/registrator

ENTRYPOINT ["/bin/registrator"]
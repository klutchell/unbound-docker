ARG BR_VERSION=2020.11

# hadolint ignore=DL3029
FROM --platform=$BUILDPLATFORM klutchell/buildroot-rootfs-amd64:$BR_VERSION as rootfs-amd64

# hadolint ignore=DL3029
FROM --platform=$BUILDPLATFORM klutchell/buildroot-rootfs-arm64:$BR_VERSION as rootfs-arm64

# hadolint ignore=DL3029
FROM --platform=$BUILDPLATFORM klutchell/buildroot-rootfs-arm32v7:$BR_VERSION as rootfs-armv7

# hadolint ignore=DL3029
FROM --platform=$BUILDPLATFORM klutchell/buildroot-rootfs-arm32v6:$BR_VERSION as rootfs-armv6

# hadolint ignore=DL3006
FROM rootfs-$TARGETARCH$TARGETVARIANT as build

COPY package ./package

COPY rootfs_overlay ./rootfs_overlay

COPY config.pkg ./config.pkg

RUN support/kconfig/merge_config.sh -m .config config.pkg

RUN make olddefconfig && make source

RUN make

# hadolint ignore=DL3002
USER root

WORKDIR /rootfs

RUN tar xpf /home/br-user/output/images/rootfs.tar -C /rootfs

FROM scratch

COPY --from=build rootfs/ /

ENTRYPOINT [ "unbound" ]

HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 \
	CMD [ "dig", "sigok.verteiltesysteme.net", "@127.0.0.1" ]

LABEL org.opencontainers.image.authors "Kyle Harding <https://klutchell.dev>"
LABEL org.opencontainers.image.url "https://github.com/klutchell/unbound-dnscrypt"
LABEL org.opencontainers.image.documentation "https://github.com/klutchell/unbound-dnscrypt"
LABEL org.opencontainers.image.source "https://github.com/klutchell/unbound-dnscrypt"
LABEL org.opencontainers.image.title "klutchell/unbound-dnscrypt"
LABEL org.opencontainers.image.description "Unbound is a validating, recursive, caching DNS resolver"

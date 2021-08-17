#syntax=docker/dockerfile:1.2

# hadolint ignore=DL3029
FROM --platform=$BUILDPLATFORM debian:bullseye-20210816 AS buildroot-base

# hadolint ignore=DL3008
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        bc \
        build-essential \
        ca-certificates \
        cmake \
        cpio \
        file \
        locales \
        python3 \
        rsync \
        unzip \
        wget && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# hadolint ignore=DL3059
RUN sed -i 's/# \(en_US.UTF-8\)/\1/' /etc/locale.gen && \
    /usr/sbin/locale-gen && \
	useradd -ms /bin/bash br-user && \
    chown -R br-user:br-user /home/br-user

USER br-user

WORKDIR /home/br-user

ENV LC_ALL=en_US.UTF-8

ARG BR_VERSION=2021.02.4

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN wget -q -O- https://buildroot.org/downloads/buildroot-$BR_VERSION.tar.gz | tar xz --strip 1

FROM buildroot-base as rootfs

ARG TARGETARCH
ARG TARGETVARIANT
ARG PACKAGE_VERSION=1.13.1
ARG ROOTFS_LIBC=musl

# check the expected unbound version matches the one included with this buildroot version
RUN grep -qw "${PACKAGE_VERSION}" ./package/unbound/unbound.mk

COPY config ./config

COPY rootfs_overlay ./rootfs_overlay

RUN support/kconfig/merge_config.sh -m \
	config/common.cfg \
	config/arch/"${TARGETARCH}${TARGETVARIANT}".cfg \
	config/libc/"${ROOTFS_LIBC}".cfg \
	config/unbound.cfg

RUN --mount=type=cache,target=/cache,uid=1000,gid=1000,sharing=private \
    make olddefconfig && make source && make

# hadolint ignore=DL3002
USER root

WORKDIR /rootfs

RUN tar xpf /home/br-user/output/images/rootfs.tar -C /rootfs

FROM scratch

COPY --from=rootfs rootfs/ /

HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 \
	CMD [ "dig", "sigok.verteiltesysteme.net", "@127.0.0.1" ]

ENTRYPOINT [ "unbound" ]

LABEL org.opencontainers.image.authors "Kyle Harding <https://klutchell.dev>"
LABEL org.opencontainers.image.url "https://github.com/klutchell/unbound-dnscrypt"
LABEL org.opencontainers.image.documentation "https://github.com/klutchell/unbound-dnscrypt"
LABEL org.opencontainers.image.source "https://github.com/klutchell/unbound-dnscrypt"
LABEL org.opencontainers.image.title "klutchell/unbound-dnscrypt"
LABEL org.opencontainers.image.description "Unbound is a validating, recursive, caching DNS resolver"

RUN [ "unbound", "-V" ]

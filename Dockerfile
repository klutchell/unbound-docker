#syntax=docker/dockerfile:1.2

# platform set by buildkit (DOCKER_BUILDKIT=1)
FROM --platform=$BUILDPLATFORM buildroot/base:20211120.1925 AS buildroot-base

ARG BR_VERSION=2022.02.6

RUN git clone --depth 1 --branch ${BR_VERSION} https://git.busybox.net/buildroot

FROM buildroot-base as rootfs

WORKDIR /home/br-user/buildroot

# set by buildkit (DOCKER_BUILDKIT=1)
ARG TARGETARCH
ARG TARGETVARIANT

# musl or glibc (musl is smaller)
ARG ROOTFS_LIBC=musl

COPY *.patch ./

RUN git apply ./*.patch

COPY config ./config

RUN support/kconfig/merge_config.sh -m \
	config/arch/"${TARGETARCH}${TARGETVARIANT}".cfg \
	config/libc/"${ROOTFS_LIBC}".cfg \
	config/*.cfg

RUN --mount=type=cache,target=/cache,uid=1000,gid=1000,sharing=private \
    make olddefconfig && make source && make && \
    rm -rf output/build output/host

# hadolint ignore=DL3002
USER root

WORKDIR /rootfs

RUN tar xpf /home/br-user/buildroot/output/images/rootfs.tar -C /rootfs

FROM scratch

COPY --from=rootfs rootfs/ /

COPY --chown=unbound:unbound rootfs_overlay/ /

ENTRYPOINT [ "unbound" ]

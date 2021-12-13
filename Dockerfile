#syntax=docker/dockerfile:1.2

# hadolint ignore=DL3029
FROM --platform=$BUILDPLATFORM debian:bullseye-20211011 AS buildroot-base

# hadolint ignore=DL3008
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        bc \
        build-essential \
        ca-certificates \
        cmake \
        cpio \
        file \
        git \
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

ENV HOME=/home/br-user

ENV LC_ALL=en_US.UTF-8

ARG BR_VERSION=2021.11

RUN git clone --depth 1 --branch ${BR_VERSION} https://git.busybox.net/buildroot

FROM buildroot-base as rootfs

WORKDIR /home/br-user/buildroot

ARG TARGETARCH
ARG TARGETVARIANT
ARG ROOTFS_LIBC=musl

COPY *.patch ./

RUN git apply ./*.patch

COPY config ./config

RUN support/kconfig/merge_config.sh -m \
	config/common.cfg \
	config/arch/"${TARGETARCH}${TARGETVARIANT}".cfg \
	config/libc/"${ROOTFS_LIBC}".cfg \
	config/unbound.cfg

COPY rootfs_overlay ./rootfs_overlay

RUN --mount=type=cache,target=/cache,uid=1000,gid=1000,sharing=private \
    make olddefconfig && make source && make

# hadolint ignore=DL3002
USER root

WORKDIR /rootfs

RUN tar xpf /home/br-user/buildroot/output/images/rootfs.tar -C /rootfs

FROM scratch

COPY --from=rootfs rootfs/ /

ENTRYPOINT [ "unbound" ]

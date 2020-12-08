ARG ARCH=amd64

FROM buildroot-rootfs-$ARCH:2020.08.2 as buildroot

COPY . .

RUN support/kconfig/merge_config.sh -m .config config.pkg

RUN make olddefconfig && make source

RUN make

# hadolint ignore=DL3002
USER root

WORKDIR /rootfs

RUN tar xpf /home/br-user/output/images/rootfs.tar -C /rootfs

FROM scratch

COPY --from=buildroot rootfs/ /

ENTRYPOINT [ "unbound" ]

HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 \
	CMD [ "dig", "sigok.verteiltesysteme.net", "@127.0.0.1" ]

LABEL org.opencontainers.image.authors "Kyle Harding <https://klutchell.dev>"
LABEL org.opencontainers.image.url "https://github.com/klutchell/unbound-dnscrypt"
LABEL org.opencontainers.image.documentation "https://github.com/klutchell/unbound-dnscrypt"
LABEL org.opencontainers.image.source "https://github.com/klutchell/unbound-dnscrypt"
LABEL org.opencontainers.image.title "klutchell/unbound-dnscrypt"
LABEL org.opencontainers.image.description "Unbound is a validating, recursive, caching DNS resolver"

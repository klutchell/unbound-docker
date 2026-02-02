# syntax=docker/dockerfile:1.21@sha256:27f9262d43452075f3c410287a2c43f5ef1bf7ec2bb06e8c9eeb1b8d453087bc

FROM alpine:3.23.3@sha256:25109184c71bdad752c8312a8623239686a9a2071e8825f20acb8f2198c3f659 AS build-base

ARG TARGETARCH

# hadolint ignore=DL3018
RUN --mount=type=cache,id=apk-cache-${TARGETARCH},target=/var/cache/apk \
	apk add --update --cache-dir=/var/cache/apk \
	binutils \
	bind-tools \
	build-base \
	ca-certificates-bundle \
	libevent-dev \
	libsodium-dev \
	nghttp2-dev \
	openssl-dev \
	hiredis-dev \
	expat-dev

RUN find / -name "libcrypto.so*" -exec ls -al {} \;

ARG UNBOUND_UID=101
ARG UNBOUND_GID=102

RUN addgroup -S -g ${UNBOUND_GID} unbound \
	&& adduser -S -g unbound -h /var/unbound -u ${UNBOUND_UID} -D -H -G unbound unbound

####################################################################################################

FROM build-base AS ldns

WORKDIR /src

ARG LDNS_VERSION=1.8.4
# https://nlnetlabs.nl/downloads/ldns/ldns-1.8.4.tar.gz.sha256
ARG LDNS_SHA256="838b907594baaff1cd767e95466a7745998ae64bc74be038dccc62e2de2e4247"

ADD https://nlnetlabs.nl/downloads/ldns/ldns-${LDNS_VERSION}.tar.gz ldns.tar.gz

SHELL ["/bin/ash", "-eo", "pipefail", "-c"]

RUN echo "${LDNS_SHA256}  ldns.tar.gz" | sha256sum -c - \
	&& tar -xzf ldns.tar.gz --strip-components=1

RUN ./configure \
	--prefix=/opt/usr \
	--with-drill \
	--localstatedir=/var \
	--with-ssl \
	--disable-rpath \
	--disable-shared \
	--disable-static \
	--disable-ldns-config

RUN make -j"$(nproc)" && \
	make install && \
	strip /opt/usr/bin/drill && \
	ln -s drill /opt/usr/bin/dig

####################################################################################################

FROM build-base AS unbound

WORKDIR /src

ARG UNBOUND_VERSION=1.24.2
# https://nlnetlabs.nl/downloads/unbound/unbound-1.24.2.tar.gz.sha256
ARG UNBOUND_SHA256="44e7b53e008a6dcaec03032769a212b46ab5c23c105284aa05a4f3af78e59cdb"

ADD https://nlnetlabs.nl/downloads/unbound/unbound-${UNBOUND_VERSION}.tar.gz unbound.tar.gz

SHELL ["/bin/ash", "-eo", "pipefail", "-c"]

RUN echo "${UNBOUND_SHA256}  unbound.tar.gz" | sha256sum -c - \
	&& tar -xzf unbound.tar.gz --strip-components=1

# https://unbound.docs.nlnetlabs.nl/en/latest/getting-started/installation.html#building-from-source-compiling
RUN ./configure \
	--prefix=/opt/usr \
	--with-conf-file=/etc/unbound/unbound.conf \
	--with-run-dir=/var/unbound \
	--with-chroot-dir=/var/unbound \
	--with-pidfile=/var/unbound/unbound.pid \
	--with-rootkey-file=/var/unbound/root.key \
	--disable-static \
	--disable-shared \
	--disable-rpath \
	--enable-dnscrypt \
	--enable-subnet \
	--enable-cachedb \
	--enable-tfo-server \
	--enable-tfo-client \
	--with-pthreads \
	--with-libevent \
	--with-libhiredis \
	--with-libnghttp2 \
	--with-ssl \
	--with-username=unbound

RUN make -j"$(nproc)" && \
	make install && \
	strip /opt/usr/sbin/unbound \
	/opt/usr/sbin/unbound-anchor \
	/opt/usr/sbin/unbound-checkconf \
	/opt/usr/sbin/unbound-control \
	/opt/usr/sbin/unbound-host

WORKDIR /var/unbound

####################################################################################################

FROM scratch AS conf-example

# docker build . --target conf-example --output rootfs_overlay/etc/unbound/
COPY --from=unbound /etc/unbound/unbound.conf /unbound.conf.example

####################################################################################################

FROM build-base AS root-hints

# https://unbound.docs.nlnetlabs.nl/en/latest/manpages/unbound-anchor.html
RUN wget -q https://www.internic.net/domain/named.root -O /root.hints

####################################################################################################

FROM unbound AS root-key

WORKDIR /var/unbound

SHELL ["/bin/ash", "-eo", "pipefail", "-c"]

COPY --from=root-hints /root.hints .

# Generate initial root key with the provided root hints.
# https://unbound.docs.nlnetlabs.nl/en/latest/manpages/unbound-anchor.html
# This tool exits with value 1 if the root anchor was updated using the certificate or
# if the builtin root-anchor was used. It exits with code 0 if no update was necessary,
# if the update was possible with RFC 5011 tracking, or if an error occurred.
RUN { /opt/usr/sbin/unbound-anchor -v -r root.hints -a root.key || true ; } | tee -a /dev/stderr | grep -q "success: the anchor is ok"

####################################################################################################

# This is a minimal C wrapper for drill to avoid the need for a shell
# and reduce the exit code to 0 or 1.
# Dockerfile reference says that health checks should always return 0 or 1.
# Any other status code is reserved.
# See https://docs.docker.com/reference/dockerfile/#healthcheck
FROM build-base AS drill-hc

# Set the working directory
WORKDIR /src

# Copy the source file
COPY drill-hc/main.c .

# Compile the program statically
RUN gcc -Wall -Wextra -pedantic -std=c2x -static -O3 -o drill-hc main.c

####################################################################################################

FROM scratch AS final

COPY --from=build-base /lib/ld-musl*.so.1 /lib/
COPY --from=build-base /usr/lib/libgcc_s.so.1 /usr/lib/
COPY --from=build-base /usr/lib/libcrypto.so.3 /usr/lib/libssl.so.3 /usr/lib/
COPY --from=build-base /usr/lib/libsodium.so.* /usr/lib/libevent-2.1.so.* /usr/lib/libexpat.so.* /usr/lib/libhiredis.so.* /usr/lib/libnghttp2.so.* /usr/lib/
COPY --from=build-base /etc/ssl/ /etc/ssl/
COPY --from=build-base /etc/passwd /etc/group /etc/

COPY --from=unbound /opt/usr/sbin/ /usr/sbin/

COPY --from=ldns /opt/usr/bin/ /usr/bin/

COPY --from=drill-hc /src/drill-hc /usr/bin/drill-hc

COPY --chown=unbound:unbound rootfs_overlay/etc/unbound/ /etc/unbound/

COPY --from=root-key --chown=unbound:unbound /var/unbound/root.hints /var/unbound/root.hints
COPY --from=root-key --chown=unbound:unbound /var/unbound/root.key /var/unbound/root.key

RUN [ "unbound", "-V" ]
# hadolint ignore=DL3059
RUN [ "unbound-checkconf" ]
# hadolint ignore=DL3059
RUN [ "drill", "-v" ]
# hadolint ignore=DL3059
RUN [ "dig", "-v" ]

ENTRYPOINT [ "unbound" ]

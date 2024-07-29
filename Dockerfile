# syntax=docker/dockerfile:1.9@sha256:fe40cf4e92cd0c467be2cfc30657a680ae2398318afd50b0c80585784c604f28

FROM alpine:3.20.2@sha256:0a4eaa0eecf5f8c050e5bba433f58c052be7587ee8af3e8b3910ef9ab5fbe9f5 AS build-base

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
	openssl-dev \
	hiredis-dev \
	expat-dev

ARG UNBOUND_UID=101
ARG UNBOUND_GID=102

RUN addgroup -S -g ${UNBOUND_GID} unbound \
	&& adduser -S -g unbound -h /var/unbound -u ${UNBOUND_UID} -D -H -G unbound unbound

####################################################################################################

FROM build-base AS ldns

WORKDIR /src

ARG LDNS_VERSION=1.8.3
# https://nlnetlabs.nl/downloads/ldns/ldns-1.8.3.tar.gz.sha256
ARG LDNS_SHA256="c3f72dd1036b2907e3a56e6acf9dfb2e551256b3c1bbd9787942deeeb70e7860"

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

ARG UNBOUND_VERSION=1.20.0
# https://nlnetlabs.nl/downloads/unbound/unbound-1.20.0.tar.gz.sha256
ARG UNBOUND_SHA256="56b4ceed33639522000fd96775576ddf8782bb3617610715d7f1e777c5ec1dbf"

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
	--with-pthreads \
	--with-libevent \
	--with-libhiredis \
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

FROM scratch AS final

COPY --from=build-base /lib/ld-musl*.so.1 /lib/
COPY --from=build-base /usr/lib/libgcc_s.so.1 /usr/lib/
COPY --from=build-base /lib/libcrypto.so.3 /lib/libssl.so.3 /lib/
COPY --from=build-base /usr/lib/libsodium.so.* /usr/lib/libevent-2.1.so.* /usr/lib/libexpat.so.* /usr/lib/libhiredis.so.* /usr/lib/
COPY --from=build-base /etc/ssl/ /etc/ssl/
COPY --from=build-base /etc/passwd /etc/group /etc/

COPY --from=unbound /opt/usr/sbin/ /usr/sbin/

COPY --from=ldns /opt/usr/bin/ /usr/bin/

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

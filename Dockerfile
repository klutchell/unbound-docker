# syntax=docker/dockerfile:1.7@sha256:dbbd5e059e8a07ff7ea6233b213b36aa516b4c53c645f1817a4dd18b83cbea56

FROM alpine:3.19.1@sha256:c5b1261d6d3e43071626931fc004f70149baeba2c8ec672bd4f27761f8e1ad6b AS build-base

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
	expat-dev

ARG UNBOUND_UID=101
ARG UNBOUND_GID=102

RUN addgroup -S -g ${UNBOUND_GID} unbound \
	&& adduser -S -g unbound -h /var/unbound -u ${UNBOUND_UID} -D -H -G unbound unbound

# hadolint ignore=DL3007
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

# hadolint ignore=DL3007
FROM build-base AS unbound

WORKDIR /src

ARG UNBOUND_VERSION=1.19.3
# https://nlnetlabs.nl/downloads/unbound/unbound-1.19.3.tar.gz.sha256
ARG UNBOUND_SHA256="3ae322be7dc2f831603e4b0391435533ad5861c2322e34a76006a9fb65eb56b9"

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
	--with-pthreads \
	--with-libevent \
	--with-ssl \
	--with-username=unbound

RUN make -j"$(nproc)" && \
	make install && \
	strip /opt/usr/sbin/unbound \
	/opt/usr/sbin/unbound-anchor \
	/opt/usr/sbin/unbound-checkconf \
	/opt/usr/sbin/unbound-control \
	/opt/usr/sbin/unbound-host

WORKDIR /var/unbound/

# download root hints and generate initial root key
# https://unbound.docs.nlnetlabs.nl/en/latest/manpages/unbound-anchor.html
RUN wget -q https://www.internic.net/domain/named.root -O root.hints \
	&& { /opt/usr/sbin/unbound-anchor -v -r root.hints 2>&1 || true ; } | tee -a /dev/stderr | grep -q "success: the anchor is ok"

FROM scratch AS conf-example

# docker build . --target conf-example --output rootfs_overlay/etc/unbound/
COPY --from=unbound /etc/unbound/unbound.conf /unbound.conf.example

FROM scratch as root-hints

# docker build . --target root-hints --output rootfs_overlay/var/unbound/
COPY --from=unbound /var/unbound/root.key /root.key
COPY --from=unbound /var/unbound/root.hints /root.hints

FROM scratch AS final

COPY --from=build-base /lib/ld-musl*.so.1 /lib/
COPY --from=build-base /usr/lib/libgcc_s.so.1 /usr/lib/
COPY --from=build-base /lib/libcrypto.so.3 /lib/libssl.so.3 /lib/
COPY --from=build-base /usr/lib/libsodium.so.* /usr/lib/libevent-2.1.so.* /usr/lib/libexpat.so.* /usr/lib/
COPY --from=build-base /etc/ssl/ /etc/ssl/
COPY --from=build-base /etc/passwd /etc/group /etc/

COPY --from=unbound /opt/usr/sbin/ /usr/sbin/

COPY --from=ldns /opt/usr/bin/ /usr/bin/

COPY --chown=unbound:unbound rootfs_overlay/etc/unbound/ /etc/unbound/
COPY --chown=unbound:unbound rootfs_overlay/var/unbound/ /var/unbound/

RUN [ "unbound", "-V" ]
# hadolint ignore=DL3059
RUN [ "unbound-checkconf" ]	
# hadolint ignore=DL3059
RUN [ "drill", "-v" ]
# hadolint ignore=DL3059
RUN [ "dig", "-v" ]

ENTRYPOINT [ "unbound" ]

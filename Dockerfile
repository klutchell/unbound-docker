# syntax=docker/dockerfile:1.4

FROM alpine:3.17.3 AS build-base

# hadolint ignore=DL3018
RUN --mount=type=cache,target=/var/cache/apk \
	apk add --update-cache --cache-dir=/var/cache/apk \
	binutils \
	bind-tools \
	build-base \
	ca-certificates-bundle \
	libevent-dev \
	libevent-static \
	libsodium-dev \
	libsodium-static \
	openssl-dev \
	openssl-libs-static \
	expat-dev \
	expat-static

ARG UNBOUND_UID=101
ARG UNBOUND_GID=102

RUN addgroup -g ${UNBOUND_GID} unbound \
	&& adduser -u ${UNBOUND_UID} -D -H -G unbound unbound

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
	--disable-shared

RUN make -j"$(nproc)" LDFLAGS=-all-static && \
	make install && \
	strip /opt/usr/bin/drill && \
	ln -s drill /opt/usr/bin/dig

# hadolint ignore=DL3007
FROM build-base AS unbound

WORKDIR /src

ARG UNBOUND_VERSION=1.17.1
# https://nlnetlabs.nl/downloads/unbound/unbound-1.17.1.tar.gz.sha256
ARG UNBOUND_SHA256="ee4085cecce12584e600f3d814a28fa822dfaacec1f94c84bfd67f8a5571a5f4"

ADD https://nlnetlabs.nl/downloads/unbound/unbound-${UNBOUND_VERSION}.tar.gz unbound.tar.gz

SHELL ["/bin/ash", "-eo", "pipefail", "-c"]

RUN echo "${UNBOUND_SHA256}  unbound.tar.gz" | sha256sum -c - \
	&& tar -xzf unbound.tar.gz --strip-components=1

# https://unbound.docs.nlnetlabs.nl/en/latest/getting-started/installation.html#building-from-source-compiling
RUN ./configure \
	--prefix=/opt/usr \
	--sysconfdir=/etc \
	--localstatedir=/var \
	--enable-fully-static \
	--disable-shared \
	--disable-rpath \
	--enable-dnscrypt \
	--with-pthreads \
	--with-libevent \
	--with-ssl \
	--with-username=unbound

RUN make -j"$(nproc)" && \
	make install && \
	strip /opt/usr/sbin/unbound

FROM scratch

COPY --from=build-base /etc/ssl/ /etc/ssl/
COPY --from=build-base /etc/passwd /etc/group /etc/

COPY --from=unbound /opt/usr/sbin/ /usr/sbin/
COPY --from=unbound /etc/unbound/unbound.conf /etc/unbound/unbound.conf.example

COPY --from=ldns /opt/usr/bin/ /usr/bin/

COPY --chown=unbound:unbound rootfs_overlay/ /

# TODO: run as non-root on port 5053
# USER unbound

RUN [ "unbound", "-V" ]
# hadolint ignore=DL3059
RUN [ "unbound-checkconf" ]
# hadolint ignore=DL3059
RUN [ "unbound-anchor", "-v" ]	
# hadolint ignore=DL3059
RUN [ "drill", "-v" ]
# hadolint ignore=DL3059
RUN [ "dig", "-v" ]

ENTRYPOINT [ "unbound" ]

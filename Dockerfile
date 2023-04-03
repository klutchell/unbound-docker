# syntax=docker/dockerfile:1.4

# hadolint ignore=DL3007
FROM cgr.dev/chainguard/wolfi-base:latest AS ldns

# hadolint ignore=DL3018
RUN apk add --no-cache --update-cache \
	busybox \
	ca-certificates-bundle \
	build-base \
	openssl-dev \
	posix-libc-utils

WORKDIR /src

ARG LDNS_VERSION=1.8.3
# https://nlnetlabs.nl/downloads/ldns/ldns-1.8.3.tar.gz.sha256
ARG LDNS_SHA256="c3f72dd1036b2907e3a56e6acf9dfb2e551256b3c1bbd9787942deeeb70e7860"

ADD https://nlnetlabs.nl/downloads/ldns/ldns-${LDNS_VERSION}.tar.gz ldns.tar.gz

SHELL ["/bin/ash", "-eo", "pipefail", "-c"]

RUN echo "${LDNS_SHA256}  ldns.tar.gz" | sha256sum -c - \
	&& tar -xzf ldns.tar.gz --strip-components=1

RUN ./configure \
	--prefix=/opt \
	--with-drill \
	--localstatedir=/var \
	--with-ssl --

RUN make -j"$(nproc)" && make install

RUN find /opt

# hadolint ignore=DL3007
FROM cgr.dev/chainguard/wolfi-base:latest AS unbound

# hadolint ignore=DL3018
RUN apk add --no-cache --update-cache \
	busybox \
	ca-certificates-bundle \
	build-base \
	openssl-dev \
	expat-dev \
	libevent-dev \
	libsodium-dev \
	posix-libc-utils

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
	--prefix=/opt \
	--sysconfdir=/etc \
	--localstatedir=/var \
	--enable-dnscrypt \
	--with-pthreads \
	--with-libevent \
	--with-ssl --

RUN make -j"$(nproc)" && make install

RUN ldd /opt/lib/*.so  | awk '{print $3}' | xargs -I{} sh -c "mkdir -vp \$(dirname /opt{}) && cp -v {} /opt{}" \
	&& adduser -D unbound

# hadolint ignore=DL3007
FROM cgr.dev/chainguard/glibc-dynamic:latest

COPY --from=unbound /opt/sbin/ /sbin/
COPY --from=unbound /opt/usr/lib/*.so* /usr/lib/
COPY --from=unbound /opt/lib/*.so* /lib/

COPY --from=unbound /etc/passwd /etc/group /etc/

COPY --from=ldns /opt/bin/drill /bin/drill
COPY --from=ldns /opt/lib/libldns.so* /lib/

COPY --chown=unbound:unbound rootfs_overlay/ /

USER unbound

RUN [ "unbound", "-V" ]

RUN [ "drill", "-v" ]

ENTRYPOINT [ "unbound" ]

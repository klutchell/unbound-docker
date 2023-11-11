# syntax=docker/dockerfile:1.6@sha256:ac85f380a63b13dfcefa89046420e1781752bab202122f8f50032edf31be0021

FROM alpine:3.18.4@sha256:eece025e432126ce23f223450a0326fbebde39cdf496a85d8c016293fc851978 AS build-base

ARG TARGETARCH

# hadolint ignore=DL3018
RUN --mount=type=cache,id=apk-cache-${TARGETARCH},target=/var/cache/apk \
	apk add --update --cache-dir=/var/cache/apk \
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

RUN sed -e 's/@LDFLAGS@/@LDFLAGS@ -all-static/' -i Makefile.in && \
	LIBS="-lpthread -lm" LDFLAGS="-Wl,-static -static -static-libgcc -no-pie" ./configure \
	--prefix=/opt/usr \
	--with-drill \
	--localstatedir=/var \
	--with-ssl \
	--disable-rpath \
	--disable-shared \
	--enable-fully-static \
	--disable-ldns-config

RUN make -j"$(nproc)" && \
	make install && \
	strip /opt/usr/bin/drill && \
	ln -s drill /opt/usr/bin/dig

# hadolint ignore=DL3007
FROM build-base AS unbound

WORKDIR /src

ARG UNBOUND_VERSION=1.19.0
# https://nlnetlabs.nl/downloads/unbound/unbound-1.19.0.tar.gz.sha256
ARG UNBOUND_SHA256="a97532468854c61c2de48ca4170de854fd3bc95c8043bb0cfb0fe26605966624"

ADD https://nlnetlabs.nl/downloads/unbound/unbound-${UNBOUND_VERSION}.tar.gz unbound.tar.gz

SHELL ["/bin/ash", "-eo", "pipefail", "-c"]

RUN echo "${UNBOUND_SHA256}  unbound.tar.gz" | sha256sum -c - \
	&& tar -xzf unbound.tar.gz --strip-components=1

# https://unbound.docs.nlnetlabs.nl/en/latest/getting-started/installation.html#building-from-source-compiling
RUN sed -e 's/@LDFLAGS@/@LDFLAGS@ -all-static/' -i Makefile.in && \
	LIBS="-lpthread -lm" LDFLAGS="-Wl,-static -static -static-libgcc -no-pie" ./configure \
	--prefix=/opt/usr \
	--sysconfdir=/etc \
	--localstatedir=/var \
	# --with-run-dir=/var/run/unbound \
	# --with-chroot-dir= \
	# --with-pidfile=/var/run/unbound/unbound.pid \
	--enable-fully-static \
	--disable-shared \
	--disable-rpath \
	--enable-dnscrypt \
	--enable-subnet \
	--with-pthreads \
	--with-libevent \
	--with-ssl \
	--with-username=unbound
	# --disable-flto \
	# --enable-event-api \
	# --enable-tfo-client \
	# --enable-tfo-server \
	# --enable-ipset \

RUN make -j"$(nproc)" && \
	make install && \
	strip /opt/usr/sbin/unbound \
	/opt/usr/sbin/unbound-anchor \
	/opt/usr/sbin/unbound-checkconf \
	/opt/usr/sbin/unbound-control \
	/opt/usr/sbin/unbound-host

FROM scratch AS conf-example

# docker build . --target conf-example --output rootfs_overlay/etc/unbound/
COPY --from=unbound /etc/unbound/unbound.conf /unbound.conf.example

FROM scratch AS final

COPY --from=build-base /etc/ssl/ /etc/ssl/
COPY --from=build-base /etc/passwd /etc/group /etc/

COPY --from=unbound /opt/usr/sbin/ /usr/sbin/

COPY --from=ldns /opt/usr/bin/ /usr/bin/

COPY --chown=unbound:unbound rootfs_overlay/ /

# TODO: run as non-root on port 5053
# USER unbound

RUN [ "unbound", "-V" ]
# hadolint ignore=DL3059
RUN [ "unbound-checkconf" ]	
# hadolint ignore=DL3059
RUN [ "drill", "-v" ]
# hadolint ignore=DL3059
RUN [ "dig", "-v" ]

ENTRYPOINT [ "unbound" ]

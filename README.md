# unofficial unbound multiarch docker image

[![Docker Pulls](https://img.shields.io/docker/pulls/klutchell/unbound.svg?style=flat-square)](https://hub.docker.com/r/klutchell/unbound)
[![Docker Stars](https://img.shields.io/docker/stars/klutchell/unbound.svg?style=flat-square)](https://hub.docker.com/r/klutchell/unbound)

[Unbound](https://unbound.net/) is a validating, recursive, and caching DNS resolver.

## Usage

NLnet Labs documentation: <https://unbound.docs.nlnetlabs.nl/en/latest/>

```bash
# print general usage
docker run --rm klutchell/unbound:1.14.0 -h
```

```bash
# run a recursive dns server on host port 53
docker run --name unbound \
  -p 53:53/tcp \
  -p 53:53/udp \
  klutchell/unbound:1.14.0
```

```bash
# mount existing configuration from a host directory
docker run --name unbound \
  -p 53:53/tcp \
  -p 53:53/udp \
  -v unbound:/etc/unbound \
  klutchell/unbound:1.14.0
```

```bash
# add a regular healthcheck to test dns resolution
docker run --name unbound \
  -p 53:5053/tcp \
  -p 53:5053/udp \
  -v /path/to/config:/etc/unbound \
  --health-cmd "dig sigok.verteiltesysteme.net @127.0.0.1" \
  klutchell/unbound:1.14.0
```

The provided `unbound.conf` will provide recursive DNS with DNSSEC validation.
However Unbound has many features available so I recommend getting familiar with the
documentation and mounting your own config directory.

<https://unbound.docs.nlnetlabs.nl/en/latest/manpages/unbound.conf.html>

### Examples

Use unbound as upstream DNS for [Pi-Hole](https://pi-hole.net/).

```yaml
version: "2"

volumes:
  pihole:
  dnsmasq:

services:
  pihole:
    image: pihole/pihole
    cap_add:
      - NET_ADMIN
    volumes:
      - "pihole:/etc/pihole"
      - "dnsmasq:/etc/dnsmasq.d"
    dns:
      - "127.0.0.1"
      - "1.1.1.1"
    network_mode: host
    environment:
      - "DNS1=127.0.0.1#5053"
      - "DNS2=127.0.0.1#5053"
  unbound:
    image: klutchell/unbound:1.14.0
    ports:
      - "5053:53/tcp"
      - "5053:53/udp"
```

## Build

```bash
# optionally update root hints before building
rm rootfs_overlay/etc/unbound/root.hints
wget https://www.internic.net/domain/named.root -O rootfs_overlay/etc/unbound/root.hints
```

```bash
# enable docker buildkit and experimental mode
export DOCKER_BUILDKIT=1
export DOCKER_CLI_EXPERIMENTAL=enabled

# build local image for native platform
docker build . --pull --tag klutchell/unbound --load

# cross-build for another platform
docker build . --pull --tag klutchell/unbound --load --platform linux/arm/v6
```

## Test

```bash
# enable QEMU for arm emulation
docker run --rm --privileged multiarch/qemu-user-static:5.2.0-2 --reset -p yes

# run a detached unbound container
docker run --rm -d --name unbound klutchell/unbound:1.14.0

# run dig with dnssec to test an example NOERROR endpoint
docker exec unbound dig sigok.verteiltesysteme.net @127.0.0.1 +dnssec

# run dig with dnssec to test an example SERVFAIL endpoint
docker exec unbound dig sigfail.verteiltesysteme.net @127.0.0.1 +dnssec

# stop and remove the container
docker stop unbound
```

## Contributing

Please open an issue or submit a pull request with any features, fixes, or changes.

<https://github.com/klutchell/unbound-docker/issues>

## Acknowledgments

Original software is by NLnet Labs: <https://unbound.net>

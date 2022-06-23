# unofficial unbound multiarch docker image

[![Docker Pulls](https://img.shields.io/docker/pulls/klutchell/unbound.svg?style=flat-square)](https://hub.docker.com/r/klutchell/unbound)
[![Docker Stars](https://img.shields.io/docker/stars/klutchell/unbound.svg?style=flat-square)](https://hub.docker.com/r/klutchell/unbound)

[Unbound](https://unbound.net/) is a validating, recursive, and caching DNS resolver.

## Usage

NLnet Labs documentation: <https://unbound.docs.nlnetlabs.nl/en/latest/>

```bash
# print version information
docker run --rm klutchell/unbound -V
```

```bash
# print general usage
docker run --rm klutchell/unbound -h
```

```bash
# run a recursive dns server on host port 53
docker run --name unbound \
  -p 53:53/tcp \
  -p 53:53/udp \
  klutchell/unbound
```

```bash
# mount existing configuration from a host directory
# examples can be downloaded from root_overlay/etc/unbound
docker run --name unbound \
  -p 53:53/tcp \
  -p 53:53/udp \
  -v /path/to/config:/etc/unbound \
  klutchell/unbound
```

```bash
# add a regular healthcheck to test dns resolution
docker run --name unbound \
  -p 53:53/tcp \
  -p 53:53/udp \
  -v /path/to/config:/etc/unbound \
  --health-cmd "dig sigok.verteiltesysteme.net @127.0.0.1" \
  klutchell/unbound
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
    container_name: pihole
    image: pihole/pihole:latest
    ports:
      - "53:53/tcp"
      - "53:53/udp"
      - "67:67/udp"
      - "80:80/tcp"
    networks:
      default:
        ipv4_address: 172.28.0.3
    environment:
      TZ: "America/Chicago"
      PIHOLE_DNS_: "172.28.0.2;172.28.0.2"
    volumes:
      - "pihole:/etc/pihole"
      - "dnsmasq:/etc/dnsmasq.d"
    cap_add:
      - NET_ADMIN
    restart: unless-stopped

  unbound:
    image: klutchell/unbound
    networks:
      default:
        ipv4_address: 172.28.0.2

networks:
  default:
    driver: bridge
    ipam:
      config:
      - subnet: 172.28.0.0/24
        gateway: 172.28.0.1
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
docker build . --tag klutchell/unbound

# cross-build for another platform
docker build . --tag klutchell/unbound --platform linux/arm/v6
```

## Test

```bash
# enable QEMU for arm emulation
docker run --rm --privileged multiarch/qemu-user-static:5.2.0-2 --reset -p yes

# run a detached unbound container
docker run --rm -d --name unbound klutchell/unbound

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

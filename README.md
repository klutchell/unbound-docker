# unofficial unbound multiarch docker image

[![Docker Pulls](https://img.shields.io/docker/pulls/klutchell/unbound.svg?style=flat-square)](https://hub.docker.com/r/klutchell/unbound)
[![Docker Stars](https://img.shields.io/docker/stars/klutchell/unbound.svg?style=flat-square)](https://hub.docker.com/r/klutchell/unbound)

[Unbound](https://unbound.net/) is a validating, recursive, and caching DNS resolver.

## Usage

NLnet Labs documentation: <https://unbound.docs.nlnetlabs.nl/en/latest/>

Print version information:

```bash
docker run --rm klutchell/unbound -V
```

Print general usage:

```bash
docker run --rm klutchell/unbound -h
```

Run a recursive dns server on host port 53

```bash
docker run --name unbound \
  -p 53:53/tcp -p 53:53/udp \
  klutchell/unbound
```

Add a regular healthcheck to test DNS resolution.
Read more about Docker healthchecks here: <https://docs.docker.com/engine/reference/builder/#healthcheck>

```bash
docker run --name unbound \
  -p 53:53/tcp -p 53:53/udp \
  --health-cmd "dig sigok.verteiltesysteme.net @127.0.0.1" \
  klutchell/unbound
```

Mount custom configuration from a host directory. Files must be readable by user/group `101:102` or world.
Examples can be downloaded from [custom.conf.d](./root_overlay/etc/unbound/custom.conf.d) in this project.

```bash
docker run --name unbound \
  -p 53:53/tcp -p 53:53/udp \
  -v /path/to/config:/etc/unbound/custom.conf.d \
  klutchell/unbound
```

See all available config options here: <https://unbound.docs.nlnetlabs.nl/en/latest/manpages/unbound.conf.html>

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

# unofficial unbound-dnscrypt multiarch docker image

[![Docker Pulls](https://img.shields.io/docker/pulls/klutchell/unbound-dnscrypt.svg?style=flat-square)](https://hub.docker.com/r/klutchell/unbound-dnscrypt/)
[![Docker Stars](https://img.shields.io/docker/stars/klutchell/unbound-dnscrypt.svg?style=flat-square)](https://hub.docker.com/r/klutchell/unbound-dnscrypt/)

[Unbound](https://unbound.net/) is a validating, recursive, and caching DNS resolver.

## Architectures

The architectures supported by this image are:

- `linux/amd64`
- `linux/arm64`
- `linux/arm/v7`
- `linux/arm/v6`

Simply pulling `klutchell/unbound-dnscrypt` should retrieve the correct image for your arch.

## Build

```bash
# build for amd64
docker build . --build-arg ARCH=amd64 -t klutchell/unbound-dnscrypt

# build for arm64
docker build . --build-arg ARCH=arm64 -t klutchell/unbound-dnscrypt

# build for arm32v7
docker build . --build-arg ARCH=arm32v7 -t klutchell/unbound-dnscrypt

# build for arm32v6
docker build . --build-arg ARCH=arm32v6 -t klutchell/unbound-dnscrypt
```

## Test

```bash
# run a detached unbound-dnscrypt container instance
docker run --rm -d --name unbound-dnscrypt klutchell/unbound-dnscrypt

# run dig with dnssec to test an NOERROR endpoint
docker exec unbound-dnscrypt dig sigok.verteiltesysteme.net @127.0.0.1 +dnssec

# run dig with dnssec to test an SERVFAIL endpoint
docker exec unbound-dnscrypt dig sigfail.verteiltesysteme.net @127.0.0.1 +dnssec

# stop and remove the detached container instance
docker stop unbound-dnscrypt
```

## Usage

NLnet Labs documentation: <https://nlnetlabs.nl/documentation/unbound/>

```bash
# print general usage
docker run --rm klutchell/unbound-dnscrypt -h

# run a recursive dns server on host port 53
docker run --name unbound-dnscrypt \
  -p 53:53/tcp -p 53:53/udp \
  klutchell/unbound-dnscrypt

# run a recursive dns server on host port 53 with a persistent config volume
docker run --name unbound-dnscrypt \
  -p 53:53/tcp -p 53:53/udp \
  -v unbound:/etc/unbound \
  klutchell/unbound-dnscrypt

# run a recursive dns server on host port 53 with an existing host volume
# note that in this case /path/to/config must already contain unbound.conf and
# any other custom files (use ./rootfs_overlay/etc/unbound/ as a reference)
# /path/to/config must also be writable by user 1001
docker run --name unbound-dnscrypt \
  -p 53:53/tcp -p 53:53/udp \
  -v /path/to/config:/etc/unbound \
  klutchell/unbound-dnscrypt
```

The provided `unbound.conf` will provide recursive DNS with DNSSEC validation.
However Unbound has many features available so I recommend getting familiar with the
documentation and mounting your own config directory.

- <https://nlnetlabs.nl/documentation/unbound/unbound.conf/>
- <https://nlnetlabs.nl/documentation/unbound/howto-optimise/>

### Examples

Use unbound-dnscrypt as upstream DNS for [Pi-Hole](https://pi-hole.net/).

```bash
# run unbound-dnscrypt and bind to port 5053 to avoid conflicts with pihole on port 53
docker run -d --name unbound-dnscrypt \
  --restart=unless-stopped \
  -p 5053:53/tcp -p 5053:53/udp \
  klutchell/unbound-dnscrypt

# run pihole and bind to host network with 127.0.0.1:5053 as DNS1/DNS2
docker run -d --name pihole \
    -e ServerIP=your_IP_here \
    -e TZ=time_zone_here \
    -e WEBPASSWORD=Password \
    -e DNS1=127.0.0.1#5053 \
    -e DNS2=127.0.0.1#5053 \
    -v ~/pihole/:/etc/pihole/ \
    --dns=127.0.0.1 \
    --dns=1.1.1.1 \
    --cap-add=NET_ADMIN \
    --network=host \
    --restart=unless-stopped \
    pihole/pihole
```

If using docker-compose something like the following may suffice.

```yaml
version: '2.1'

volumes:
  pihole:
  dnsmasq:

services:
  pihole:
    image: pihole/pihole
    privileged: true
    volumes:
      - 'pihole:/etc/pihole'
      - 'dnsmasq:/etc/dnsmasq.d'
    dns:
      - '127.0.0.1'
      - '1.1.1.1'
    network_mode: host
    environment:
      - 'ServerIP=192.168.8.8'
      - 'TZ=America/Toronto'
      - 'WEBPASSWORD=secretpassword'
      - 'DNS1=127.0.0.1#5053'
      - 'DNS2=127.0.0.1#5053'
      - 'INTERFACE=eth0'
      - 'DNSMASQ_LISTENING=eth0'
  unbound-dnscrypt:
    image: klutchell/unbound-dnscrypt
    ports:
      - '5053:53/tcp'
      - '5053:53/udp'
```

## Contributing

Please open an issue or submit a pull request with any features, fixes, or changes.

<https://github.com/klutchell/unbound-dnscrypt/issues>

## Acknowledgments

Original software is by NLnet Labs: <https://github.com/NLnetLabs/unbound>

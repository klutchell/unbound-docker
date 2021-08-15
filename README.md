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
# enable docker buildkit and experimental mode
export DOCKER_BUILDKIT=1
export DOCKER_CLI_EXPERIMENTAL=enabled

# enable QEMU for arm emulation
docker run --rm --privileged multiarch/qemu-user-static:5.2.0-2 --reset -p yes

# use buildx to build and load an amd64 image
docker buildx build . --pull --platform linux/amd64 \
  --tag klutchell/unbound-dnscrypt:latest --load

# use buildx to build and load an arm64 image
docker buildx build . --pull --platform linux/arm64 \
  --tag klutchell/unbound-dnscrypt:latest --load

# use buildx to build and load an arm32v7 image
docker buildx build . --pull --platform linux/arm/v7 \
  --tag klutchell/unbound-dnscrypt:latest --load

# use buildx to build and load an arm32v6 image
docker buildx build . --pull --platform linux/arm/v6 \
  --tag klutchell/unbound-dnscrypt:latest --load
```

## Test

```bash
# enable QEMU for arm emulation
docker run --rm --privileged multiarch/qemu-user-static:5.2.0-2 --reset -p yes

# run a detached unbound-dnscrypt container
docker run --rm -d --name unbound-dnscrypt klutchell/unbound-dnscrypt

# run dig with dnssec to test an example NOERROR endpoint
docker exec unbound-dnscrypt dig sigok.verteiltesysteme.net @127.0.0.1 +dnssec

# run dig with dnssec to test an example SERVFAIL endpoint
docker exec unbound-dnscrypt dig sigfail.verteiltesysteme.net @127.0.0.1 +dnssec

# stop and remove the container
docker stop unbound-dnscrypt
```

## Deploy

Requires `docker login` to authenticate with your provided repo tag.

```bash
# enable docker buildkit and experimental mode
export DOCKER_BUILDKIT=1
export DOCKER_CLI_EXPERIMENTAL=enabled

# enable QEMU for arm emulation
docker run --rm --privileged multiarch/qemu-user-static:5.2.0-2 --reset -p yes

# use buildx to build and push a multiarch manifest
docker buildx build . --pull \
  --platform linux/amd64,linux/arm64,linux/arm/v7,linux/arm/v6 \
  --tag klutchell/unbound-dnscrypt:latest --push
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
  -p 5335:53/tcp -p 5335:53/udp \
  klutchell/unbound-dnscrypt

# run pihole and bind to host network with 127.0.0.1:5053 as DNS1/DNS2
docker run -d --name pihole \
    -e ServerIP=your_IP_here \
    -e TZ=time_zone_here \
    -e WEBPASSWORD=Password \
    -e DNS1=127.0.0.1#5335 \
    -e DNS2=127.0.0.1#5335 \
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
      - 'DNS1=127.0.0.1#5335'
      - 'DNS2=127.0.0.1#5335'
      - 'INTERFACE=eth0'
      - 'DNSMASQ_LISTENING=eth0'
  unbound-dnscrypt:
    image: klutchell/unbound-dnscrypt
    ports:
      - '5335:53/tcp'
      - '5335:53/udp'
```

## Contributing

Please open an issue or submit a pull request with any features, fixes, or changes.

<https://github.com/klutchell/unbound-dnscrypt/issues>

## Acknowledgments

Original software is by NLnet Labs: <https://github.com/NLnetLabs/unbound>

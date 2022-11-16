# unofficial unbound multiarch docker image

[![Docker Pulls](https://img.shields.io/docker/pulls/klutchell/unbound.svg?style=flat-square)](https://hub.docker.com/r/klutchell/unbound)
[![Docker Stars](https://img.shields.io/docker/stars/klutchell/unbound.svg?style=flat-square)](https://hub.docker.com/r/klutchell/unbound)

[Unbound](https://unbound.net/) is a validating, recursive, and caching DNS resolver.

Note that this image is [distroless](https://github.com/GoogleContainerTools/distroless)!

> "Distroless" images contain only your application and its runtime dependencies. They do not contain package managers, shells or any other programs you would expect to find in a standard Linux distribution.

## Usage/Examples

Run a recursive dns server on host port 53 with the default configuration.

```bash
docker run --name unbound \
  -p 53:53/tcp -p 53:53/udp \
  klutchell/unbound
```

Optionally mount [custom configuration](https://unbound.docs.nlnetlabs.nl/en/latest/manpages/unbound.conf.html) from a host directory.
Files must be readable by user/group `101:102` or world.

```bash
docker run --name unbound \
  -p 53:53/tcp -p 53:53/udp \
  -v /path/to/config:/etc/unbound/custom.conf.d \
  klutchell/unbound
```

Examples of docker-compose usage can be found in [examples](./examples)

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

# run dig with dnssec to test NOERROR
docker exec unbound dig @127.0.0.1 dnssec.works +dnssec +multi

# run dig with dnssec to test SERVFAIL
docker exec unbound dig @127.0.0.1 fail01.dnssec.works +dnssec +multi
docker exec unbound dig @127.0.0.1 fail02.dnssec.works +dnssec +multi
docker exec unbound dig @127.0.0.1 fail03.dnssec.works +dnssec +multi
docker exec unbound dig @127.0.0.1 fail04.dnssec.works +dnssec +multi

# stop and remove the container
docker stop unbound
```

## Contributing

Please open an issue or submit a pull request with any features, fixes, or changes.

<https://github.com/klutchell/unbound-docker/issues>

## Legal

Original software is by NLnet Labs: <https://unbound.net>

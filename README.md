# unofficial unbound multiarch docker image

[![Docker Pulls](https://img.shields.io/docker/pulls/klutchell/unbound.svg?style=flat-square)](https://hub.docker.com/r/klutchell/unbound)
[![Docker Stars](https://img.shields.io/docker/stars/klutchell/unbound.svg?style=flat-square)](https://hub.docker.com/r/klutchell/unbound)

[Unbound](https://unbound.net/) is a validating, recursive, and caching DNS
resolver.

Note that this image is
[distroless](https://github.com/GoogleContainerTools/distroless)!

> "Distroless" images contain only your application and its runtime
> dependencies. They do not contain package managers, shells or any other
> programs you would expect to find in a standard Linux distribution.

## Usage/Examples

Run a recursive dns server on host port 53 with the default configuration.

```bash
docker run --name unbound \
  -p 53:53/tcp -p 53:53/udp \
  klutchell/unbound
```

Optionally mount
[custom configuration](https://unbound.docs.nlnetlabs.nl/en/latest/manpages/unbound.conf.html)
from a host directory. Files must be readable by user/group `101:102` or world.

```bash
docker run --name unbound \
  -p 53:53/tcp -p 53:53/udp \
  -v /path/to/config:/etc/unbound/custom.conf.d \
  klutchell/unbound
```

### Optional: Enable CacheDB Module with Redis backend

The cache DB module was compiled into daemon, but is disabled by default. To
enable this module, follow this steps:

- Create a `cachedb.conf` under your custom configuration directory `/path/to/config/custom.conf.d`;
- Add a `server` directive with module configuration to enable `cachedb` module;
- Add a `cachedb` directive with Redis credentials;

```bash
server:
  module-config: "validator cachedb iterator"
cachedb:
  backend: "redis"
  redis-server-host: redis
  redis-server-port: 6379
  redis-expire-records: yes
```

Files must be readable by user/group `101:102` or world.

Examples of docker-compose usage can be found in [examples](examples).

## License

This software is licensed under the [BSD 3-Clause License](LICENSE.md).

Original software is by NLnet Labs: <https://unbound.net>

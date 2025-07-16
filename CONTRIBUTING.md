# Contributing

We love your input! We want to make contributing to this project as easy and
transparent as possible, whether it's:

- Reporting a bug
- Discussing the current state of the code
- Submitting a fix
- Proposing new features
- Becoming a maintainer

## We develop with Github

We use Github to host code, to track issues and feature requests, as well as
accept pull requests.

## We use [Github Flow](https://guides.github.com/introduction/flow/index.html), so all code changes happen through pull requests

Pull requests are the best way to propose changes to the codebase. We actively
welcome your pull requests:

1. Fork the repo and create your branch from `main`.
2. If you've added code that should be tested, add tests.
3. If you've changed APIs, update the documentation.
4. Ensure the test suite passes.
5. Make sure your code lints.
6. Issue that pull request!

## Any contributions you make will be under the [Software License](LICENSE.md)

In short, when you submit code changes, your submissions are understood to be
under the same [Software License](LICENSE.md) that covers the project. Feel free
to contact the maintainers if that's a concern.

## Report bugs using Github's [issues](https://github.com/klutchell/unbound-docker/issues)

We use GitHub issues to track public bugs. Report a bug by
[opening a new issue](https://github.com/klutchell/unbound-docker/issues/new);
it's that easy!

**Great Bug Reports** tend to have:

- A quick summary and/or background
- Steps to reproduce
  - Be specific!
  - Give sample code if you can.
- What you expected would happen
- What actually happens
- Notes (possibly including why you think this might be happening, or stuff you
  tried that didn't work)

People _love_ thorough bug reports. I'm not even kidding.

## Use a consistent coding style

- Use [hadolint](https://github.com/hadolint/hadolint) for linting and
  validating Dockerfile changes
- Use [prettier](https://prettier.io) for linting and validating Markdown
  changes

## Building

1. Enable docker buildkit and experimental mode

   ```bash
   export DOCKER_BUILDKIT=1
   export DOCKER_CLI_EXPERIMENTAL=enabled
   ```

2. Build image for host architecture

   ```bash
   docker build . --tag klutchell/unbound:dev
   ```

3. Optionally cross-build for another architecture

   ```bash
   docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
   docker build . --tag klutchell/unbound:dev --platform linux/arm/v6
   ```

> [!NOTE] Outgoing port 53 must not be blocked on the network where the build is
> running in order to generate initial root keys with unbound-anchor!

## Testing

1. Run a detached unbound container

   ```bash
   docker run --rm -d --name unbound klutchell/unbound:dev
   ```

2. Run drill with DNSSEC to test NOERROR

   ```bash
   docker exec unbound drill @127.0.0.1 dnssec.works
   ```

3. Run drill with dnssec to test SERVFAIL

   ```bash
   docker exec unbound drill @127.0.0.1 fail01.dnssec.works
   docker exec unbound drill @127.0.0.1 fail02.dnssec.works
   docker exec unbound drill @127.0.0.1 fail03.dnssec.works
   docker exec unbound drill @127.0.0.1 fail04.dnssec.works
   ```

4. Stop and remove the test container

   ```bash
   docker stop unbound
   ```

## Packaging new Unbound releases

1. In your working copy, create a new branch if you haven't already, and update
   the following fields in the [Dockerfile](Dockerfile) with the new version and
   hash.

   ```dockerfile
   ARG UNBOUND_VERSION=1.19.1
   # https://nlnetlabs.nl/downloads/unbound/unbound-1.19.1.tar.gz.sha256
   ARG UNBOUND_SHA256="a97532468854c61c2de48ca4170de854fd3bc95c8043bb0cfb0fe26605966624"
   ```

2. Run the following docker build command to copy the example config.

   ```bash
   export DOCKER_BUILDKIT=1
   export DOCKER_CLI_EXPERIMENTAL=enabled
   docker build . --target conf-example --output rootfs_overlay/etc/unbound/
   ```

3. [Build](#building) and [test](#testing) changes locally.

4. Commit and push changes to `Dockerfile` and `unbound.conf.example`.

[Example pull request #235](https://github.com/klutchell/unbound-docker/pull/235) for reference.

## License

By contributing, you agree that your contributions will be licensed under its
[Software License](LICENSE.md).

## References

This document was adapted from the open-source contribution guidelines for
[Facebook's Draft](https://github.com/facebook/draft-js)

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

> [!NOTE] These tests resolve names recursively, so outbound DNS (UDP/TCP port
> 53) must be allowed on the network where they run. On firewalled networks the
> queries will hang or appear to fail for non-Unbound reasons; CI is the
> authoritative source of test results.

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

> **Automated:** The [`Bump Unbound`](.github/workflows/bump-unbound.yml) workflow runs
> weekly (and on demand via **Run workflow**). It detects new upstream releases, updates
> the `ARG` fields below, regenerates the example config, sanity-builds the image, and
> opens a `Bump Unbound to X.Y.Z` PR for review. The manual steps below are the fallback
> for out-of-band bumps or when you want to drive it by hand.

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

For the current pattern, see recent commits touching the Unbound `ARG` lines:

```bash
git log --oneline -- Dockerfile | grep -iE "bump unbound|update unbound" | head -5
```

## Tagging a release (maintainers only)

This section applies to repository maintainers. Contributors do not need to tag
releases — the maintainer will tag once your bump PR is merged.

Every published image comes from a git tag `vX.Y.Z+YYYYMMDD` on a content commit.
The date makes each tag unique, so a git tag never moves.

> **Automated:** The [`Tag Unbound release`](.github/workflows/tag-release.yml)
> workflow creates the tag (an unsigned annotated tag) when one of these happens:
>
> - A PR that changes `UNBOUND_VERSION` merges. The workflow re-verifies the
>   pinned SHA256 against the upstream tarball first.
> - A PR that changes `FROM alpine` merges.
> - A maintainer uses **Run workflow** on `main`, for example for a package fix
>   that ships between Alpine point releases.

Flowzone publishes `vX.Y.Z-YYYYMMDD`, `X.Y.Z`, and `latest` from the tag. Then
[`Retag Unbound release`](.github/workflows/retag-release.yml) points the
`vX.Y.Z` image tag at the same digest. Pin `vX.Y.Z-YYYYMMDD` for an image that
never changes.

To tag by hand, tag the **content commit** (for example the "Bump Unbound to
X.Y.Z" commit), not the merge commit GitHub creates on top.

```bash
git fetch origin
# Find the content commit on origin/main
git log origin/main -3 --format='%H %s'

# Create a signed, annotated tag with the tag name as the message body
git tag -s vX.Y.Z+YYYYMMDD -m "vX.Y.Z+YYYYMMDD" <content-commit-sha>

# Push the tag
git push origin vX.Y.Z+YYYYMMDD
```

Tags created before this scheme are plain `vX.Y.Z`.

## License

By contributing, you agree that your contributions will be licensed under its
[Software License](LICENSE.md).

## References

This document was adapted from the open-source contribution guidelines for
[Facebook's Draft](https://github.com/facebook/draft-js)

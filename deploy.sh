#!/bin/sh

set -e

export DOCKER_REPO="${1:-klutchell}/unbound-dnscrypt"
export BR_VERSION="${2:-2021.02.4}"
export PACKAGE_VERSION="${3:-1.13.1}"

export DOCKER_BUILDKIT=1
export DOCKER_CLI_EXPERIMENTAL=enabled

docker run --rm --privileged multiarch/qemu-user-static:5.2.0-2 --reset -p yes

docker buildx build . \
    --pull \
    --platform linux/amd64,linux/arm64,linux/arm/v7,linux/arm/v6 \
    --build-arg BR_VERSION \
    --build-arg PACKAGE_VERSION \
    --tag "${DOCKER_REPO}:${PACKAGE_VERSION}" \
    --tag "${DOCKER_REPO}:latest" \
    --push

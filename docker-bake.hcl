target "default" {
  context = "./"
  dockerfile = "Dockerfile"
  platforms = [
    "linux/amd64",
    "linux/arm/v7",
    "linux/arm/v6",
    "linux/arm64"
  ]
  cache-from = [
    "ghcr.io/klutchell/unbound:latest",
    "docker.io/klutchell/unbound:latest",
    "ghcr.io/klutchell/unbound:main",
    "docker.io/klutchell/unbound:main",
  ]
}

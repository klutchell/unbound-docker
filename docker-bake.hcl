variable "GITHUB_REF_NAME" {
  default = "dev"
}

variable "GITHUB_REPOSITORY" {
  default = "klutchell/unbound-docker"
}

target "server" {
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
    "ghcr.io/klutchell/unbound:master",
    "docker.io/klutchell/unbound:master",
    "type=registry,ref=ghcr.io/klutchell/unbound:buildkit-cache-${base64encode(GITHUB_REF_NAME)},mode=max"
  ]
  cache-to = [
    "type=registry,ref=ghcr.io/klutchell/unbound:buildkit-cache-${base64encode(GITHUB_REF_NAME)},mode=max"
  ]
}

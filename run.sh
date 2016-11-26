#! /bin/sh
set -e -o pipefail
export QEMU_OPTS="-cpu host -enable-kvm -m 765M"
exec $(nix-build --no-out-link nixos -I nixos-config=./configuration.nix -A vm)/bin/run-nixos-vm "${@}"

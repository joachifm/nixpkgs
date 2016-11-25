#! /bin/sh -e
nix-build nixos -I nixos-config=./configuration.nix -A vm -o vm
export QEMU_OPTS="-cpu host -enable-kvm -m 765M"
exec ./vm/bin/run-nixos-vm "${@}"

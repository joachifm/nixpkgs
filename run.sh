#! /bin/sh -e
export QEMU_OPTS="-m 765M -cpu host -enable-kvm"
exec $(nix-build --no-out-link nixos -I nixos-config=./configuration.nix -A vm)/bin/run-nixos-vm

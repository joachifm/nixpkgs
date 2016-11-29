#! /bin/sh
set -e -o pipefail
export QEMU_OPTS="-cpu host -enable-kvm -m 765M"
exec $(./build-vm.sh)/bin/run-nixos-vm "${@}"

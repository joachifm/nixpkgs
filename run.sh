#! /bin/sh
set -e -o pipefail
export QEMU_OPTS="-cpu host -enable-kvm -m 900M"
exec $(./build.sh -A vm)/bin/run-nixos-vm "${@}"

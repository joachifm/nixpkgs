#! /bin/sh
nix-build --no-out-link nixos -I nixos-config=./configuration.nix -A vm

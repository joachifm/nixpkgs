#! /bin/sh
exec nix-build nixos -I nixos-config=./configuration.nix -A vm

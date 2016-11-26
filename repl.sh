#! /bin/sh
export NIXOS_CONFIG=$PWD/configuration.nix
exec nix-repl ./nixos

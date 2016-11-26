{ config, lib, pkgs }: pkgs.writeText "learn_config" ''

dont-reduce-path /
dont-reduce-path /dev
dont-reduce-path /etc
dont-reduce-path /home
dont-reduce-path /nix
dont-reduce-path /proc
dont-reduce-path /run
dont-reduce-path /sys
dont-reduce-path /var

always-reduce-path /var/cache/fontconfig
always-reduce-path /var/cache/man
always-reduce-path /var/log/journal

always-reduce-path /dev/block
always-reduce-path /dev/bus
always-reduce-path /dev/char
always-reduce-path /dev/dri
always-reduce-path /dev/input
always-reduce-path /dev/mapper
always-reduce-path /dev/net
always-reduce-path /dev/pts
always-reduce-path /dev/snd
always-reduce-path /run/udev/data

protected-path /dev
protected-path /etc
protected-path /home
protected-path /nix
protected-path /proc/sys
protected-path /run
protected-path /srv
protected-path /var

high-protected-path /dev/mem
high-protected-path /dev/port

high-protected-path /etc/grsec
high-protected-path /dev/grsec

high-protected-path /etc/ssh
high-protected-path /etc/tarsnap
high-protected-path /etc/openvpn
read-protected-path /etc/ssh
read-protected-path /etc/tarsnap
read-protected-path /etc/openvpn

high-protected-path /etc/shadow
read-protected-path /etc/shadow

high-protected-path /proc/bus
high-protected-path /proc/kallsyms
high-protected-path /proc/kcore
high-protected-path /proc/modules
high-protected-path /proc/slabinfo
high-protected-path /proc/vmallocinfo

''

{ config, lib, pkgs, ... }:
with lib;

let
  generateLoginUserPolicy = cfg: ''
    role ${cfg.name} u
      subject /
        /

        /nix/store h
        /nix/store/* rx # */

        ${cfg.shell} x

        /dev
        /dev/null rw
        /dev/zero rw
        /dev/full rw
        /dev/urandom r

        ${cfg.home}
        /run/user/${cfg.uid}

        /tmp rwcd
        /var/tmp rwcd

      subject ${pkgs.shadow}/bin/login:${cfg.shell}
        /dev/tty rw
        /dev/console rw

        ${cfg.home} rwcdl
        /run/user/${cfg.uid} rwcdl

        ${cfg.home}/.gnupg h
        ${cfg.home}/.pki h
        ${cfg.home}/.ssh h
        ${cfg.home}/.cache/mozilla h
        ${cfg.home}/.mozilla h

        ${cfg.home}/.bash_profile r
        ${cfg.home}/.bashrc r

        ${cfg.home}/.zshrc r
        ${cfg.home}/.zlogin r
        ${cfg.home}/.zlogout r

        ${cfg.home}/.xinitrc r
        ${cfg.home}/.xprofile r

        /nix/store h
        /nix/store/* rxi # */
  '';
in

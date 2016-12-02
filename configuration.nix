{ config, lib, pkgs, ... }:
with lib;

{
  imports = [ ./grsecurity-rbac.nix ];

  networking.nameservers = [ "10.0.2.3" ];

  i18n.consoleKeyMap = "no-latin1";

  security.hideProcessInformation = true;

  users.mutableUsers = false;

  users.users.root.password = "pass";
  users.users.gray = {
    password = "pass";
    isNormalUser = true;
    group = "wheel";
  };

  services.xserver.enable = true;
  services.xserver.autorun = false;
  services.xserver.layout = "no";
  services.xserver.xkbOptions = "caps:escape";

  environment.systemPackages = with pkgs; [
    clisp
    tinycc

    curl
    elinks
    emacs
    git
    gnupg
    nethack
    ntp
    torbrowser
    w3m
    wget

    lsof
    ncdu
    strace

    gdb
    valgrind
  ];
}

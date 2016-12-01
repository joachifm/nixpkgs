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

  environment.systemPackages = with pkgs; [
    clisp
    curl
    elinks
    emacs
    git
    gnupg
    ncdu
    nethack
    ntp
    strace
    tinycc
    torbrowser
    valgrind
    w3m
    wget
  ];
}

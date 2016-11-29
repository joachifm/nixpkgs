{ config, lib, pkgs, ... }:
with lib;

{
  imports = [ ./grsecurity-rbac.nix ];

  security.hideProcessInformation = true;
  i18n.consoleKeyMap = "no-latin1";
  users.mutableUsers = false;
  users.users.root.password = "pass";
  users.users.gray = {
    password = "pass";
    isNormalUser = true;
    group = "wheel";
  };
  environment.systemPackages = with pkgs;
    [ ncdu
      emacs
      nethack
      torbrowser
    ];
}

{ config, lib, pkgs, ... }:
with lib;

{
  i18n.consoleKeyMap = "no-latin1";
  security.apparmor.enable = true;
  users.mutableUsers = false;
  users.users.root.password = "pass";
}

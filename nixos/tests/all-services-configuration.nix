{ config, lib, pkgs, ... }:

{
  networking.firewall.enable = false;
  networking.useDHCP = false;

  services.brltty.enable = false; /* BUGS */
  services.foldingAtHome.enable = false; /* BUG: assertion fails */
  services.namecoind.enable = false; /* BUG: cannot coerce null to a string */
  services.nsd.enable = false; /* BUG: attr outgoingInterface missing */
  services.terraria.enable = false; /* BUG: tmux.bin missing */
  services.gateone.enable = false; /* UX: default fails to start */
  services.icecast.enable = false; /* UX: default conf fails with hostname not a str */
}

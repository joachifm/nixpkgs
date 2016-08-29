{ config, lib, pkgs, ... }:

with lib;

let
  inherit (pkgs) runCommand;
  cfg = config.security.apparmor-ng;

  appArmorParserBin = "${pkgs.apparmor-parser}/bin/apparmor_parser";

  # This profile defines NixOS specific abstractions adapted to the
  # current system configuration.
  nixosProfile = pkgs.writeText "nixos" ''
    /etc/passwd r,
    /etc/group r,
    ${config.environment.etc."nsswitch.conf".source} r,
    ${getLib pkgs.glibc}/lib/*.so mr,
    ${pkgs.tzdata}/share/zoneinfo/** r,
    /nix/store/*/lib/*.so* mr, # */
  '';
in

{
  meta = {
    maintainers = with maintainers; [ joachifm ];
  };

  options.security.apparmor-ng = {
    enable = mkEnableOption "AppArmor mandatory access control";

    packages = mkOption {
      type = types.listOf types.package;
      default = [];
      description = ''
      '';
    };
  };

  config = mkIf cfg.enable {
    systemd.services.apparmor = {
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = appArmorParserBin;
        ExecStop = appArmorParserBin;
      };
    };
  };
}
/*
${pkgs.apparmor-parser}/bin/apparmor_parser -rKv -I ${pkgs.apparmor-profiles}/etc/apparmor.d "${p}
*/

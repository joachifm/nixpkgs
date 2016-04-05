{ config, pkgs, lib, ... }:
with lib;

{
  options = {
    security.hideProcessInformation = {
      enable = mkEnableOption "" // { description = ''
        Restrict access to process information to the owning user.  Enabling
        this option implies, among other things, that command-line arguments
        remain private.  This option is recommended for most systems, unless
        there's a legitimate reason for allowing unprivileged users to inspect
        the process information of other users.
      '';
      };
    };
  };

  config = mkIf (config.security.hideProcessInformation) {
    systemd.services.hidepid = {
      wantedBy = [ "sysinit.target" ];
      after = [ "local-fs.target" ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = ''${pkgs.utillinux}/bin/mount -o remount,hidepid=2 /proc'';
        ExecStop = ''${pkgs.utillinux}/bin/mount -o remount,hidepid=0 /proc'';
      };
      unitConfig.DefaultDependencies = false;
    };
  };
}

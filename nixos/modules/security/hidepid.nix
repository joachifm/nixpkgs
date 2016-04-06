{ config, pkgs, lib, ... }:
with lib;

let
  cfg = config.security.hideProcessInformation;
  gidArg = if cfg.procGID != null then toString gidArg else "0";
in

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
      procGID = mkOption {
        type = types.nullOr types.int;
        default = null;
        example = 1337;
        description = ''
          Members of this group can read the process information of other users.
          By default, all users except root are subject to process information
          hiding.
        '';
      };
    };
  };

  config = mkIf cfg.enable {
    systemd.services.hidepid = {
      wantedBy = [ "sysinit.target" ];
      after = [ "local-fs.target" ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = ''${pkgs.utillinux}/bin/mount -o remount,hidepid=2,gid=${gidArg} /proc'';
        ExecStop = ''${pkgs.utillinux}/bin/mount -o remount,hidepid=0 /proc'';
      };
      unitConfig.DefaultDependencies = false;
    };
  };
}

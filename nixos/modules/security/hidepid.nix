{ config, pkgs, lib, ... }:
with lib;

let
  cfg = config.security.hideProcessInformation;
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
          hiding. Services that require access to process information should be
          executing with this GID added to their supplementary groups (or as the
          primary group). This can be achieved by setting
          <literal>systemd.services.<name?>.serviceConfig.SupplementaryGroups</literal>.
        '';
      };
    };
  };

  config = {
    # Note: these options must be set regardless of whether the module is
    # "enabled" to ensure that the effect of enabling process information hiding
    # is undone when the module is disabled.
    fileSystems."/proc".options = [
      ''hidepid=${if cfg.enable then "2" else "0"}''
      ''gid=${if (cfg.enable && cfg.procGID != null) then "${toString cfg.procGID}" else "0"}''
    ];
  };
}

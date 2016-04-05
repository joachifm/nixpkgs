{ config, pkgs, lib, ... }:
with lib;

{
  options = {
    security.hideProcessInformation = {
      enable = mkEnableOption ''restricted access to process information to the
        owning user.  Enable this option to minimize what unprivileged users can
        learn about the processes of other users.  In particular, this option
        ensures that potentially sensitive information passed via command-line
        arguments remain private.

        This is a more compatible (less likely to break legitimate applications)
        alternative to GRsecurity's <literal>/proc</literal> hardening.

        Enabling this option is recommended for most systems, unless there's a
        legitimate reason for allowing unprivileged users to inspect the process
        information about other users.
      '';
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

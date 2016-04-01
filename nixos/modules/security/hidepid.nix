{ config, lib, ... }:
with lib;

{
  options = {
    security.hideProcessInformation = {
      enable = mkEnableOption = ''
        restrict access to process information to the process owner.  Enabling
        this option implies, among other things, that users can can only see
        their own processes and that information such as command-line arguments
        is not leaked between users.

        Note that a user may still discover which programs or PIDs are in use
        with <literal>pkill</literal> and <literal>kill</literal>
        (a permission denied error would indicate that the program or PID exists),
        but this requires much more work and provides less useful information than
        if process information is readily available.

        This option is a more lenient alternative to the <literal>/proc</literal>
        hardening provided by GRsecurity. Enabling this option is recommended
        unless you have a legitimate need for allowing unprivileged users to inspect
        process information owned by other users.
      '';
    };
  };

  config = mkIf (config.security.hideProcessInformation) {
    system.activationScripts.hidepid = ''
      mount -o remount,hidepid=2 /proc
    '';
  };
}

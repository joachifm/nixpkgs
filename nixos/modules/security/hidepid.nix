{ config, lib, ... }:
with lib;

{
  options = {
    security.hideProcessInformation = {
      enable = mkEnableOption ''restricted access to process information.
	Enable this option to minimize what unprivileged users can
	learn about the processes of other users.  In particular, this
	option ensures that potentially sensitive information passed
	via command-line arguments remain private.
      '';
    };
  };

  config = mkIf (config.security.hideProcessInformation) {
    system.activationScripts.hidepid = ''
      mount -o remount,hidepid=2 /proc
    '';
  };
}

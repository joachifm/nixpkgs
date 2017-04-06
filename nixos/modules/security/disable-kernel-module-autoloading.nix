{ config, lib, ... }:

with lib;

{
  options = {
    security.disableKernelModuleAutoloading = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Disable automatic kernel module loading.
      '';
    };
  };

  config = mkIf config.security.disableKernelModuleAutoloading {
    systemd.services.disable-kernel-module-autoloading = rec {
      description = "Disable automatic kernel module loading";

      # Assume that all legitimate module loading has occurred by the time
      # we're activated.  NOTE: may not hold if X11 is enabled but not
      # configured to run automatically.
      wantedBy = [ config.systemd.defaultUnit ];
      after = [ "systemd-modules-load.service" ] ++ wantedBy;

      script = "echo -n 1 > /proc/sys/kernel/modules_disabled";

      unitConfig.ConditionPathIsWritable = "/proc/sys/kernel";

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
    };
  };
}

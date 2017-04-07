{ config, lib, ... }:

with lib;

{
  options = {
    security.disableKernelModuleAutoloading = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Disable automatic kernel module loading once the system is fully
        initialised.  Module loading will be disabled until next reboot.
        Problems caused by delayed module loading are fixed by adding the
        module(s) in question to <option>boot.kernelModules</option>.
        Special care is required if you enable X11 without also
        configuring it to run automatically on startup.
      '';
    };
  };

  config = mkIf config.security.disableKernelModuleAutoloading {
    systemd.services.disable-kernel-module-autoloading = rec {
      description = "Disable automatic kernel module loading";

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

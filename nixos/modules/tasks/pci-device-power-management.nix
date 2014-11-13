{ config, lib, ... }:

{

  #### implementation

  config = lib.mkIf config.powerManagement.enable {

    systemd.services."pci-device-pm" = {
      description = "Enable automatic power management for coldplugged PCI devices.";

      wantedBy = [ "multi-user.target" ];
      requires = [ "systemd-udev-trigger.service" ];

      script = ''
        shopt -s nullglob
        for x in /sys/bus/pci/devices/*/power/control ; do echo -n auto >$x ; done
      '';

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = "yes";
      };

    };
  };
}

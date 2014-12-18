{ config, lib, ... }:

{

  #### implementation

  config = lib.mkIf config.powerManagement.enable {
    services.udev.extraRules = ''
      SUBSYSTEM=="pci", ACTION=="add", ATTR{power/control}="auto"
    '';
  };

}

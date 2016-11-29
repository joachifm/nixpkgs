{ config, lib, pkgs, ... }:
with lib;

let
  grPasswd = ./grsec/pw;
  grLearn = import ./learn_config.nix { inherit config lib pkgs; };
  grPolicyText = import ./policy.nix {
    inherit config lib pkgs;
  };
  grPolicy = pkgs.writeText "policy" grPolicyText;
in

{
  passthru = { inherit grPolicyText; };

  i18n.consoleKeyMap = "no-latin1";

  security.apparmor.enable = false;
  boot.kernelParams = [ "apparmor=0" ];
  security.grsecurity.enable = true;
  security.hideProcessInformation = true;

  users.mutableUsers = false;

  users.users.root.password = "pass";

  users.users.gray = {
    password = "pass";
    isNormalUser = true;
    group = "wheel";
  };

  environment.systemPackages = with pkgs;
    [ ncdu
      emacs
      nethack
    ];

  system.activationScripts."grsec" = ''
    mkdir -pv /etc/grsec
    chmod -c 700 /etc/grsec

    cp -v ${grPasswd} /etc/grsec/pw
    chmod 600 /etc/grsec/pw

    cp -v ${grPolicy} /etc/grsec/policy
    chmod 600 /etc/grsec/policy

    cp -v ${grLearn} /etc/grsec/learn_config
    chmod 600 /etc/grsec/learn_config
  '';

  systemd.services.grlearn = {
    after = [ "multi-user.target" ];
    script = ''
      ${pkgs.gradm}/bin/gradm -FL /var/log/grsec.log
    '';
  };
}

{ config, lib, pkgs, ... }:
with lib;

let
  gradmBin = "${lib.getBin pkgs.gradm}/bin/gradm";

  grPasswd = ./grsec/pw;

  grLearn = import ./learn_config.nix {
    inherit config lib pkgs;
  };

  grPolicyText = import ./policy.nix {
    inherit config lib pkgs;
  };

  grPolicy = pkgs.writeText "policy" grPolicyText;

  enableFullsystemLearning = false;

  enforcePolicy = true;
in

{
  config = {
    security.apparmor.enable = false;
    boot.kernelParams = [ "apparmor=0" ];
    security.grsecurity.enable = true;

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
      wantedBy = optionals enableFullsystemLearning [ "multi-user.target" ];
      script = ''
        logfile=/var/log/grsec.log
        d=0
        while [[ -f $logfile.$d ]] ; do
          d=$(($d + 1))
        done
        ${gradmBin} -FL $logfile.$d
      '';
    };

    systemd.services.load-grsec-policy = {
      after = [ "multi-user.target" ];
      wantedBy = optionals (enforcePolicy && !enableFullsystemLearning) [ "multi-user.target" ];
      serviceConfig.ExecStart = "${gradmBin} -E";
    };

    passthru = { inherit grPolicyText; };
  };
}

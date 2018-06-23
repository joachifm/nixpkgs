import ./make-test.nix ({ lib, ... }: with lib;

rec {
  name = "tor";
  meta.maintainers = with maintainers; [ joachifm ];

  common =
    { config, ... }:
    { boot.kernelParams = [ "audit=0" "apparmor=0" "quiet" ];
      networking.firewall.enable = false;
      networking.useDHCP = false;
      services.tor.extraConfig = ''
        TestingTorNetwork 1
      '';
    };

  nodes.client =
    { config, pkgs, ... }:
    { imports = [ common ];
      environment.systemPackages = with pkgs; [ netcat ];
      services.tor.enable = true;
      services.tor.client.enable = true;
      services.tor.client.privoxy.enable = false;
      services.tor.controlPort = 9051;
    };

  testScript = ''
    $client->waitForUnit("tor.service");
    $client->waitForOpenPort(9051);
    $client->succeed("echo GETINFO version | nc 127.0.0.1 9051");
  '';
})

import ./make-test.nix ({ lib, ... }: with lib;

rec {
  name = "tor";
  meta.maintainers = with maintainers; [ joachifm ];

  common =
    { config, ... }:
    { boot.kernelParams = [ "audit=0" "apparmor=0" "quiet" ];
      networking.firewall.enable = false;
      networking.useDHCP = false;
    };

  nodes.client =
    { config, pkgs, ... }:
    { imports = [ common ];
      services.tor.enable = true;
      services.tor.client.enable = true;
    };

  testScript = ''
    $client->waitForUnit("tor.service");
  '';
})

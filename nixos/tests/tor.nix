import ./make-test.nix ({ pkgs, ... }:

{
  name = "tor";
  meta = {
    maintainers = with pkgs.stdenv.lib.maintainers; [ joachifm ];
  };

  nodes =
    { client =
        { config, pkgs, ... }:
        {
          services.tor.enable = true;
          services.tor.client = {
            enable = true;
            socksListenAddress = "127.0.0.1:9050";
          };
          environment.systemPackages = with pkgs; [ curl torsocks ];
        };
    };

  testScript =
    { nodes, ... }:
    ''
      $client->waitForUnit("multi-user.target");
      $client->succeed("torsocks curl --fail --connect-timeout 2 https://check.torproject.org/");
    '';
})

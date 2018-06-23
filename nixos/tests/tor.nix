import ./make-test.nix ({ lib, ... }: with lib;

let
  # See ./tor/gencert
  auth1Data = builtins.filterSource (_: _: true) ./tor/auth1;
  auth1Fprint = readFile "${auth1Data}/fingerprint";

  auth2Data = builtins.filterSource (_: _: true) ./tor/auth2;
  auth2Fprint = readFile "${auth2Data}/fingerprint";
in

rec {
  name = "tor";
  meta.maintainers = with maintainers; [ joachifm ];

  common =
    { config, ... }:
    { boot.kernelParams = [ "audit=0" "apparmor=0" "quiet" ];
      networking.firewall.enable = false;
      networking.useDHCP = false;
      services.tor.extraConfig = ''
        ContactInfo tor-abuse@mail.example.com
        TestingTorNetwork 1
        DirAuthority auth1 orport=443 192.168.0.1:8080 ${auth1Fprint}
        DirAuthority auth2 orport=443 192.168.0.2:8080 ${auth2Fprint}
      '';
    };

  nodes.auth1 =
    { config, pkgs, ... }:
    { imports = [ common ];
      environment.systemPackages = with pkgs; [ netcat ];
      services.tor.enable = true;
      services.tor.client.enable = false;
      services.tor.extraConfig = ''
        Nickname auth1
        Address 192.168.0.1
        DirPort 0.0.0.0:8080
        ORPort 0.0.0.0:443
        AuthoritativeDirectory 1
        V3AuthoritativeDirectory 1
      '';
      networking.interfaces.eth1.ipv4.addresses = [
        { address = "192.168.0.1"; prefixLength = 24; }
      ];
      systemd.services.copy-keyfiles =
        let dataDir = "/var/lib/tor";
            authData = auth1Data;
        in {
        wantedBy = [ "tor.service" ];
        before = [ "tor.service" ];
        after = [ "local-fs.target" ];

        path = with pkgs; [ tor ];
        script = ''
          install -d ${dataDir} -m 700 -o tor -g tor

          cp -va ${authData}/* ${dataDir}/
          chown -c -R tor:tor ${dataDir}/*

          touch ${dataDir}/.initialized
        '';
        unitConfig.ConditionPathExists = "!${dataDir}/.initialized";
        serviceConfig.Type = "oneshot";
        serviceConfig.RemainAfterExit = true;
      };
    };

  nodes.auth2 =
    { config, pkgs, ... }:
    { imports = [ common ];
      environment.systemPackages = with pkgs; [ netcat ];
      services.tor.enable = true;
      services.tor.client.enable = false;
      services.tor.extraConfig = ''
        Nickname auth2
        Address 192.168.0.2
        DirPort 0.0.0.0:8080
        ORPort 0.0.0.0:443
        AuthoritativeDirectory 1
        V3AuthoritativeDirectory 1
      '';
      networking.interfaces.eth1.ipv4.addresses = [
        { address = "192.168.0.2"; prefixLength = 24; }
      ];
      systemd.services.copy-keyfiles =
        let dataDir = "/var/lib/tor";
            authData = auth2Data;
        in {
        wantedBy = [ "tor.service" ];
        before = [ "tor.service" ];
        after = [ "local-fs.target" ];

        path = with pkgs; [ tor ];
        script = ''
          install -d ${dataDir} -m 700 -o tor -g tor

          cp -va ${authData}/* ${dataDir}/
          chown -c -R tor:tor ${dataDir}/*

          touch ${dataDir}/.initialized
        '';
        unitConfig.ConditionPathExists = "!${dataDir}/.initialized";
        serviceConfig.Type = "oneshot";
        serviceConfig.RemainAfterExit = true;
      };
    };

  /*
  nodes.client =
    { config, pkgs, ... }:
    { imports = [ common ];
      environment.systemPackages = with pkgs; [ netcat ];
      services.tor.enable = true;
      services.tor.client.enable = true;
      services.tor.client.privoxy.enable = false;
      services.tor.controlPort = 9051;
      networking.interfaces.eth1.ipv4.addresses = [
        { address = "192.168.0.3"; prefixLength = 24; }
      ];
    };
  */

  testScript = ''
    $auth1->waitForUnit("tor.service");
    $auth1->waitForOpenPort(443);

    $auth2->waitForUnit("tor.service");
    $auth2->waitForOpenPort(443);
  '';

  /*
    $client->waitForUnit("tor.service");
    $client->waitForOpenPort(9051);
    $client->succeed("echo GETINFO version | nc 127.0.0.1 9051");
  '';
  */
})

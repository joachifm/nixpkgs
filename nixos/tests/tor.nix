import ./make-test.nix ({ lib, ... }: with lib;

let
  getFirstIpV4AddrOn = iface: cfg:
    (head cfg.networking.interfaces.eth1.ipv4.addresses).address;

  readFileNoNewline = fname: replaceStrings ["\n"] [""] (readFile fname);

  dirPort = "8080";
  orPort = "443";
  controlPort = "9051";

  # See ./tor/gencert.  Pre-generated only because we need to know the fingerprints
  # ahead of time.
  auth1Data = builtins.filterSource (_: _: true) ./tor/auth1;
  auth1V3Fprint = readFileNoNewline "${auth1Data}/v3fingerprint";
  auth1Fprint = readFileNoNewline "${auth1Data}/fingerprint_plain";
in

rec {
  name = "tor";
  meta.maintainers = with maintainers; [ joachifm ];

  common =
    { config, ... }:
    { boot.kernelParams = [ "audit=0" "apparmor=0" "quiet" ];
      networking.firewall.enable = false;
      networking.useDHCP = false;
      services.tor.controlPort = controlPort;
      services.tor.extraConfig = ''
        Log warn
        TestingTorNetwork 1
        DirAuthority auth1 orport=${orPort} no-v2 v3ident=${auth1V3Fprint} 192.168.0.1:${dirPort} ${auth1Fprint}
      '';
    };

  router = ipV4Address:
    { config, pkgs, ... }:
    { imports = [ common ];
      environment.systemPackages = with pkgs; [ netcat ];
      services.tor.enable = true;
      services.tor.relay.enable = true;
      services.tor.relay.address = ipV4Address;
      services.tor.relay.port = orPort;
      services.tor.relay.nickname = mkDefault "Unnamed";
      services.tor.relay.contactInfo = "tor-abuse@mail.example.com";
      services.tor.relay.role = mkDefault "exit";
      services.tor.extraConfig = optionalString (config.services.tor.relay.role == "exit") ''
        ExitPolicy accept 192.168.1.0/24:*
        ExitRelay 1
      '';
      systemd.services.tor-genkey =
        let dataDir = "/var/lib/tor";
        in {
        wantedBy = [ "tor.service" ];
        before = [ "tor.service" ];
        after = [ "local-fs.target" ];

        path = with pkgs; [ tor ];
        script = ''
          echo "Generating onion router keys ..."
          set -x
          install -d ${dataDir} -m 700 -o tor -g tor
          echo -n password | tor --quiet --User tor --keygen --DataDirectory ${dataDir} --passphrase-fd 0
          tor --quiet --list-fingerprint \
              --User tor \
              --Nickname ${config.services.tor.relay.nickname} \
              --ORPort 1 \
              --DirServer "x 127.0.0.1:1 ffffffffffffffffffffffffffffffffffffffff" \
              --DataDirectory ${dataDir}
          chown -R tor:tor ${dataDir}
          rm -f ${dataDir}/lock
        '';

        serviceConfig.Type = "oneshot";
        serviceConfig.RemainAfterExit = true;
      };
      networking.interfaces.eth1.ipv4.addresses = [
        { address = ipV4Address; prefixLength = 24; }
      ];
    };

  nodes.dir =
    { config, pkgs, ... }:
    { imports = [ common ];
      environment.systemPackages = with pkgs; [ netcat ];
      services.tor.enable = true;
      services.tor.client.enable = false;
      services.tor.extraConfig = ''
        Nickname auth1
        Address 192.168.0.1
        ContactInfo tor-abuse@mail.example.com

        DirPort ${dirPort}
        ORPort ${orPort}
        AuthoritativeDirectory 1
        V3AuthoritativeDirectory 1
        ExitPolicy accept 192.168.1.0/24:*
        ExitRelay 1
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
          chown -R tor:tor ${dataDir}/*

          touch ${dataDir}/.initialized
        '';
        unitConfig.ConditionPathExists = "!${dataDir}/.initialized";
        serviceConfig.Type = "oneshot";
        serviceConfig.RemainAfterExit = true;
      };
    };

  nodes.cli =
    { config, pkgs, ... }:
    { imports = [ common ];
      environment.systemPackages = with pkgs; [ netcat ];
      services.tor.enable = true;
      services.tor.client.enable = true;
      services.tor.client.privoxy.enable = false;
      networking.interfaces.eth1.ipv4.addresses = [
        { address = "192.168.0.2"; prefixLength = 24; }
      ];
    };

  nodes.ex1 =
    { config, pkgs, ... }:
    { imports = [ (router "192.168.0.3") ];
    };

  nodes.www =
    { config, pkgs, ... }:
    let
      handler = pkgs.writeScript "handler" ''
        #! ${pkgs.bash}
        content='<html><body><h1>Hello</h1></body></html>'

        printf 'HTTP/1.0 200 OK\r\n'
        printf 'Content-type: text/html\r\n'
        printf 'Content-length: %d\r\n' ''${#content}
        printf '%s\r\n' "$content"
        printf '\r\n'
      '';
    in
    { imports = [ (router "192.168.0.4") ];
      services.tor.hiddenServices."www".map = [
        { port = 80; }
      ];
      systemd.services.www = {
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];
        path = with pkgs; [ netcat ];
        script = ''
          while : ; do
            ${handler} | nc -l 80
          done
        '';
      };
    };

  testScript = ''
    startAll;

    $dir->waitForUnit("tor.service");
    $dir->waitForOpenPort(${dirPort});

    $www->waitForUnit("tor.service");
    $ex1->waitForUnit("tor.service");

    $cli->waitForOpenPort(${controlPort});
    $cli->succeed("echo GETINFO version | nc 127.0.0.1 ${controlPort}");
  '';

  /*
    # TODO: actually route over tor ...
    $www->waitForOpenPort(80);
    #$cli->execute("printf 'GET / HTTP/1.0\r\n\r\n' | nc 192.168.0.5 80");
  '';
  */
})

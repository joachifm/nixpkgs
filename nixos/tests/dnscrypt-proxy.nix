import ./make-test.nix ({ pkgs, ... }: {
  name = "dnscrypt-proxy";
  meta = with pkgs.stdenv.lib.maintainers; {
    maintainers = [ joachifm ];
  };

  nodes =
    let
      # A dummy keypair used by our test DNSCrypt server.
      dummyProviderKeypair = pkgs.runCommand "dummy-provider-keypair" {} ''
        mkdir $out
        cd $out
        ${pkgs.dnscrypt-wrapper}/bin/dnscrypt-wrapper --gen-provider-keypair
        echo -n $(${pkgs.dnscrypt-wrapper}/bin/dnscrypt-wrapper \
          --show-provider-publickey-fingerprint \
          --provider-publickey-file public.key \
          | cut -d ' ' -f6) >pubkey_id.txt
      '';
  in
  {
    # A client running the recommended setup: DNSCrypt proxy as a
    # forwarder for a caching DNS client.
    client =
    { config, lib, pkgs, nodes, ... }:
    {
      security.apparmor.enable = true;

      networking.nameservers = lib.mkForce [ "127.0.0.1" ];
      networking.useDHCP = false;

      services.dnscrypt-proxy.enable = true;
      services.dnscrypt-proxy.localPort = 42;
      services.dnscrypt-proxy.customResolver = {
        address = "${(lib.head nodes.server.config.networking.interfaces.eth1.ip4).address}";
        port = 443;
        name = "2.dnscrypt-cert.example.com";
        key = builtins.readFile "${dummyProviderKeypair}/pubkey_id.txt";
      };

      services.dnsmasq.enable = true;
      services.dnsmasq.servers = [ "127.0.0.1#${toString config.services.dnscrypt-proxy.localPort}" ];
    };

    # A DNSCrypt server
    server =
    { config, pkgs, ... }:
    {
      services.unbound.enable = true;

      virtualisation.vlans = [ 1 ];

      # We just need the service to return *something*
      services.unbound.extraConfig = ''
        local-zone: "101com.com" redirect
        local-data: "nixos.example.com A 127.0.0.1"
      '';

      networking.firewall.allowedUDPPorts = [ 443 ];
      networking.useDHCP = false;

      # An ad-hoc service that adds DNSCrypt support to our unbound instance
      systemd.services.dnscrypt-wrapper = {
        wants = [ "unbound.service" ];
        after = [ "network.target" "unbound.service" ];
        wantedBy = [ "multi-user.target" ];

        serviceConfig = {
          ExecStart = pkgs.writeScript "dnscrypt-wrapper" ''
            #! /bin/sh
            PATH=${pkgs.dnscrypt-wrapper}/bin
            dnscrypt-wrapper --gen-crypt-keypair --crypt-secretkey-file=1.key
            dnscrypt-wrapper --gen-cert-file --crypt-secretkey-file=1.key \
              --provider-cert-file=1.cert \
              --provider-publickey-file=${dummyProviderKeypair}/public.key \
              --provider-secretkey-file=${dummyProviderKeypair}/secret.key \
              --cert-file-expire-days=365
            dnscrypt-wrapper --resolver-address=127.0.0.1:53 \
              --listen-address=0.0.0.0:443 \
              --provider-name=2.dnscrypt-cert.example.com \
              --crypt-secretkey-file=1.key --provider-cert-file=1.cert
          '';
        };
      };
    };
  };

  testScript = ''
    startAll;

    $server->waitForUnit("dnscrypt-wrapper.service");

    $client->waitForUnit("sockets.target");
    $client->execute("${pkgs.iputils}/bin/ping -c1 example.com");
    $client->succeed("systemctl is-active dnscrypt-proxy");
  '';
})

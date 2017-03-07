import ./make-test.nix ({ pkgs, ... }: {
  name = "dnscrypt-proxy";
  meta = with pkgs.stdenv.lib.maintainers; {
    maintainers = [ joachifm ];
  };

  nodes = {
    # All defaults
    client1 =
    { config, pkgs, ... }:
    {
      services.dnscrypt-proxy.enable = true;
    };

    # Using a custom resolver
    client2 =
    { config, pkgs, ... }:
    {
      services.dnscrypt-proxy.enable = true;
      services.dnscrypt-proxy.customResolver = {
        address = "203.0.113.1";
        port = 443;
        name = "2.dnscrypt.resolver.example";
        key = "E801:B84E:A606:BFB0:BAC0:CE43:445B:B15E:BA64:B02F:A3C4:AA31:AE10:636A:0790:324D";
      };
    };

    # Running as a forwarder for another client
    client3 =
    { config, pkgs, ... }:
    let localProxyPort = 43; in
    {
      security.apparmor.enable = true;

      services.dnscrypt-proxy.enable = true;
      services.dnscrypt-proxy.listenPort = localProxyPort;

      services.dnsmasq.enable = true;
      services.dnsmasq.resolveLocalQueries = true;
      services.dnsmasq.servers = [ "127.0.0.1#${toString localProxyPort}" ];
    };
  };

  testScript = ''
    $client1->execute("${pkgs.iputils}/bin/ping -c1 example.com");
    $client1->succeed("systemctl is-active dnscrypt-proxy");

    $client2->execute("${pkgs.iputils}/bin/ping -c1 example.com");
    $client2->succeed("systemctl is-active dnscrypt-proxy");

    $client3->waitForUnit("dnsmasq");
    $client3->execute("${pkgs.iputils}/bin/ping -c1 example.com");
    $client3->succeed("systemctl is-active dnscrypt-proxy");
  '';
})

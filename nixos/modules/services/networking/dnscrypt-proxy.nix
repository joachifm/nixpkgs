{ config, lib, pkgs, ... }:
with lib;

let
  cfg = config.services.dnscrypt-proxy;

  # Local state.  Unused if user specifies a custom upstream
  # resolver.
  stateDirectory = "/var/lib/dnscrypt-proxy";

  # Full path to local resolvers list.  Unused if user specifies
  # a custom upstream resolver.
  resolversList = "${stateDirectory}/dnscrypt-resolvers.csv";

  # Internal flag to indicate whether to use the upstream
  # resolvers list.
  useUpstreamResolversList = cfg.customResolver == null;

  # Internal flag to indicate whether dnscrypt-proxy has been
  # configured to resolve local queries.
  resolveLocalQueries = cfg.listenAddr == "127.0.0.1" && cfg.listenPort == 53;

  # The minisign public key used to sign the upstream resolver
  # list.  This is somewhat more flexible than preloading the
  # key as an embedded string.
  upstreamResolversListPubKey = pkgs.fetchurl {
    url = https://raw.githubusercontent.com/jedisct1/dnscrypt-proxy/master/minisign.pub;
    sha256 = "18lnp8qr6ghfc2sd46nn1rhcpr324fqlvgsp4zaigw396cd7vnnh";
  };

  upstreamBaseUrl = "https://download.dnscrypt.org/dnscrypt-proxy";

  # The initial resolver list.  A conservative default is to use
  # ${pkgs.dnscrypt-proxy}/share/dnscrypt-proxy/dnscrypt-resolvers.csv
  # but it is prone to becoming out-of-date.
  upstreamResolversListInitial = pkgs.fetchurl {
    url = "${upstreamBaseUrl}/dnscrypt-resolvers.csv";
    sha256 = "1ddl2n7g833lmjvnws76nnc78gzl3pr1jqid7irnjn5lpr9s6l5s";
  };

  # Extract canonical name based on the resolver config.
  instanceName =
    if (cfg.customResolver == null)
      then cfg.resolverName
      else cfg.customResolver.name;

  # Configuration file text used for all client configs.
  commonConfigText = ''
    Daemonize no
  '';

  # Generate full dnscrypt-proxy.conf text for a given client
  # proxy configuration.
  #
  # The listening address and port are configured exclusively
  # via the socket unit and so are not mentioned here.
  configText = ''
    ${commonConfigText}

    ${if (cfg.customResolver == null) then ''
      ResolverName ${cfg.resolverName}
      ResolversList ${resolversList}
    '' else ''
      ProviderName ${cfg.customResolver.name}
      ProviderKey ${cfg.customResolver.key}
      ResolverAddress ${cfg.customResolver.address}:${toString cfg.customResolver.port}
    ''}

    ${optionalString (cfg.listenPort == 53) ''
      LocalCache on
    ''}

    ${cfg.extraConfig}
  '';

  configFile = pkgs.writeText "dnscrypt-proxy-${instanceName}.conf" configText;

  unitCommon = {
    description = "DNSCrypt client proxy";
    documentation = [ "man:dnscrypt-proxy(8)" ];
    restartTriggers = [ configFile ];
  };

  # Generate the socket unit for a given proxy client instance config.
  socketUnit = unitCommon // {
    wantedBy = [ "sockets.target" ];
    socketConfig = {
      ListenStream = "${cfg.listenAddr}:${toString cfg.listenPort}";
      ListenDatagram = "${cfg.listenAddr}:${toString cfg.listenPort}";
    };
  };

  # Generate the service unit for a given proxy client instance config.
  serviceUnit = unitCommon // {
    requires = [ "dnscrypt-proxy.socket" ];
    after = [ "network.target" ];
    before = [ "nss-lookup.target" ];

    serviceConfig = {
      NonBlocking = true;
      User = "dnscrypt-proxy";
      ExecStart = "${pkgs.dnscrypt-proxy}/bin/dnscrypt-proxy ${configFile}";
    };
  };

  # A module that fully describes an upstream resolver.
  resolverModule = types.submodule ({ ... }: { options = {
    address = mkOption {
      description = "IP address";
      type = types.str;
      example = "203.0.113.1";
    };

    port = mkOption {
      description = "Port";
      type = types.int;
      default = 443;
    };

    name = mkOption {
      description = "Fully qualified domain name";
      type = types.str;
      example = "2.dnscrypt.resolver.example";
    };

    key = mkOption {
      description = "Public key";
      type = types.str;
      example = "E801:B84E:A606:BFB0:BAC0:CE43:445B:B15E:BA64:B02F:A3C4:AA31:AE10:636A:0790:324D";
    };
  }; });
in

{
  meta = {
    maintainers = with maintainers; [ joachifm ];
    doc = ./dnscrypt-proxy.xml;
  };

  options.services.dnscrypt-proxy = {
    # Before adding another option here, please consider whether
    # it could equally well be specified via extraConfig.

    enable = mkOption {
      description = "Whether to enable DNSCrypt client proxy.";
      type = types.bool;
      default = false;
    };

    listenAddr = mkOption {
      description = "Local listening address.";
      type = types.str;
      default = "127.0.0.1";
    };

    listenPort = mkOption {
      description = "Local listening port.";
      type = types.int;
      default = 53;
    };

    resolverName = mkOption {
      description = "Name of listed upstream resolver";
      type = types.str;
      default = "dnscrypt.eu-nl";
    };

    customResolver = mkOption {
      description = ''
        Use an unlisted upstream resolver.  If specified, this
        option takes precedence.
      '';
      type = types.nullOr resolverModule;
      default = null;
    };

    extraConfig = mkOption {
      description = ''
        Additional configuration text, appended verbatim.  See
        <citerefentry><refentrytitle>dnscrypt-proxy</refentrytitle><manvolnum>8</manvolnum></citerefentry>
        for details.
      '';
      type = types.lines;
      default = "";
    };
  };

  config = mkIf cfg.enable {
    assertions =
      [ { assertion = resolveLocalQueries -> !(config.services.dnsmasq.enable && config.services.dnsmasq.resolveLocalQueries);
          message = "Both dnscrypt-proxy and dnsmasq configured to resolve local queries.";
        }
        { assertion = resolveLocalQueries ->
            !(config.services.unbound.enable && any [ "::1" "127.0.0.1" ] config.services.unbound.interfaces);
          message = "Both dnscrypt-proxy and unbound configured to resolve local queries.";
        }
      ];

    users.users.dnscrypt-proxy = {
      description = "DNSCrypt proxy daemon user";
      isSystemUser = true;
      group = "dnscrypt-proxy";
    };
    users.groups.dnscrypt-proxy = {};

    networking.nameservers = mkIf resolveLocalQueries (mkForce [ "127.0.0.1" ]);

    systemd.sockets."dnscrypt-proxy" = socketUnit;
    systemd.services."dnscrypt-proxy" = serviceUnit;

    systemd.services."init-dnscrypt-proxy-statedir" = {
      description = "Initialize dnscrypt-proxy state directory";

      after = [ "local-fs.target" ];
      before = [ "dnscrypt-proxy.service" ];
      wantedBy = [ "dnscrypt-proxy.service" ];

      script = ''
        mkdir -p "${stateDirectory}"
        chown -c dnscrypt-proxy:dnscrypt-proxy "${stateDirectory}"
        cp -uv "${upstreamResolversListInitial}" "${stateDirectory}/dnscrypt-resolvers.csv"
      '';

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
    };

    systemd.services."update-dnscrypt-resolvers" = {
      description = "Update DNSCrypt resolvers list";

      after = [ "network-online.target" "init-dnscrypt-proxy-statedir.service" ];
      requires = [ "network-online.target" "init-dnscrypt-proxy-statedir.service" ];

      path = with pkgs; [ curl minisign ];
      script = ''
        cd "${stateDirectory}"
        curl -fSsL -o dnscrypt-resolvers.csv.tmp \
          ${upstreamBaseUrl}/dnscrypt-resolvers.csv
        curl -fSsL -o dnscrypt-resolvers.csv.minisig.tmp \
          ${upstreamBaseUrl}/dnscrypt-resolvers.csv.minisig
        mv dnscrypt-resolvers.csv.minisig{.tmp,}
        minisign -q -V \
          -p ${upstreamResolversListPubKey} \
          -m dnscrypt-resolvers.csv.tmp \
          -x dnscrypt-resolvers.csv.minisig
        mv dnscrypt-resolvers.csv{.tmp,}
      '';
    };

    systemd.timers."update-dnscrypt-resolvers" = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "5min";
        OnUnitActiveSec = "6h";
      };
    };
  };

  imports = [
    (mkRenamedOptionModule [ "services" "dnscrypt-proxy" "port" ] [ "services" "dnscrypt-proxy" "localPort" ])
    (mkRenamedOptionModule [ "services" "dnscrypt-proxy" "localPort" ] [ "services" "dnscrypt-proxy" "listenPort" ])
  ];
}

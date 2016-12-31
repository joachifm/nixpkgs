{ config, lib, pkgs, ... }:
with lib;

let
  cfg = config.services.dnscrypt-proxy;

  stateDirectory = "/var/lib/dnscrypt-proxy";

  # The minisign public key used to sign the upstream resolver list.
  # This is somewhat more flexible than preloading the key as an
  # embedded string.
  upstreamResolverListPubKey = pkgs.fetchurl {
    url = https://raw.githubusercontent.com/jedisct1/dnscrypt-proxy/master/minisign.pub;
    sha256 = "18lnp8qr6ghfc2sd46nn1rhcpr324fqlvgsp4zaigw396cd7vnnh";
  };

  # Internal flag indicating whether to use the upstream resolver list
  useUpstreamResolverList = cfg.customResolver == null;

  # Build the command-line
  resolverList = "${stateDirectory}/dnscrypt-resolvers.csv";

  localAddress = "${cfg.localAddress}:${toString cfg.localPort}";

  resolverArgs = if (cfg.customResolver != null)
    then
      [ "--resolver-address=${cfg.customResolver.address}:${toString cfg.customResolver.port}"
        "--provider-name=${cfg.customResolver.name}"
        "--provider-key=${cfg.customResolver.key}"
      ]
    else
      [ "--resolvers-list=${resolverList}"
        "--resolver-name=${cfg.resolverName}"
      ];

  # Final daemon command-line arguments
  daemonArgs =
    [ "--local-address=${localAddress}" ]
    ++ resolverArgs
    ++ cfg.extraArgs;
in

{
  meta = {
    maintainers = with maintainers; [ joachifm ];
    doc = ./dnscrypt-proxy.xml;
  };

  options = {
    services.dnscrypt-proxy = {
      enable = mkOption {
        default = false;
        type = types.bool;
        description = ''
          Whether to enable the DNSCrypt proxy client daemon.
        '';
      };

      localAddress = mkOption {
        default = "127.0.0.1";
        type = types.str;
        description = ''
          Listen for DNS queries to relay on this address. The only reason to
          change this from its default value is to proxy queries on behalf
          of other machines (typically on the local network).
        '';
      };

      localPort = mkOption {
        default = 53;
        type = types.int;
        description = ''
          Listen for DNS queries to relay on this port. The default value
          assumes that the DNSCrypt proxy should relay DNS queries directly.
          When running as a forwarder for another DNS client, set this option
          to a different value; otherwise leave the default.
        '';
      };

      resolverName = mkOption {
        default = "dnscrypt.eu-nl";
        type = types.nullOr types.str;
        description = ''
          The name of the upstream DNSCrypt resolver to use, taken from
          <filename>${resolverList}</filename>.  The default resolver is
          located in Holland, supports DNS security extensions, and
          <emphasis>claims</emphasis> to not keep logs.
        '';
      };

      customResolver = mkOption {
        default = null;
        description = ''
          Use an unlisted resolver (e.g., a private DNSCrypt provider). For
          advanced users only. If specified, this option takes precedence.
        '';
        type = types.nullOr (types.submodule ({ ... }: { options = {
          address = mkOption {
            type = types.str;
            description = "IP address";
            example = "208.67.220.220";
          };

          port = mkOption {
            type = types.int;
            description = "Port";
            default = 443;
          };

          name = mkOption {
            type = types.str;
            description = "Fully qualified domain name";
            example = "2.dnscrypt-cert.opendns.com";
          };

          key = mkOption {
            type = types.str;
            description = "Public key";
            example = "B735:1140:206F:225D:3E2B:D822:D7FD:691E:A1C3:3CC8:D666:8D0C:BE04:BFAB:CA43:FB79";
          };
        }; }));
      };

      extraArgs = mkOption {
        type = types.listOf types.str;
        description = "Additional command-line arguments";
        default = [];
        example = [ "--ephemeral-keys" ];
      };

    };
  };

  config = mkIf cfg.enable {

    # For man page and hostip utility
    environment.systemPackages = with pkgs; [ dnscrypt-proxy ];

    users.users.dnscrypt-proxy = {
      description = "dnscrypt-proxy daemon user";
      isSystemUser = true;
      group = "dnscrypt-proxy";
    };
    users.groups.dnscrypt-proxy = {};

    systemd.services.init-dnscrypt-proxy-statedir = optionalAttrs useUpstreamResolverList {
      description = "Initialize dnscrypt-proxy state directory";
      script = ''
        mkdir -pv ${stateDirectory}
        chown -c dnscrypt-proxy:dnscrypt-proxy ${stateDirectory}
        cp --preserve=timestamps -uv \
          ${pkgs.dnscrypt-proxy}/share/dnscrypt-proxy/dnscrypt-resolvers.csv \
          ${stateDirectory}
      '';
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
    };

    systemd.services.update-dnscrypt-resolvers = optionalAttrs useUpstreamResolverList {
      description = "Update list of DNSCrypt resolvers";

      requires = [ "init-dnscrypt-proxy-statedir.service" ];
      after = [ "init-dnscrypt-proxy-statedir.service" ];

      path = with pkgs; [ curl minisign ];
      script = ''
        cd ${stateDirectory}
        curl -fSsL -o dnscrypt-resolvers.csv.tmp \
          https://download.dnscrypt.org/dnscrypt-proxy/dnscrypt-resolvers.csv
        curl -fSsL -o dnscrypt-resolvers.csv.minisig.tmp \
          https://download.dnscrypt.org/dnscrypt-proxy/dnscrypt-resolvers.csv.minisig
        mv dnscrypt-resolvers.csv.minisig{.tmp,}
        minisign -q -V -p ${upstreamResolverListPubKey} \
          -m dnscrypt-resolvers.csv.tmp -x dnscrypt-resolvers.csv.minisig
        mv dnscrypt-resolvers.csv{.tmp,}
      '';

      serviceConfig = {
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectHome = true;
        ProtectSystem = "full";
        ReadWritePaths = stateDirectory;
        MemoryDenyWriteExecute = true;
        RestrictAddressFamilies = "AF_UNIX AF_INET AF_INET6";
        SystemCallArchitectures = "native";
      };
    };

    systemd.timers.update-dnscrypt-resolvers = optionalAttrs useUpstreamResolverList {
      timerConfig = {
        OnBootSec = "5min";
        OnUnitActiveSec = "6h";
      };
      wantedBy = [ "timers.target" ];
    };

    systemd.sockets.dnscrypt-proxy = {
      description = "dnscrypt-proxy listening socket";
      socketConfig = {
        ListenStream = localAddress;
        ListenDatagram = localAddress;
      };
      wantedBy = [ "sockets.target" ];
    };

    systemd.services.dnscrypt-proxy = {
      description = "dnscrypt-proxy daemon";

      before = [ "nss-lookup.target" ];

      after = [ "network.target" ]
        ++ optional useUpstreamResolverList "init-dnscrypt-proxy-statedir.service";

      requires = [ "dnscrypt-proxy.socket "]
        ++ optional useUpstreamResolverList "init-dnscrypt-proxy-statedir.service";

      serviceConfig = {
        Type = "simple";
        NonBlocking = "true";
        ExecStart = "${pkgs.dnscrypt-proxy}/bin/dnscrypt-proxy ${toString daemonArgs}";

        User = "dnscrypt-proxy";

        PrivateTmp = true;
        PrivateDevices = true;
        ProtectHome = true;
        MemoryDenyWriteExecute = true;
        RestrictAddressFamilies = "AF_UNIX AF_INET AF_INET6";
        SystemCallArchitectures = "native";
      };
    };
  };
}

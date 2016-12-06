{ config, lib, pkgs, ... }:
with lib;

let

  cfg = config.services.cjdns;

  cjdnsBin = "${getBin pkgs.cjdns}/bin";

  stateDir = "/var/lib";
  pubfile = "${stateDir}/cjdns.pub";
  prvfile = "${stateDir}/cjdns.prv";

  # The final cjdroute.conf
  cjdrouteConf = builtins.toJSON {
    privatekey = "@CJDNS_PRIVKEY@";

    ipv6 = "@CJDNS_IPV6@";
    publickey = "@CJDNS_PUBKEY@";

    ETHInterface = [
      { bind = "all";
        beacon = 2;
      }
    ];

    router.interface.type = "TUNInterface";

    ipTunnel = {
      allowedConnections = [];
      outgoingConnections = [];
    };

    security = [
      { setuser = "nobody"; keepNetAdmin = 1; }
      { chroot = "/var/empty"; }
      { noforks = 1; }
      { seccomp = 1; }
      { setupComplete = 1; }
    ];

    logging.logTo = "stdout";
    pipe = "/run";
  };

in

{
  options.services.cjdns = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Whether to enable the cjdns routing engine.
      '';
    };
  };

  config = mkIf cfg.enable {
    systemd.packages = with pkgs; [ cjdns ];

    systemd.services.cjdns = {
      description = "cjdns: routing engine";

      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      preStart = ''
        umask 077

        [[ -e "${pubfile}" ]] && . "${pubfile}"
        [[ -e "${prvfile}" ]] && . "${prvfile}"

        if [[ -z "$CJDNS_PRIVKEY" ]] ; then
          ${cjdnsBin}/makekeys | read prvkey ipv6 pubkey

          mkdir -p "${stateDir}"

          cat >"${prvfile}" <<EOF
          CJDNS_PRIVKEY=$prvkey
          EOF
          unset prvkey

          cat >"${pubfile}" <<EOF
          CJDNS_IPV6=$ipv6
          CJDNS_PUBKEY=$pubkey
          EOF
          unset ipv6 pubkey
        fi
      '';

      script = ''
        . "${pubfile}" "${prvfile}"

        sed ${cjdrouteConf} \
          -e "s,@CJDNS_PRIVKEY@,$CJDNS_PRIVKEY," \
          -e "s,@CJDNS_PUBKEY@,$CJDNS_PUBKEY," \
          -e ",s@CJDNS_IPV6@$CJDNS_IPV6," \
          | ${cjdnsBin}/cjdroute --nobg
      '';

      serviceConfig = {
        CapabilityBoundingSet = "CAP_NET_ADMIN CAP_NET_RAW"
          + "CAP_SYS_CHROOT CAP_SETUID CAP_SETGID";
        NoNewPrivileges = true;

        # Isolation
        ProtectHome = true;
        ProtectSystem = "strict";
        ReadWritePaths = stateDir;
      };
    }
  };
}

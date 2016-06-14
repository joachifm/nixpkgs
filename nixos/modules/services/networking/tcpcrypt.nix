{ config, lib, pkgs, ... }:

with lib;

let

  cfg = config.networking.tcpcrypt;

  divertPort = 666;
  runtimeDir = "/run/tcpcryptd";
  ctrlSocket = "/run/tcpcryptd-ctrl.socket";

in

{

  ###### interface

  options = {

    networking.tcpcrypt.enable = mkOption {
      default = false;
      description = ''
        Whether to enable opportunistic TCP encryption. If the other end
        speaks Tcpcrypt, then your traffic will be encrypted; otherwise
        it will be sent in clear text. Thus, Tcpcrypt alone provides no
        guarantees -- it is best effort. If, however, a Tcpcrypt
        connection is successful and any attackers that exist are
        passive, then Tcpcrypt guarantees privacy.
      '';
    };
  };

  config = mkIf cfg.enable {

    users.extraUsers.tcpcryptd = {
      description = "tcpcrypt daemon user";
      isSystemUser = true;
    };

    # We would like to use systemd's User feature, but the daemon expects to
    # run as root so as to chroot and drop privileges by itself ...

    systemd.services.tcpcrypt = {
      description = "tcpcrypt";

      wantedBy = [ "multi-user.target" ];
      after = [ "network-interfaces.target" ];

      path = with pkgs; [ iptables tcpcrypt procps ];

      preStart = ''
        # Ideally, we'd use RuntimeDirectory, but since we're running as root,
        # the permissions would end up wrong, so do it manually.
        mkdir -m 755 -p ${runtimeDir}
        chown tcpcryptd ${runtimeDir}

        sysctl -n net.ipv4.tcp_ecn >/run/pre-tcpcrypt-ecn-state
        sysctl -w net.ipv4.tcp_ecn=0

        iptables -t raw -N nixos-tcpcrypt
        iptables -t raw -A nixos-tcpcrypt -p tcp -m mark --mark 0x0/0x10 -j NFQUEUE --queue-num ${toString divertPort}
        iptables -t raw -I PREROUTING -j nixos-tcpcrypt

        iptables -t mangle -N nixos-tcpcrypt
        iptables -t mangle -A nixos-tcpcrypt -p tcp -m mark --mark 0x0/0x10 -j NFQUEUE --queue-num ${toString divertPort}
        iptables -t mangle -I POSTROUTING -j nixos-tcpcrypt
      '';

      script = ''
        tcpcryptd -x 0x10 -p ${toString divertPort} -u ${ctrlSocket} -U tcpcryptd -J ${runtimeDir}
      '';

      postStop = ''
        if [ -f /run/pre-tcpcrypt-ecn-state ]; then
          sysctl -w net.ipv4.tcp_ecn=$(< /run/pre-tcpcrypt-ecn-state)
        fi

        rm -rf ${runtimeDir}

        iptables -t mangle -D POSTROUTING -j nixos-tcpcrypt || true
        iptables -t raw -D PREROUTING -j nixos-tcpcrypt || true

        iptables -t raw -F nixos-tcpcrypt || true
        iptables -t raw -X nixos-tcpcrypt || true

        iptables -t mangle -F nixos-tcpcrypt || true
        iptables -t mangle -X nixos-tcpcrypt || true
      '';

      serviceConfig.CapabilityBoundingSet = "CAP_CHOWN CAP_NET_ADMIN CAP_SETUID CAP_SYS_CHROOT"
        + optionalString (divertPort < 1024) "CAP_NET_BIND_SERVICE";
    };
  };

}

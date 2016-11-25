{ config, lib, pkgs, ... }:
with lib;

let
  grPasswd = ./grsec/pw;
  grLearn = ./grsec/learn_config;
  grPolicy = pkgs.writeText "policy" ''
role admin sA
subject / rkva {
  / rwxcldmix
}

role default G
role_transitions admin
subject / {
  / r

  /lost+found h

  # Protect RBAC system
  /dev/grsec h
  /etc/grsec h

  # Protect static boot files
  /boot h
  /run/current-system/kernel-modules h
  /run/current-system/kernel h
  /run/current-system/initrd h

  /dev/port h
  /dev/mem h
  /dev/kmem h

  /dev h
  /dev/zero rw
  /dev/null rw
  /dev/urandom r
  /dev/tty? rw
  /dev/dri
  /dev/snd

  /proc rw
  /proc/sys r

  /proc/kallsyms h
  /proc/kcore h
  /proc/modules h
  /proc/slabinfo h
  /proc/vmallocinfo h
  /proc/ioports
  /proc/iomem

  /sys h
  /sys/* r # */
  /sys/fs/cgroup rwcd
  /sys/module r
  /sys/module/*/sections # */

  /etc r
  /etc/shadow
  /etc/ssh h
  /etc/tarsnap h

  /run r

  /run/keys h

  /home
  /home/* h # */
  /run/user
  /run/user/* h # */

  /tmp rwcdl
  /var/tmp rwcdl
  /dev/shm rwcdl

  /run/nscd/socket rw
  ${config.environment.etc."nsswitch.conf".source}

  /nix/store h
  /nix/store/*/bin rx  # */
  /nix/store/*/lib rx  # */
  /nix/store/*/share r # */
  /run/setuid-wrapper-dirs rx
  /run/current-system

  /var/lib/systemd
  /var/lib/systemd/* h # */

  -CAP_KILL
  -CAP_LINUX_IMMUTABLE
  -CAP_MKNOD
  -CAP_NET_ADMIN
  -CAP_NET_BIND_SERVICE
  -CAP_NET_RAW
  -CAP_SETFCAP
  -CAP_SETPCAP
  -CAP_SYSLOG
  -CAP_SYS_ADMIN
  -CAP_SYS_BOOT
  -CAP_SYS_MODULE
  -CAP_SYS_PTRACE
  -CAP_SYS_RAWIO
  -CAP_SYS_TIME
  -CAP_SYS_TTY_CONFIG
}

subject ${config.systemd.package} o {
  / h

  /dev
  /dev/urandom r
  /dev/zero rw
  /dev/null rw
  /dev/tty? rw
  /dev/grsec h
  /dev/port h
  /dev/mem h

  /etc r
  /etc/ssh h
  /etc/tarsnap h
  /etc/shadow

  /proc rw
  /proc/kcore h
  /sys rw
  /sys/fs/cgroup rwcd

  /run r
  /run/dbus rw
  /run/systemd rwcd
  /run/udev rwcd

  /var/log rwcd
  /var/lib/systemd rwcd

  ${config.systemd.package}/bin rxi
  /nix/store h
  /nix/store/*/bin rx  # */
  /nix/store/*/lib rx  # */
  /nix/store/*/share r # */
  /run/setuid-wrapper-dirs rx

  -CAP_ALL
  +CAP_DAC_OVERRIDE
  +CAP_WAKE_ALARM
  +CAP_KILL
  +CAP_MKNOD
  +CAP_NET_ADMIN
  +CAP_SYS_ADMIN
  +CAP_SYS_PTRACE
  +CAP_SYS_TIME
  +CAP_SYS_TTY_CONFIG
  +CAP_AUDIT_WRITE
}

subject ${config.nix.package}/bin/nix-daemon o {
  / h

  /etc/nix r

  /dev
  /dev/mem h
  /dev/port h

  /proc r
  /proc/kcore h

  /sys r

  /nix/var/nix rwcdl
  /nix/store rwcdl

  /nix/store/*/bin rx # */
  /nix/store/*/lib rx # */

  /var/tmp rwcdl
  /tmp rwcdl
  /dev/shm rwcdl

  -CAP_ALL
}

role nixbld g
subject / {
  / h
  -CAP_ALL
  bind disabled
  connect disabled
}
  '';
in

{
  i18n.consoleKeyMap = "no-latin1";

  security.apparmor.enable = false;
  boot.kernelParams = [ "apparmor=0" ];
  security.grsecurity.enable = true;

  users.mutableUsers = false;

  users.users.root.password = "pass";

  users.users.gray = {
    password = "pass";
    isNormalUser = true;
    group = "wheel";
  };

  systemd.services."grsec" = {
    after = [ "multi-user.target" ];
    wantedBy = [ "multi-user.target" ];

    script = ''
      mkdir -pv /etc/grsec
      chmod -c 700 /etc/grsec

      cp -v ${grPasswd} /etc/grsec/pw
      chmod 600 /etc/grsec/pw

      cp -v ${grLearn} /etc/grsec/learn_config
      chmod 600 /etc/grsec/learn_config

      cp -v ${grPolicy} /etc/grsec/policy
      chmod 600 /etc/grsec/policy

      ${pkgs.gradm}/bin/gradm -C
      #${pkgs.gradm}/bin/gradm -E
    '';
  };
}

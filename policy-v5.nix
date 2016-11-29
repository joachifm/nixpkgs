{ config, lib, pkgs, ... }:
with lib;

''
define tty_user {
  /dev/tty rw
  /dev/console rw

  /dev/pts
  /dev/tty?
  /dev/tty[0-9]*
}

define pam_auth {
  /nix/store/*/lib/security/pam_filter/* x # */
  /nix/store/*/lib/security/pam_*.so rx    # */
}

define setuid_wrappers {
  /var/setuid-wrappers
  /run/setuid-wrapper-dirs
  /run/setuid-wrapper-dirs/* x # */
}

define system {
  /

  /home
  /home/* h # */
  /run/user
  /run/user/* h # */

  # Protect static boot files
  /boot h
  ${config.system.build.kernel}
  ${config.system.build.initialRamdisk}

  # Limit kernel information leaks
  /dev/kmem h
  /proc/modules h
  /proc/slabinfo h

  /dev/mem h
  /dev/port h
  /proc/kcore h

  # Protect RBAC
  /dev/grsec h
  /etc/grsec h

  # Protect grsecurity/PaX tunables
  /proc/sys/kernel/pax h
  /proc/sys/kernel/grsecurity h

  /dev/zero rw
  /dev/full rw
  /dev/null rw
  /dev/urandom r

  /nix/store
  /nix/store/*/bin/* x # */
  /nix/store/*/lib/*.so* rx # */
  /nix/store/*/share r # */
  ${glibcLocales}/lib/locale/locale-archive r
  ${tzdata}/share/zoneinfo r

  /run/current-system

  # Problematic capabilities
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

  bind disabled
  connect disabled
}

role admin sA
  subject / rkva
    / rwcdmlxi

role root uG
  role_transitions admin shutdown

  subject /
    /
    -CAP_ALL
    bind disabled
    connect disabled

  subject ${config.systemd.package}/lib/systemd o
    / h
    -CAP_ALL
    bind disabled
    connect disabled

  subject ${config.systemd.package}/lib/systemd-journald o
    / h
    -CAP_ALL
    bind disabled
    connect disabled

  subject ${config.systemd.package}/lib/systemd-udevd o
    / h
    -CAP_ALL
    bind disabled
    connect disabled

  subject ${config.nix.package}/bin/nix-daemon o
    / h
    -CAP_ALL
    bind disabled
    connect disabled

role nixbld g
  subject /
    / h
    -CAP_ALL
    bind disabled
    connect disabled
''

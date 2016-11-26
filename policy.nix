{ config, pkgs, lib }: pkgs.writeText "policy" ''

role admin sA
subject / rkva {
  / rwxcldmix
}

role messagebus u
subject / {
  / h
  /run/systemd/seats
  /run/systemd/users r
  -CAP_ALL
  bind disabled
  connect disabled
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
  ${config.system.build.kernel} h
  ${config.system.build.initialRamdisk} h
  /proc/kallsyms h
  /proc/modules h
  /proc/slabinfo h
  /proc/vmallocinfo h
  /dev/kmem h

  /dev/port h
  /dev/mem h
  /proc/kcore h
  /proc/bus h

  /dev h
  /dev/zero rw
  /dev/null rw
  /dev/urandom r

  /dev/tty rw
  /dev/tty? rw

  /proc rw
  /proc/sys r

  /sys h

  /etc r
  /etc/shadow
  /etc/passwd
  /etc/group
  /etc/ssh h
  /etc/tarsnap h

  /run r
  /run/keys h

  /home
  /home/* h # */
  /run/user
  /run/user/* h # */

  /dev/shm rwcdl
  /tmp rwcdl
  /var/tmp rwcdl

  /run/nscd/socket rw

  /nix/store h
  /nix/store/* rx # */

  /nix/var/nix
  /nix/var/nix/* h # */
  /nix/var/nix/daemon-socket/socket rw
  /nix/var/nix/profiles r
  /nix/var/nix/gcroots r
  /nix/var/nix/temproots r
  /nix/var/log h

  /run/setuid-wrapper-dirs
  /run/setuid-wrapper-dirs/*/* rxi # */

  /var/lib/systemd h

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

subject /var/setuid-wrappers/ping o {
  / h
  /nix/store h
  /nix/store/*/lib/* rx # */
  -CAP_ALL
}

subject ${pkgs.iputils}/bin/ping o {
  / h

  /etc/resolv.conf r
  /run/nscd/socket rw

  /nix/store h
  /nix/store/*/lib/* rx # */
  /nix/store/*/share/* r # */

  -CAP_ALL
  +CAP_NET_RAW
}

subject ${pkgs.procps}/bin/ps o {
  / h

  /nix/store h
  /nix/store/*/lib/* rx # */
  /nix/store/*/share/* r # */

  /run/nscd/socket rw
  ${config.environment.etc."nsswitch.conf".source} r

  /dev h
  /dev/zero rw
  /dev/null rw
  /dev/urandom r
  /dev/tty? r
  /dev/pts r

  /proc r
  /proc/bus h
  /proc/kcore h
  /proc/modules h
  /proc/kallsyms h
  /sys/devices/system/cpu r

  -CAP_ALL
  bind disabled
  connect disabled
}

subject ${config.systemd.package} o {
  / h

  /dev

  /dev/urandom r
  /dev/zero rw
  /dev/null rw

  /dev/tty? rw

  /dev/grsec h
  /etc/grsec h

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
  /run/utmp rw

  /var/lib/systemd rwcd
  /var/log/journal rwcd

  /var/log/lastlog rw
  /var/log/wtmp rw

  /nix/store rx
  /run/setuid-wrapper-dirs rx

  -CAP_ALL
  +CAP_AUDIT_WRITE
  +CAP_DAC_OVERRIDE
  +CAP_KILL
  +CAP_MKNOD
  +CAP_NET_ADMIN
  +CAP_SYS_ADMIN
  +CAP_SYS_PTRACE
  +CAP_SYS_RESOURCE
  +CAP_SYS_TIME
  +CAP_SYS_TTY_CONFIG
  +CAP_WAKE_ALARM
}

subject ${pkgs.utillinux}/bin/agetty o {
  / h
  -CAP_ALL
  bind disabled
  connect disabled
}

subject ${pkgs.shadow}/bin/login o {
  / h
  -CAP_ALL
  bind disabled
  connect disabled
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

  /dev/shm rwcdl
  /tmp rwcdl
  /var/tmp rwcdl

  -CAP_ALL
}

role nixbld g
subject / {
  / h
  -CAP_ALL
  bind disabled
  connect disabled
}

''

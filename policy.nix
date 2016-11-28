{ config, pkgs, lib }: with lib; pkgs.writeText "policy" ''
define all_denied {
  / h
  -CAP_ALL
  bind disabled
  connect disabled
}

role admin sA
subject / rkva {
  / rwxcldmix
}

role messagebus u
subject / {
  $all_denied
  ${getBin pkgs.dbus}/bin/dbus-daemon x
}

# role: messagebus
subject ${getBin pkgs.dbus}/bin/dbus-daemon o {
  $all_denied

  /proc
  /proc/[0-9]*/* r # */

  /run/dbus
  /run/systemd/seats
  /run/systemd/users r

  /nix/store h
  /nix/store/*/lib/*.so* # */
  # Note: could be even more specific by generating rules for dbus.packages
  /nix/store/*/etc/dbus-1 r # */
  /nix/store/*/share/dbus-1 r # */
}

role nscd u
subject / {
  $all_denied
  ${pkgs.glibc.bin}/bin/nscd x
}

# role: nscd
subject ${pkgs.glibc.bin}/bin/nscd o {
  / h

  ${config.environment.etc."host.conf".source} r
  /etc/resolv.conf r

  ${config.environment.etc."hosts".source} r
  /etc/group r
  /etc/passwd r
  /etc/shadow

  /proc r
  /proc/kcore h

  /run h
  /run/nscd rwcd

  /nix/store h
  /nix/store/*-nscd.conf r # */
  /nix/store/*/lib/*.so* rx # */

  -CAP_ALL
}

role default G
role_transitions admin
subject / {
  / r

  /lost+found h

  # Protect RBAC system
  /dev/grsec h
  /etc/grsec h

  # Protect grsecurity/PaX tunables
  /proc/sys/kernel/grsecurity h
  /proc/sys/kernel/pax h

  # Protect static boot files
  /boot hs
  ${config.system.build.kernel} hs
  ${config.system.build.initialRamdisk} hs

  # Limit kernel information leaks
  /dev/kmem h
  /proc/kallsyms h
  /proc/modules h
  /proc/slabinfo h
  /proc/vmallocinfo h

  # Protect OS runtime
  /dev/mem h
  /dev/port h
  /proc/bus h
  /proc/kcore h

  /dev h
  /dev/full rw
  /dev/null rw
  /dev/zero rw
  /dev/urandom r

  /dev/tty rw
  /dev/console rw

  /proc r
  /proc/sys/kernel/ngroups_max r
  /proc/sys/kernel/pid_max r

  /sys h
  /sys/devices/system/cpu r

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

  -CAP_ALL

  bind disabled
  connect 0.0.0.0/32:0 dgram stream icmp tcp udp
}

subject /var/setuid-wrappers/ping o {
  / h
  /nix/store h
  /nix/store/*/lib/*.so* rx # */
  -CAP_ALL
  bind disabled
  connect disabled
}

subject ${pkgs.iputils}/bin/ping o {
  / h

  /etc/resolv.conf r
  /run/nscd/socket rw

  /nix/store h
  /nix/store/*/lib/*.so* rx # */
  /nix/store/*/share/* r # */

  -CAP_ALL
  +CAP_NET_RAW
}

# role: root
subject ${pkgs.su}/bin/su o {
  / h

  /etc/login.defs r
  /etc/pam.d r

  /etc/group r
  /etc/passwd r
  /etc/shadow r

  /proc h
  /proc/[0-9]*/loginuid r
  /proc/[0-9]*/fd rw

  /proc/sys/kernel/ngroups_max r
  /proc/sys/kernel/pid_max r

  /run/nscd/socket rw
  /run/systemd/journal/dev-log rw
  /run/utmp rw

  /nix/store h
  /nix/store/* rx # */

  -CAP_ALL
  +CAP_CHOWN
  +CAP_SETGID
  +CAP_SETUID

  bind disabled
  connect disabled
}

# role: root
subject ${pkgs.utillinux}/bin/agetty o {
  / h

  /dev h
  /dev/null rw
  /dev/tty? rw

  /nix/store h
  /nix/store/* rx # */

  /run h
  /run/agetty.reload rwcd
  /run/nscd/socket rw

  /var h
  /var/log/wtmp w

  -CAP_ALL
  +CAP_CHOWN
  +CAP_DAC_OVERRIDE
  +CAP_FSETID
  +CAP_SYS_ADMIN
  +CAP_SYS_TTY_CONFIG

  bind disabled
  connect disabled
}

# role: root
subject ${pkgs.shadow}/bin/login o {
  / h

  /dev h
  /dev/tty? rw

  /etc h
  /etc/pam.d r
  /etc/shadow r

  /nix/store h
  /nix/store/* rxi # */

  /proc rw
  /proc/sys r
  /proc/kcore h
  /proc/bus h
  /proc/kallsyms h
  /proc/modules h
  /proc/slabinfo h
  /proc/vmallocinfo h

  /run h
  /run/dbus h
  /run/dbus/system_bus_socket rw
  /run/nscd h
  /run/nscd/socket rw
  /run/systemd h
  /run/systemd/seats
  /run/systemd/journal/dev-log rw
  /run/utmp rw

  /var h
  /var/log/lastlog rw
  /var/log/wtmp w

  -CAP_ALL
  +CAP_CHOWN
  +CAP_FOWNER
  +CAP_FSETID
  +CAP_NET_ADMIN
  +CAP_SETGID
  +CAP_SETUID

  bind disabled
  connect disabled
}

subject ${config.systemd.package} o {
  / h

  /dev

  /dev/urandom r
  /dev/full rw
  /dev/null rw
  /dev/zero rw

  /dev/console rw
  /dev/tty rw
  /dev/tty? rw

  /dev/grsec h
  /etc/grsec h

  /dev/port h
  /dev/mem h

  /etc r
  /etc/shadow
  /etc/ssh h
  /etc/tarsnap h

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

  /nix/store h
  /nix/store/* rx # */

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
''

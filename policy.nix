{ config, pkgs, lib }:
with lib;

''
define all_denied {
  / h
  -CAP_ALL
  bind disabled
  connect disabled
}

role admin sA
subject / rkva {
  / rwcdmlxi
}

role shutdown sARG
subject / rvka {
  /
  /dev
  /dev/urandom r
  /etc r
  /nix/store h
  /nix/store/* rx # */

  /proc r
  /proc/kcore h

  /dev/grsec h
  /dev/mem h
  /dev/port h

  -CAP_ALL
  bind disabled
  connect disabled
}

role messagebus u
subject / {
  $all_denied
}

# role: messagebus
subject ${getBin pkgs.dbus}/bin/dbus-daemon o {
  $all_denied

  /proc
  /proc/[0-9]*/* r # */

  /run/dbus

  /run/nscd h
  /run/nscd/socket rw

  /run/systemd h
  /run/systemd/journal/dev-log rw
  /run/systemd/seats
  /run/systemd/users r

  /nix/store h
  /nix/store/* # */
}

role polkituser u
subject / {
  $all_denied
}

# role: polkituser
subject ${pkgs.polkit.out}/lib/polkit-1/polkitd o {
  / h

  /dev h
  /dev/urandom r

  /etc h
  /etc/polkit-1/rules.d

  /nix/store h
  /nix/store/* rx # */

  /proc r

  /run h
  /run/dbus h
  /run/dbus/system_bus_socket rw

  /run/systemd
  /run/systemd/journal h
  /run/systemd/journal/dev-log rw

  /sys h
  /sys/devices/system/cpu/online r

  /var h
  /var/empty

  -CAP_ALL
  +CAP_SETUID

  bind disabled
  connect disabled
}

role nscd u
subject / {
  $all_denied
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
  /nix/store/* rx # */

  -CAP_ALL
}

role default G
role_transitions admin shutdown
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

  /root r
  /run/user/0 r

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

subject ${config.systemd.package} o {
  /

  /boot hs
  ${config.system.build.kernel} hs
  ${config.system.build.initialRamdisk} hs

  /dev/urandom r
  /dev/full rw
  /dev/null rw
  /dev/zero rw

  /dev
  /dev/console rw
  /dev/tty rw
  /dev/tty[0-9]* rw

  /dev/grsec h
  /etc/grsec h

  /dev/mem h
  /dev/port h

  /etc r
  /etc/ssh h
  /etc/tarsnap h

  /proc rw
  /proc/kcore h
  /proc/sys r
  /sys r
  /sys/fs/cgroup rwcd

  /run rwcdl
  /var/lib/systemd rwcd
  /var/log rwcd

  /nix/store h
  /nix/store/* rx # */

  /run/setuid-wrapper-dirs rx

  -CAP_ALL
  +CAP_AUDIT_WRITE
  +CAP_CHOWN
  +CAP_DAC_OVERRIDE
  +CAP_FOWNER
  +CAP_KILL
  +CAP_MKNOD
  +CAP_NET_ADMIN
  +CAP_SETGID
  +CAP_SETUID
  +CAP_SYS_ADMIN
  +CAP_SYS_CHROOT
  +CAP_SYS_PTRACE
  +CAP_SYS_RESOURCE
  +CAP_SYS_TIME
  +CAP_SYS_TTY_CONFIG
  +CAP_WAKE_ALARM
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

  /dev h
  /dev/tty[0-9]*

  /home
  /root

  /etc/login.defs r
  /etc/pam.d r
  /etc/shells r

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
  /run/utmp r

  /var/log/faillog rwc

  /nix/store h
  /nix/store/* rx # */

  -CAP_ALL
  +CAP_SETGID
  +CAP_SETUID
  +CAP_DAC_READ_SEARCH

  bind disabled
  connect disabled
}

# role: root
subject ${pkgs.utillinux}/bin/agetty o {
  /

  /dev h
  /dev/null rw
  /dev/tty[0-9]* rw

  /nix/store h
  /nix/store/* rx # */

  /run h
  /run/agetty.reload rwcd
  /run/nscd/socket rw
  /run/utmp rw

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

  /root r
  /home r

  /dev h
  /dev/tty[0-9]* rw

  /etc h
  /etc/pam.d r
  /etc/shadow r

  /nix/store h
  /nix/store/* rx # */

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

role gray u
subject / {
  /

  /boot hs
  ${config.system.build.kernel} hs
  ${config.system.build.initialRamdisk} hs

  /root

  /dev h
  /dev/null rw
  /dev/zero rw
  /dev/full rw
  /dev/urandom r

  /dev/console rw
  /dev/tty rw
  /dev/tty[0-9]*

  /etc r
  /etc/grsec h
  /etc/ssh h

  /etc/nix h
  /etc/nix/nix.conf r
  /etc/nixos h

  /etc/openvpn h
  /etc/samba h
  /etc/tarsnap h

  /proc/kcore h
  /proc/modules h
  /proc/slabinfo h
  /proc/kallsyms h

  /proc/bus h
  /proc/acpi h
  /proc/asound h

  /proc
  /proc/[0-9]*/ r
  /proc/self

  /proc/cpuinfo r
  /proc/filesystems r
  /proc/loadavg r
  /proc/meminfo r
  /proc/stat r
  /proc/uptime r
  /proc/tty/drivers r
  /proc/sys h
  /proc/sys/kernel/domainname r
  /proc/sys/kernel/hostname r
  /proc/sys/kernel/ngroups_max r
  /proc/sys/kernel/osrelease r
  /proc/sys/kernel/pid_max r
  /proc/sys/kernel/random/boot_id r
  /proc/sys/kernel/version r

  /sys h
  /sys/devices/system/cpu/online r

  /run
  /run/user rwcdl
  /run/nscd/socket rw
  /run/dbus/system_bus_socket rw
  /run/utmp r

  /var
  /var/empty
  /var/cache/fontconfig r
  /var/cache/man r
  /var/log h
  /var/log/journal r

  /dev/shm rwcdl
  /tmp rwcdl
  /var/tmp rwcdl

  /nix/store h
  /nix/store/* rx # */

  /nix/var/nix
  /nix/var/nix/* h # */
  /nix/var/nix/daemon-socket/socket rw
  /nix/var/nix/profiles r
  /nix/var/nix/profiles/per-user rwcdl
  /nix/var/nix/gcroots r
  /nix/var/nix/gcroots/tmp rwcdl
  /nix/var/nix/gcroots/per-user rwcdl
  /nix/var/nix/temproots r
  /nix/var/log h

  /run/setuid-wrapper-dirs rx

  /home/gray rwcdl
  /home/gray/.gnupg h
  /home/gray/.ssh h
  /home/gray/.pki h
  /home/gray/.mozilla h

  -CAP_ALL
}
''

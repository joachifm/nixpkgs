{ config, lib, pkgs, ... }:
with lib;

''
define all_denied {
  / h
  -CAP_ALL
  bind disabled
  connect disabled
}

role admin sA
  subject / rvka
    / rwcdlmxi

role nscd u
  subject /
    $all_denied

  subject ${getBin pkgs.glibc}/bin/nscd dpo
    / h

    /etc
    /etc/resolv.conf r
    /etc/passwd r
    /etc/group r
    /etc/shadow

    /run
    /run/nscd rwcd

    /run/systemd/journal/dev-log rw

    /var
    /var/db/nscd rwcd
    /var/run/nscd rwcd

    /proc
    /proc/[0-9]*/maps r
    /proc/sys/vm/overcommit_memory r

    /nix/store h
    /nix/store/* rx # */

    -CAP_ALL

    bind disabled
    ${if (length config.networking.nameservers > 0)
      then concatMapStringsSep "\n" (x: "connect ${x}/32:53 dgram udp")
             config.networking.nameservers
      else "connect disabled"}

    sock_allow_family unix ipv4 ipv6

role messagebus u
  subject /
    $all_denied

  subject ${getBin pkgs.dbus}/bin/dbus-daemon dpo
    $all_denied

    /proc
    /proc/[0-9]*/* r # */

    /run/dbus
    /run/dbus/system_bus_socket rw

    /run/nscd h
    /run/nscd/socket rw

    /run/systemd h
    /run/systemd/journal/dev-log rw
    /run/systemd/seats
    /run/systemd/users r

    /nix/store h
    /nix/store/* # */

role default G
  role_transitions admin

  subject /
    /
    /dev

    ## Always "safe" special devices
    /dev/urandom r
    /dev/full rw
    /dev/null rw
    /dev/zero rw

    ## Access to real-time clock
    /dev/rtc? r

    ## Allow tty access to applications attached to the controlling terminal
    /dev/console rw
    /dev/tty rw

    ## Protect static boot files
    /boot hs
    ${config.system.build.kernel} hs
    ${config.system.build.initialRamdisk} hs

    ## Limit kernel information leaks
    /dev/kmem h
    /proc/modules h
    /proc/slabinfo h
    /proc/kallsyms h

    ## Protect RBAC
    /dev/grsec h
    /etc/grsec h

    ## Protect grsecurity/PaX runtime
    /proc/sys/kernel/grsecurity h
    /proc/sys/kernel/pax h

    ## Hide problematic device nodes
    /dev/mem h
    /dev/port h

    ## Limit access to OS runtime tunables
    /proc
    /proc/[0-9]* r
    /proc/kcore h
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
    /proc/sys/vm/overcommit_memory r

    /sys h
    /sys/devices/system/cpu/online r

    ## Configuration files
    /etc r
    /etc/samba h
    /etc/ssh h
    /etc/tarsnap h
    /etc/shadow

    ## Runtime state
    /run
    /run/nscd/socket rw
    /run/dbus/system_bus_socket rw
    /run/utmp r

    ## Persistent tate
    /var
    /var/cache/fontconfig r
    /var/cache/man r
    /var/log/journal r

    ## Global writable storage
    /dev/shm rwcdl
    /tmp rwcdl
    /var/tmp rwcdl

    ## Nix store privacy: limit access to known store paths
    /nix/store h
    /nix/store/* rx # */

    /nix/var/nix
    /nix/var/nix/daemon-socket/socket rw
    /nix/var/nix/profiles r
    /nix/var/nix/profiles/per-user rwcdl
    /nix/var/nix/gcroots r
    /nix/var/nix/gcroots/tmp rwcdl
    /nix/var/nix/gcroots/per-user rwcdl
    /nix/var/nix/temproots r

    /run/setuid-wrapper-dirs
    /run/setuid-wrapper-dirs/*/* rx # */

    ## Drop problematic capabilities
    -CAP_MKNOD
    -CAP_NET_ADMIN
    -CAP_NET_BIND_SERVICE
    -CAP_SETFCAP
    -CAP_SYSLOG
    -CAP_SYS_ADMIN
    -CAP_SYS_BOOT
    -CAP_SYS_MODULE
    -CAP_SYS_RAWIO
    -CAP_SYS_TTY_CONFIG

    sock_allow_family unix ipv4 ipv6

  # TODO: limit this!
  subject ${config.systemd.package}/lib/systemd/systemd dpo
    / rwcdx

    +CAP_ALL

    bind disabled
    connect disabled

  subject ${config.systemd.package}/lib/systemd/systemd-journald dpo
    / h

    /dev/log rw
    /dev/kmsg rw

    /run/systemd
    /run/systemd/journal rwcd
    /run/systemd/journal/dev-log rw

    /proc
    /proc/[0-9]* r

    /var/log h
    /var/log/journal rwcd

    /nix/store h
    /nix/store/* # */

    # Grant capabilities declared by upstream service unit
    -CAP_ALL
    +CAP_SYS_ADMIN
    +CAP_DAC_OVERRIDE
    +CAP_SYS_PTRACE
    +CAP_SYSLOG
    +CAP_AUDIT_CONTROL
    +CAP_AUDIT_READ
    +CAP_CHOWN
    +CAP_DAC_READ_SEARCH
    +CAP_FOWNER
    +CAP_SETUID
    +CAP_SETGID
    +CAP_MAC_OVERRIDE

    bind disabled
    connect disabled

  # TODO: limit me
  subject ${config.systemd.package}/lib/systemd/systemd-udevd dpo
    / h

    /dev cdl

    /proc h
    /proc/[0-9]*/oom_score_adj rw
    /proc/sys r

    /sys
    /sys/fs/cgroup r
    # TODO: restrict to uevent subpaths
    /sys/bus r
    /sys/devices r
    /sys/module
    /sys/module/*/uevent r # */

    /etc/modprobe.d r

    /run h
    /run/nscd/socket rw
    /run/systemd r
    /run/systemd/notify rw
    /run/udev rwcd

    /nix/store h
    /nix/store/* # */

    -CAP_ALL
    +CAP_MKNOD
    +CAP_WAKE_ALARM
    # TODO: why?
    +CAP_NET_ADMIN

    bind disabled
    connect disabled
    sock_allow_family netlink

  subject ${config.systemd.package}/lib/systemd/systemd-logind dpo
    / h

    /dev
    /dev/tty[0-9]* rw

    /proc
    /proc/[0-9]*/cgroup r
    /proc/[0-9]*/sessionid r
    /proc/kcore h
    /proc/modules h
    /proc/kallsyms h
    /proc/slabinfo h

    /sys
    # TODO: restrict to uevent
    /sys/devices r

    /root
    /home

    /run/udev
    /run/udev/*/uacess r # */
    /run/udev/data r

    /run/systemd
    /run/systemd/notify rw
    /run/systemd/seats rwcd
    /run/systemd/sessions rwcd
    /run/systemd/users rwcd

    /nix/store h
    /nix/store/* # */

    # Grant capabilities declared by upstream service unit
    -CAP_ALL
    +CAP_SYS_ADMIN
    +CAP_MAC_ADMIN
    +CAP_AUDIT_CONTROL
    +CAP_CHOWN
    +CAP_KILL
    +CAP_DAC_READ_SEARCH
    +CAP_DAC_OVERRIDE
    +CAP_FOWNER
    +CAP_SYS_TTY_CONFIG

    bind disabled
    connect disabled

  subject ${config.systemd.package}/lib/systemd/systemd-timesyncd dpo
    / h

    /run/systemd
    /run/systemd/notify rw

    # Grant capabilities declared by upstream service unit
    -CAP_ALL
    +CAP_SYS_TIME
    +CAP_SETUID
    +CAP_SETGID
    +CAP_SETPCAP
    +CAP_CHOWN
    +CAP_DAC_OVERRIDE
    +CAP_FOWNER

    bind disabled
    connect 0.0.0.0/32:123 stream dgram tcp udp

  subject ${config.systemd.package}/lib/systemd/systemd-timedated dpo
    / h

    # Grant capabilities declared by upstream service unit
    -CAP_ALL
    +CAP_SYS_TIME

    bind disabled
    connect disabled

  subject ${config.systemd.package}/lib/systemd/systemd-networkd dpo
    / h

    /run/systemd
    /run/systemd/notify rw

    # Grant capabilities declared by upstream service unit
    -CAP_ALL
    +CAP_NET_ADMIN
    +CAP_NET_BIND_SERVICE
    +CAP_NET_BROADCAST
    +CAP_NET_RAW
    +CAP_SETUID
    +CAP_SETGID
    +CAP_SETPCAP
    +CAP_CHOWN
    +CAP_DAC_OVERRIDE
    +CAP_FOWNER

    bind disabled
    connect disabled

  subject ${config.systemd.package}/lib/systemd/systemd-resolved dpo
    / h

    /run/systemd
    /run/systemd/notify rw

    # Grant capabilities declared by upstream service unit
    -CAP_ALL
    +CAP_SETUID
    +CAP_SETGID
    +CAP_SETPCAP
    +CAP_CHOWN
    +CAP_DAC_OVERRIDE
    +CAP_FOWNER
    +CAP_NET_RAW
    +CAP_NET_BIND_SERVICE

    bind disabled
    connect disabled

  subject ${pkgs.dhcpcd}/bin/dhcpcd dpo
    / h

    /etc
    /etc/dhcpcd.duid rwcd
    /etc/grsec h
    /etc/openvpn h
    /etc/samba h
    /etc/ssh h
    /etc/tarsnap h

    /proc h
    /proc/[0-9]*/net r

    -CAP_ALL
    +CAP_NET_ADMIN

    bind disabled
    connect 0.0.0.0/32:68 stream dgram tcp udp

  subject ${pkgs.su}/bin/su o
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

    /run/nscd h
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

  subject ${pkgs.shadow}/bin/login o
    / h

    /root r
    /home r

    /dev
    /dev/tty[0-9]* rw
    /dev/pts

    /etc h
    /etc/pam.d r
    /etc/shadow r

    /nix/store h
    /nix/store/* rx # */

    /proc h
    /proc/self
    /proc/[0-9]*/fd r
    /proc/[0-9]*/loginuid rw
    /proc/[0-9]*/uid_map r
    /proc/[0-9]*/gid_map r

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

  subject ${pkgs.utillinux}/bin/agetty o
    / h

    /dev h
    /dev/null rw
    /dev/tty[0-9]* rw

    /etc/group r
    /etc/passwd r

    /run h
    /run/agetty.reload rwcd
    /run/nscd/socket rw
    /run/utmp rw

    /var h
    /var/log/wtmp w

    /nix/store h
    /nix/store/* rx # */

    -CAP_ALL
    +CAP_CHOWN
    +CAP_DAC_OVERRIDE
    +CAP_FSETID
    +CAP_SYS_ADMIN
    +CAP_SYS_TTY_CONFIG

    bind disabled
    connect disabled

  subject ${config.nix.package}/bin/nix-daemon dpo
    / h
    -CAP_ALL
    bind disabled
    connect disabled

role nixbld g
  subject /
    / h

    # Avoid having to patch builds that fail due to PaX violations
    -PAX_MPROTECT
    -PAX_RANDMMAP

    -CAP_ALL
    bind disabled
    connect disabled
''

  system.activationScripts.apparmor = ''
    mkdir -p /etc/apparmor.d/

    mkdir -p /etc/apparmor.d/nixos/tunables
    cat >/etc/apparmor.d/nixos/tunables/global <<EOF
    #include <tunables/global>
    EOF
    mkdir -p /etc/apparmor.d/nixos/abstractions
    cat >/etc/apparmor.d/nixos/abstractions/base <<EOF
    #include <abstractions/base>
    /nix/store/** r,
    /nix/store/*/lib/*.so mr,
    /nix/store/*/bin/* ixr, # */
    EOF
    cat >/etc/apparmor.d/nixos/abstractions/bash <<EOF
    #include <abstractions/bash>
    /nix/store/*/bin/ls mix,
    EOF
    cat >/etc/apparmor.d/nixos/abstractions/authentication <<EOF
    #include <abstractions/authentication>
    /nix/store/*/lib/security/pam_filter/* mr,
    /nix/store/*/lib/security/pam_*.so mr,
    /nix/store/*/lib/security/ r, # */
    EOF
    cat >/etc/apparmor.d/nixos/abstractions/nameservice <<EOF
    #include <abstractions/nameservice>
    EOF

    cat >/etc/apparmor.d/pam_binaries <<EOF
    #include <nixos/tunables/global>

    /var/setuid-wrappers/su {
      #include <nixos/abstractions/authentication>
      #include <nixos/abstractions/base>
      #include <nixos/abstractions/nameservice>

      #include <pam/mappings>

      capability chown,
      capability setgid,
      capability setuid,

      owner /etc/environment r,
      owner /etc/shells r,
      owner /etc/default/locale r,
      owner /home/*/.Xauthority rw,
      owner /home/*/.Xauthority-c w,
      owner /home/*/.Xauthority-l w, # */
      /home/.xauth* rw,
      owner /proc/sys/kernel/ngroups_max r,
      /usr/bin/xauth rix,
      owner /var/run/utmp rwk,
    }
    EOF

    cat >/etc/apparmor.d/pam_roles <<EOF
    #include <nixos/tunables/global>

    profile default_user {
      #include <nixos/abstractions/base>
      #include <nixos/abstractions/bash>
      #include <abstractions/consoles>
      #include <nixos/abstractions/nameservice>

      deny capability sys_ptrace,

      owner /** rkl,
      /proc/** r,

      /run/current-system/sw/bin/** Pixmr,
      owner /home/ w,
      owner /home/** w, # */
    }

    profile confined_user {
      #include <nixos/abstractions/base>
      #include <nixos/abstractions/bash>
      #include <abstractions/consoles>
      #include <nixos/abstractions/nameservice>

      deny capability sys_ptrace,

      owner /** rwkl,
      /proc/** r,

      /run/current-system/sw/bin/** Pixmr,
      owner /home/bin/** ixmr, # */
    }
    EOF

    mkdir -p /etc/apparmor.d/pam
    cat >/etc/apparmor.d/pam/mappings <<EOF
    # This file contains the mappings from users to roles for the
    # binaries confined with AppArmor and configured for use with
    # libpam-apparmor. Users without a mapping will not be able to
    # login.

    # The default hat is a confined user. The hat contains only the
    # permissions necessary to transition to the user's login shell. All
    # other permissions have been moved into the default_user profile.
    ^DEFAULT {
      #include <nixos/abstractions/authentication>
      #include <nixos/abstractions/nameservice>

      capability dac_override,
      capability setgid,
      capability setuid,

      /etc/environment r,
      /run/current-system/sw/bin/{,b,d,rb}ash Px -> default_user,
    }

    # A confined user. The hat contains only the permissions necessary
    # to transition to user's login shell. All other permissions have
    # been moved into the confined_user profile.
    ^gray {
      #include <nixos/abstractions/authentication>
      #include <nixos/abstractions/nameservice>

      capability dac_override,
      capability setgid,
      capability setuid,

      /etc/environment r,
      /run/current-system/sw/bin/{,b,d,rb}ash Px -> confined_user,
    }

    # Unconfined administrator
    ^root {
      #include <nixos/abstractions/authentication>
      #include <nixos/abstractions/nameservice>

      capability dac_override,
      capability setgid,
      capability setuid,

      /etc/environment r,
      /run/current-system/sw/bin/{,b,d,rb}ash Ux,
    }
    EOF

    loadProfiles=/etc/load-apparmor-profiles
    cat >$loadProfiles <<EOF
    #! /bin/sh
    ${pkgs.apparmor-parser}/bin/apparmor_parser -r -T \
      -I ${pkgs.apparmor-profiles}/etc/apparmor.d \
      -W /etc/apparmor.d/pam_binaries /etc/apparmor.d/pam_roles
    EOF
    chmod +x $loadProfiles
  '';

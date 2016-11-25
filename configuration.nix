{ config, lib, pkgs, ... }:

{
  i18n.consoleKeyMap = "no-latin1";

  security.apparmor.enable = true;

  users.mutableUsers = false;

  users.users.root.password = "pass";

  users.users.gray = {
    password = "pass";
    isNormalUser = true;
    group = "wheel";
  };

  security.pam.services.su.enableAppArmor = true;
  security.pam.services.login.enableAppArmor = true;
  security.pam.services.sudo.enableAppArmor = true;

  system.activationScripts.apparmor = ''
    mkdir -p /etc/apparmor.d/

    cat >/etc/apparmor.d/pam_binaries <<EOF
    #include <tunables/global>

    /var/setuid-wrappers/su {
      #include <pam/mappings>
      capability chown,
      capability setgid,
      capability setuid,
      /var/setuid-wrappers/su.real r,
      /run/current-system/sw/lib/*.so mr, # */
      ${pkgs.su}/bin/su mixr,
    }
    EOF

    cat >/etc/apparmor.d/pam_roles <<EOF
    #include <tunables/global>

    profile default_user {
    }

    profile confined_user {
    }
    EOF

    mkdir -p /etc/apparmor.d/pam
    cat >/etc/apparmor.d/pam/mappings <<EOF
    ^DEFAULT {
    }

    ^root {
      capability dac_override,
      capability setgid,
      capability setuid,
      /run/current-system/sw/bin/bash Ux,
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
}

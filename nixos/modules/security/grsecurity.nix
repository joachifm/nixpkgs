{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.security.grsecurity;
  grsecLockPath = "/proc/sys/kernel/grsecurity/grsec_lock";

  # Ascertain whether ZFS is required for booting the system; grsecurity is
  # currently incompatible with ZFS, rendering the system unbootable.
  zfsNeededForBoot = filter
    (fs: (fs.neededForBoot
          || elem fs.mountPoint [ "/" "/nix" "/nix/store" "/var" "/var/log" "/var/lib" "/etc" ])
          && fs.fsType == "zfs")
    config.system.build.fileSystems != [];

  # Ascertain whether NixOS container support is required
  containerSupportRequired =
    config.boot.enableContainers && config.containers != {};

  # An initial policy file.
  initialPolicy = pkgs.substituteAll "policy"
    { inherit (pkgs) nix;
      src = ./grsecurity-nixos-policy.in;
    };

  # A simple minded script for initializing the RBAC setup.  Uses NixOS
  # defaults to get the user going.  The idea is that the user should be
  # able to eventually transition to a policy based on full system
  # learning.
  #
  # Ideally, we'd do all this declaratively, but for now do it the ugly
  # way.
  gradmInitBin = pkgs.writeScriptBin "gradm_init" ''
    #! ${pkgs.stdenv.shell}
    set -e

    # Parameters
    grsecPolicy=/etc/grsec/policy
    grsecPasswd=/etc/grsec/pw

    # Initialize policy file, using NixOS defaults
    if [[ -e "$grsecPolicy" ]] ; then
      echo "$0: existing policy found at $grsecPolicy; refusing to overwrite" >&2
      exit 1
    else
      cat ${initialPolicy} >"$grsecPolicy"
    fi

    # Initialize passwd for default roles
    if [[ -e "$grsecPasswd" ]] ; then
      echo "$0: existing grsec passwd found at $grsecPasswd; refusing to overwrite" >&2
      exit 1
    else
      echo "Set RBAC password"
      gradm -P

      echo "Set password for the admin role"
      gradm -P admin

      echo "Set password for the shutdown role"
      gradm -P shutdown
    fi

    # Check everything at the end
    gradm -C
  '';
in

{
  meta = {
    maintainers = with maintainers; [ joachifm ];
    doc = ./grsecurity.xml;
  };

  options.security.grsecurity = {

    enable = mkEnableOption "grsecurity/PaX";

    lockTunables = mkOption {
      type = types.bool;
      example = false;
      default = true;
      description = ''
        Whether to automatically lock grsecurity tunables
        (<option>boot.kernel.sysctl."kernel.grsecurity.*"</option>).  Disable
        this to allow runtime configuration of grsecurity features.  Activate
        the <literal>grsec-lock</literal> service unit to prevent further
        configuration until the next reboot.
      '';
    };

    disableEfiRuntimeServices = mkOption {
      type = types.bool;
      example = false;
      default = true;
      description = ''
        Whether to disable access to EFI runtime services.  Enabling EFI runtime
        services creates a venue for code injection attacks on the kernel and
        should be disabled if at all possible.  Changing this option enters into
        effect upon reboot.
      '';
    };

    enforcePolicy = mkOption {
      type = types.bool;
      example = true;
      default = false;
      description = ''
        Whether to enforce the grsecurity RBAC policy.  Enabling this
        option implies that all RBAC roles have been properly
        initialized and that a suitable policy in place.  Run the
        <command>gradm_init</command> to initialize RBAC using NixOS
        defaults.
      '';
    };
  };

  config = mkIf cfg.enable {

    # Allow the user to select a different package set, subject to the stated
    # required kernel config
    boot.kernelPackages = mkDefault pkgs.linuxPackages_grsec_nixos;

    boot.kernelParams = optional cfg.disableEfiRuntimeServices "noefi";

    system.requiredKernelConfig = with config.lib.kernelConfig;
      [ (isEnabled "GRKERNSEC")
        (isEnabled "PAX")
        (isYES "GRKERNSEC_SYSCTL")
        (isYES "GRKERNSEC_SYSCTL_DISTRO")
        (isNO "GRKERNSEC_NO_RBAC")
      ];

    nixpkgs.config.grsecurity = true;

    # Install PaX related utillities into the system profile.
    environment.systemPackages = with pkgs; [ gradm paxctl pax-utils gradmInitBin ];

    # Install rules for the grsec device node
    services.udev.packages = [ pkgs.gradm ];

    # This service unit is responsible for locking the grsecurity tunables.  The
    # unit is always defined, but only activated on bootup if lockTunables is
    # toggled.  When lockTunables is toggled, failure to activate the unit will
    # enter emergency mode.  The intent is to make it difficult to silently
    # enter multi-user mode without having locked the tunables.  Some effort is
    # made to ensure that starting the unit is an idempotent operation.
    systemd.services.grsec-lock = {
      description = "Lock grsecurity tunables";

      wantedBy = optional cfg.lockTunables "multi-user.target";

      wants = [ "local-fs.target" "systemd-sysctl.service" ];
      after = [ "local-fs.target" "systemd-sysctl.service" ];
      conflicts = [ "shutdown.target" ];

      restartIfChanged = false;

      script = ''
        if ${pkgs.gnugrep}/bin/grep -Fq 0 ${grsecLockPath} ; then
          echo -n 1 > ${grsecLockPath}
        fi
      '';

      unitConfig = {
        ConditionPathIsReadWrite = grsecLockPath;
        DefaultDependencies = false;
      } // optionalAttrs cfg.lockTunables {
        OnFailure = "emergency.target";
      };

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
    };

    systemd.services.enable-grsec-policy = {
      after = [ "multi-user.target" ];
      wantedBy = [ "multi-user.target" ];

      restartIfChanged = false;

      script = ''
        cat ${cfg.policy} >/etc/grsec/policy
        if [[ -r /etc/grsec/policy ]] ; then
          gradm -C
          gradm -E
        fi
      '';

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };

      # Only run the unit if the user has initialized RBAC roles
      unitConfig.ConditionPathExists = "/etc/grsec/pw";
    };

    # Configure system tunables
    boot.kernel.sysctl = {
      # Read-only under grsecurity
      "kernel.kptr_restrict" = mkForce null;
    } // optionalAttrs (!cfg.enforcePolicy && config.nix.useSandbox) {
      # chroot(2) restrictions that conflict with sandboxed Nix builds.
      #
      # If policy is being enforced we assume that it deals with
      # disabling the requisite restrictions for Nix daemon/nixbld and
      # leave these settings enabled.
      "kernel.grsecurity.chroot_caps" = mkForce 0;
      "kernel.grsecurity.chroot_deny_chroot" = mkForce 0;
      "kernel.grsecurity.chroot_deny_mount" = mkForce 0;
      "kernel.grsecurity.chroot_deny_pivot" = mkForce 0;
      "kernel.grsecurity.chroot_deny_chmod" = mkForce 0;
    } // optionalAttrs containerSupportRequired {
      # chroot(2) restrictions that conflict with NixOS lightweight containers
      "kernel.grsecurity.chroot_deny_chmod" = mkForce 0;
      "kernel.grsecurity.chroot_deny_mount" = mkForce 0;
      "kernel.grsecurity.chroot_restrict_nice" = mkForce 0;
      "kernel.grsecurity.chroot_caps" = mkForce 0;
    };

    assertions = [
      { assertion = !zfsNeededForBoot;
        message = "grsecurity is currently incompatible with ZFS";
      }
    ];

  };
}

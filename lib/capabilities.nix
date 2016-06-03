/* Procedures and data for dealing with Linux capabilities. */

let
  inherit (import ./strings.nix) toUpper;
in

{
  /* All capabilities(7), lower-cased and without the CAP_ prefix.  Allows us to
    statically check input and is more convenient to type. */
  capabilities =
    [ "audit_control"
      "audit_read"
      "audit_write"
      "block_suspend"
      "chown"
      "dac_override"
      "dac_read_search"
      "fowner"
      "fsetid"
      "ipc_lock"
      "kill"
      "lease"
      "linux_immutable"
      "mac_admin"
      "mac_override"
      "mknod"
      "net_admin"
      "net_bind_service"
      "net_broadcast"
      "net_raw"
      "setgid"
      "setfcap"
      "setpcap"
      "setuid"
      "sys_admin"
      "sys_boot"
      "sys_chroot"
      "sys_module"
      "sys_nice"
      "sys_pacct"
      "sys_ptrace"
      "sys_rawio"
      "sys_resource"
      "sys_time"
      "sys_tty_config"
      "syslog"
      "wake_alarm"
    ];

  /* Expand a short-form capability name (as above) into an actual capability
     name, as understood by cap_from_name(3). */
  capFromName = name: "CAP_${toUpper name}";
}

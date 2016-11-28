{ config, lib, pkgs, ... }:

let
  inherit (lib) mkIf mkOption types concatMapStrings;
  cfg = config.security.apparmor;

  runLocalCommand = name: env:
    pkgs.runCommand name ({
      allowSubstitutes = false;
      preferLocalBuild = true;
    } // env);

  profileDir = pkgs.runLocalCommand "apparmor.d" {} ''
  '';
in

{
   options = {
     security.apparmor = {
       enable = mkOption {
         type = types.bool;
         default = false;
         description = "Enable the AppArmor Mandatory Access Control system.";
       };
       profiles = mkOption {
         type = types.listOf types.path;
         default = [];
         description = "List of files containing AppArmor profiles.";
       };
       packages = mkOption {
         type = types.listOf types.package;
         default = [];
         description = "Packages that expose one or more AppArmor profiles";
       };
     };
   };

   config = mkIf cfg.enable {
     environment.systemPackages = [ pkgs.apparmor-utils ];

     systemd.services.apparmor = {
       wantedBy = [ "local-fs.target" ];
       serviceConfig = {
         Type = "oneshot";
         RemainAfterExit = "yes";
         ExecStart = concatMapStrings (p:
           ''${pkgs.apparmor-parser}/bin/apparmor_parser -rKv -I ${pkgs.apparmor-profiles}/etc/apparmor.d "${p}" ; ''
         ) cfg.profiles;
         ExecStop = concatMapStrings (p:
           ''${pkgs.apparmor-parser}/bin/apparmor_parser -Rv "${p}" ; ''
         ) cfg.profiles;
       };
     };
   };
}

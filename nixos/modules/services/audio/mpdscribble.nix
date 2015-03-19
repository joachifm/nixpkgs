{ config, lib, pkgs, ... }:
with lib;

let
  user = "mpdscribble";
  group = "mpdscribble";

  cacheDir = "/var/cache/mpdscribble";

  cfg = config.services.mpdscribble;

  scrobblerOpts = { name, config, ... }: {
    options = {
      url = mkOption {
        type = types.str;
        description = "Scrobble server URL";
      };
      username = mkOption {
        type = types.str;
        description = "Scrobble server username";
        example = "username";
      };
      password = mkOption {
        type = types.str;
        description = ''
          Scrobble server password.

          The password is written to the Nix store as-is. You may provide
          the MD5 sum of the password instead, or use <command>
          builtins.hashString "md5" "passphrase"</command> to have the
          passphrase hashed before being written to the store.

          Do not rely on password hashing for security. The hash of a weak
          password is easily reversed. Furthermore, anyone who obtains the
          MD5 sum of your password can scrobble on your behalf.
        '';
        example = "password";
      };
    };
  };

  scrobblerConf = name: cfg: ''
    [${name}]
    url = ${cfg.url}
    username = ${cfg.username}
    password = ${cfg.password}
    journal = ${cacheDir}/${name}.journal
  '';

  configFile = pkgs.writeText "mpdscribble.conf" ''
    [mpdscribble]
    host = "${cfg.mpdHost}"
    port = ${toString cfg.mpdPort}

    ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: cfg: scrobblerConf name cfg) cfg.servers)}
  '';
in

{
  options = {
    services.mpdscribble = {
      enable = mkEnableOption "A scrobbling MPD client";
      mpdHost = mkOption {
        default = "localhost";
        type = types.str;
        description = "MPD host address.";
      };
      mpdPort = mkOption {
        default = 6600;
        type = types.int;
        description = "MPD port.";
      };
      servers = mkOption {
        default = {};
        type = types.loaOf types.optionSet;
        description = "The set of scrobble servers.";
        options = [ scrobblerOpts ];
        example = literalExample ''
          librefm = {
            username = "foo";
            password = "password";
            url = "http://turtle.libre.fm";
          };
          lastfm = {
            username = "foo";
            password = builtins.hashString "md5" "password";
            url = "http://post.audioscrobbler.com";
          };
        '';
      };
    };
  };

  config = mkIf cfg.enable {
    users.extraUsers.mpdscribble = {
      uid = config.ids.uids.mpdscribble;
      home = "/var/empty";
    };
    users.extraGroups.mpdscribble.gid = config.ids.gids.mpdscribble;

    systemd.services.mpdscribble = {
      wantedBy = [ "mpd.service" ];
      after = [ "mpd.service" ];

      preStart = ''
        mkdir -m 755 -p ${dirOf cacheDir}
        mkdir -m 700 -p ${cacheDir}
        chown ${user}:${group} ${cacheDir}
      '';

      serviceConfig = {
        User = user;
        Group = group;
        ExecStart = "${pkgs.mpdscribble}/bin/mpdscribble --no-daemon --conf ${configFile}";
        PermissionsStartOnly = true;
      };
    };
  };
}

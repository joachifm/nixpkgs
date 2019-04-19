import ./make-test.nix ({ pkgs, ...} :

let
  freedoom = pkgs.fetchzip rec {
    url = "https://github.com/freedoom/freedoom/releases/download/v${meta.version}/freedoom-${meta.version}.zip";
    sha256 = "0hyysr6jgyy65lpzjv4x2yrvgzhhlkihn9ndp4ljq7qyh3qzx4rf";
    meta.version = "0.11.3";
  };
in

rec {
  name = "gzdoom";
  meta = with pkgs.stdenv.lib.maintainers; {
    maintainers = [ joachifm ];
  };

  machine =
    { pkgs, ... }:

    { imports = [ ./common/x11.nix ];
      environment.systemPackages = [ pkgs.gzdoom ];
      networking.dhcpcd.enable = false;
      hardware.opengl.driSupport = true;
    };

  testScript =
    ''
      $machine->waitForX;
      $machine->execute("gzdoom +logfile gzdoom.txt -nosound -iwad ${freedoom}/freedoom1.wad -warp 1 &");
      $machine->sleep(20);
      $machine->screenshot("screen");
    '';

})

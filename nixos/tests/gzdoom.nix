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
      environment.systemPackages = [ pkgs.gzdoom pkgs.xdotool ];
      networking.dhcpcd.enable = false;
      hardware.opengl.driSupport = true;
    };

  testScript =
    ''
      $machine->waitForX;
      $machine->execute("gzdoom -nosound -width 640 -height 480 +set fullscreen false &");
      $machine->waitUntilSucceeds("pgrep -c gzdoom");
      $machine->succeed("xdotool search --onlyvisible --class gzdoom windowfocus --sync windowactivate --sync");
      $machine->sleep(10);
      $machine->screenshot("screen");
    '';
})

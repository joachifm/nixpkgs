{ stdenv, writeScriptBin, coreutils, gnutar, gzip }:

with stdenv.lib;

let self = { # explicit recursion to avoid cycles

  date = writeScriptBin "date" ''
    #! ${stdenv.shell}
    exec ${coreutils}/bin/date -ud@''${SOURCE_DATE_EPOCH:=1}
  '';

  gzip = writeScriptBin "gzip" ''
    #! ${stdenv.shell}
    exec ${gzip}/bin/gzip -n "''${@}"
  '';

  tar = writeScriptBin "tar" ''
    #! ${stdenv.shell}
    PATH=${makeBinPath [ self.gzip self.date ]}''${PATH:+:$PATH}
    exec ${gnutar}/bin/tar "''${@}" \
      --sort=name \
      --mtime="$(date)" \
      --group=0:0 \
      --owner=0:0
  '';

}; in self

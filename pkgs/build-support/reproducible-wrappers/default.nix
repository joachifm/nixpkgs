{ stdenv
, buildEnv
, writeScriptBin
, coreutils
, gnutar
, gzip
}:

with stdenv.lib;

let self = { # explicit recursion to avoid cycles

  dateWrapper = writeScriptBin "date" ''
    #! ${stdenv.shell}
    exec -a date ${coreutils}/bin/date -ud@''${SOURCE_DATE_EPOCH:=1}
  '';

  gzipWrapper = writeScriptBin "gzip" ''
    #! ${stdenv.shell}
    exec -a gzip ${gzip}/bin/gzip -n "''${@}"
  '';

  tarWrapper = with self; writeScriptBin "tar" ''
    #! ${stdenv.shell}
    PATH=${makeBinPath [ gzipWrapper dateWrapper ]}''${PATH:+:$PATH}
    exec -a tar ${gnutar}/bin/tar "''${@}" \
      --sort=name \
      --mtime="$(date)" \
      --group=0:0 \
      --owner=0:0
  '';

  env = buildEnv {
    name = "reproducible-wrappers";
    paths = with self; [ dateWrapper gzipWrapper tarWrapper ];
  };

}; in self

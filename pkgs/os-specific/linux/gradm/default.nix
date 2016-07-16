{ stdenv, fetchurl
, bison, flex
, pam
}:

stdenv.mkDerivation rec {
  name    = "gradm-${version}";
  version = "3.1-201603152148";

  src  = fetchurl {
    url    = "http://grsecurity.net/stable/${name}.tar.gz";
    sha256 = "1dfpdzlf4lmpq84zr2hhmw6qvd2zf1h2karmialbipsxr75xxx07";
  };

  nativeBuildInputs = [ bison flex ];
  buildInputs = [ pam ];

  makeFlags = [
    "DESTDIR=$out"
    "LEX=${flex}/bin/flex"
    "MANDIR=/share/man"
    "MKNOD=true"
  ];

  preBuild = ''
    substituteInPlace Makefile \
      --replace "/usr/bin/" "" \
      --replace "/usr/include/security/pam_" "${pam}/include/security/pam_"

    substituteInPlace gradm_defs.h \
      --replace "/sbin/grlearn" "$out/bin/grlearn" \
      --replace "/sbin/gradm" "$out/bin/gradm" \
      --replace "/sbin/gradm_pam" "$out/bin/gradm_pam"
  '';

  # The install target wants to do all sorts of stuff, it is easier to just
  # overwrite it with our own installation procedure
  installPhase = ''
    mkdir -p $out/bin
    cp gradm gradm_pam grlearn $out/bin

    mkdir -p $out/etc/udev/rules.d
    cat >$out/etc/udev/rules.d/80-grsec.rules <<EOF
    ACTION!="add|change", GOTO="permissions_end"
    KERNEL=="grsec", MODE="0622"
    LABEL="permissions_end"
    EOF

    mkdir -p $out/share/man/man8
    cp gradm.8 $out/share/man/man8

    mkdir -p $out/share/gradm
    cp learn_config policy $out/share/gradm
  '';

  enableParallelBuilding = true;

  meta = with stdenv.lib; {
    description = "grsecurity RBAC administration and policy analysis utility";
    homepage    = "https://grsecurity.net";
    license     = licenses.gpl2;
    platforms   = platforms.linux;
    maintainers = with maintainers; [ thoughtpolice joachifm ];
  };
}

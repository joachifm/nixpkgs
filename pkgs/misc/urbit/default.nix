{ stdenv, fetchurl, fetchFromGitHub
, automake, autoconf, libtool, pkgconfig, cmake
, ragel, re2c, perl
, gmp, libsigsegv, openssl, zlib
, ncurses
}:

let
  arvoBoot = fetchurl {
    url = "https://bootstrap.urbit.org/latest.pill";
    sha256 = "02508ixs85x2j66y5yvikj6zarim1x9byz2nmsd63z0bvykl6i5z";
  };
in

stdenv.mkDerivation rec {
  name = "urbit-${version}";
  version = "2016-06-02";

  src = fetchFromGitHub {
    owner = "urbit";
    repo = "urbit";
    rev = "8c113559872e4a97bce3f3ee5b370ad9545c7459";
    sha256 = "055qdpp4gm0v04pddq4380pdsi0gp2ybgv1d2lchkhwsnjyl46jl";
  };

  nativeBuildInputs = [ automake autoconf libtool cmake pkgconfig ragel re2c perl ];

  buildInputs = [ gmp libsigsegv openssl zlib ]
    ++ stdenv.lib.optional stdenv.isLinux ncurses;

  postPatch = stdenv.lib.optionalString stdenv.isLinux ''
    substituteInPlace Makefile --replace "-lcurses" "-lncurses"
  '';

  # the build invokes cmake indirectly; in a way that is incompatible with
  # cmake's setup-hook
  configurePhase = ":";

  installPhase = ''
    mkdir -p $out/bin
    cp -v bin/urbit $out/bin/.urbit-wrapped

    cat >$out/bin/urbit <<EOF
    #! $shell -e
    if [ -z "\$URBIT_HOME" ] ; then
      URBIT_HOME=\''${XDG_DATA_HOME:-\$HOME/.local/share}/urbit
    fi
    if [ ! -d "\$URBIT_HOME" ] ; then
      mkdir -pv "\$URBIT_HOME"
    fi
    if [ ! -f "\$URBIT_HOME"/urbit.pill ] || [ "\$URBIT_HOME"/urbit.pill -ot ${arvoBoot} ] ; then
      cp -fv ${arvoBoot} "\$URBIT_HOME"/urbit.pill
    fi
    cd "\$URBIT_HOME"
    exec -a $out/bin/urbit $out/bin/.urbit-wrapped "\$@"
    EOF
    chmod +x $out/bin/urbit
  '';

  meta = with stdenv.lib; {
    description = "An operating function";
    homepage = http://urbit.org;
    license = licenses.mit;
    platforms = platforms.unix;
    maintainers = with maintainers; [ mudri ];
  };
}

{ stdenv, fetchurl
, autoreconfHook, pkgconfig, bison, flex, perl, which
, pam
}:

stdenv.mkDerivation rec {
  name = "apparmor-${version}";
  series = "2.10";
  version = series;

  src = fetchurl {
    url = "https://launchpad.net/apparmor/${series}/${version}/+download/apparmor-${version}.tar.gz";
    sha256 = "1x06qmmbha9krx7880pxj2k3l8fxy3nm945xjjv735m2ax1243jd";
  };

  outputs = [ "dev" "out" "man" "pam" "parser" "profiles" ];

  nativeBuildInputs = [ autoreconfHook bison flex perl which pkgconfig ];

  buildInputs = [
    # for pam_apparmor
    pam
  ];

  dontDisableStatic = true;
  enableParallelBuilding = true;

  buildCommand = ''
    unpackPhase
    cd ${name}

    substituteInPlace common/Make.rules \
      --replace "/usr/bin/pod2man" "${perl}/bin/pod2man" \
      --replace "/usr/bin/pod2html" "${perl}/bin/pod2html" \
      --replace "/usr/include/linux/capability.h" "${stdenv.cc.libc.dev}/include/linux/capability.h" \
      --replace "/usr/share/man" "share/man"

    # component: libapparmor
    (
    cd libraries/libapparmor

    substituteInPlace src/Makefile.am \
      --replace "/usr/include/netinet/in.h" "${stdenv.cc.libc.dev}/include/netinet/in.h"
    substituteInPlace src/Makefile.in \
      --replace "/usr/include/netinet/in.h" "${stdenv.cc.libc.dev}/include/netinet/in.h"
    configurePhase
    buildPhase
    installPhase
    fixupPhase
    )

    # component: apparmor_parser
    (
    cd parser
    substituteInPlace Makefile \
      --replace "/usr/include/linux/capability.h" "${stdenv.cc.libc.dev}/include/linux/capability.h" \
      --replace "manpages htmlmanpages pdf" "manpages htmlmanpages"
    configurePhase
    makeFlags="YACC=${bison}/bin/bison LEX=${flex}/bin/flex DISTRO=unknown LANGS= DESTDIR=$parser $makeFlags"
    buildPhase
    installPhase
    # lib/ contains bash subroutines for init scripts, which adds bash
    # to the closure; usr/ and var/ are just empty directories.
    rm -rf $parser/lib $parser/usr $parser/var
    fixupPhase
    )

    # component: profiles
    (
    cd profiles
    makeFlags="DESTDIR=$profiles $makeFlags"
    buildPhase
    installPhase
    mv $profiles/usr/share $profiles/share
    rmdir $profiles/usr
    fixupPhase
    )

    # component: pam_apparmor
    (
    cd changehat/pam_apparmor
    configurePhase
    makeFlags="DESTDIR=$pam $makeFlags"
    buildPhase
    installPhase
    fixupPhase
    )
  '';

  meta = with stdenv.lib; {
    homepage = http://apparmor.net/;
    description = "AppArmor user space components";
    license = licenses.gpl2;
    maintainers = with maintainers; [ phreedom thoughtpolice joachifm ];
    platforms = platforms.linux;
  };
}

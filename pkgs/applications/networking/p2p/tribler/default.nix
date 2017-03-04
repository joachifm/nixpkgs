{ stdenv
, fetchurl
, fetchFromGitHub
, makeWrapper
, python27Packages
, libsodium
, libtorrentRasterbar
, phonon
, phonon-backend-vlc
, qtsvg
}:

with stdenv.lib;

python27Packages.buildPythonApplication rec {
  name = "tribler-${version}";
  version = "7.0.0-alpha3";

  src = fetchFromGitHub {
    owner = "Tribler";
    repo = "tribler";
    fetchSubmodules = true;
    sha256 = "1bar5w9gf9dr027xddba0ydvr5zl0gwhn2qi96q609icrl6a7xcg";
    # Recent HEAD, mostly interested in the support for not having VLC
    rev = "1717b3d157411a2993440e2955d34275ed7a8f65";
  };

  /*
  src = fetchurl {
    url = "https://github.com/Tribler/tribler/releases/download/v${version}/Tribler-v${version}.tar.xz";
    # see https://github.com/Tribler/tribler/releases/download/v${version}/SHA256.txt
    sha256 = "1ln4y8armd5mjqb77fpsjslq9r0ix92yvcz313ib9hixcgp1s55n";
  };
  */

  propagatedBuildInputs = [
    python27Packages.apsw
    python27Packages.chardet
    python27Packages.cherrypy
    python27Packages.configobj
    python27Packages.cryptography
    python27Packages.decorator
    python27Packages.feedparser
    python27Packages.m2crypto
    python27Packages.matplotlib
    python27Packages.netifaces
    python27Packages.pillow
    python27Packages.plyvel
    python27Packages.pyqt5
    python27Packages.requests
    python27Packages.twisted

    libtorrentRasterbar
    phonon-backend-vlc
    qtsvg
  ];

  LD_LIBRARY_PATH = makeLibraryPath [ libsodium libtorrentRasterbar ];

  # TODO: make it run the tests ...
  doCheck = false;

  postInstall = ''
    mkdir -p $out/bin $out/share/tribler

    cat >$out/bin/tribler <<EOF
    #! ${stdenv.shell} -e
    export LD_LIBRARY_PATH=$LD_LIBRARY_PATH
    export QT_PLUGIN_PATH=$QT_PLUGIN_PATH
    export PYTHONPATH=$out/lib/python2.7/site-packages:$out/share/tribler:$PYTHONPATH
    exec ${python27Packages.python.interpreter} $out/share/tribler/run_tribler.py "\''${@}"
    EOF
    chmod +x $out/bin/tribler
  '';

  postFixup = ''
    cp -rt $out/share/tribler/ \
      logger.conf run_tribler.py twisted Tribler TriblerGUI
  '';

  meta = with stdenv.lib; {
    homepage = https://www.tribler.org/;
    description = "Anonymous, decentralized P2P filesharing";
    license = licenses.lgpl21;
    platforms = platforms.linux;
  };
}

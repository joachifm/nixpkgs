{ stdenv
, fetchurl
, makeWrapper
, python27Packages
, libtorrentRasterbar
, libsodium
, libX11
, leveldb
, phonon-backend-vlc
}:

with stdenv.lib;

let
  # Packages that are added to PYTHONPATH by a setup hook
  pythonPath = with python27Packages; [
    apsw
    chardet
    cherrypy
    configobj
    cryptography
    decorator
    feedparser
    m2crypto
    netifaces
    pillow
    pyqt5
    requests
    twisted

    # Non-pythonPackages packages that provide python libs
    libtorrentRasterbar
  ];

  libPath = makeLibraryPath [ leveldb libsodium libX11 libtorrentRasterbar ];
in

stdenv.mkDerivation rec {
  name = "tribler-${version}";
  version = "7.0.0-alpha3";

  src = fetchurl {
    url = "https://github.com/Tribler/tribler/releases/download/v${version}/Tribler-v${version}.tar.xz";
    # see https://github.com/Tribler/tribler/releases/download/v${version}/SHA256.txt
    sha256 = "1ln4y8armd5mjqb77fpsjslq9r0ix92yvcz313ib9hixcgp1s55n";
  };

  buildInputs = pythonPath;

  buildPhase = ''
    ${python27Packages.python.interpreter} setup.py build
  '';

  installPhase = ''
    ${python27Packages.python.interpreter} setup.py --root=$out --optimize=1
  '';

  meta = with stdenv.lib; {
    homepage = https://www.tribler.org/;
    description = "Anonymous, decentralized P2P filesharing";
    longDescription = ''
      Tribler combines Tor-like onion routing with Bittorrent
      streaming to provide censorship resistant video streaming.
    '';
    license = licenses.lgpl21;
    platforms = platforms.linux;
  };
}

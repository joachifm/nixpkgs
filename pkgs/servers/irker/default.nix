{ stdenv, fetchgit, python, pkgconfig, systemd
, xmlto, docbook2x, docbook_xsl, docbook_xml_dtd_412 }:

stdenv.mkDerivation rec {
  name = "irker-${version}";
  version = "2017-02-12";
  src = fetchgit {
    url = "https://gitlab.com/esr/irker.git";
    rev = "dc0f65a7846a3922338e72d8c6140053fe914b54";
    sha256 = "1hslwqa0gqsnl3l6hd5hxpn0wlachxd51infifhlwhyhd6iwgx8p";
  };

  buildInputs = [
    python pkgconfig systemd
    xmlto docbook2x docbook_xsl docbook_xml_dtd_412
    # Needed for proxy support I believe, which I haven't tested.
    # Probably needs to be propagated and some wrapPython magic
    # python.pkgs.pysocks
  ];

  preBuild = ''
    export XML_CATALOG_FILES='${docbook_xsl}/xml/xsl/docbook/catalog.xml ${docbook_xml_dtd_412}/xml/dtd/docbook/catalog.xml'
  '';

  patchPhase = ''
    substituteInPlace Makefile \
      --replace '-o 0 -g 0' "" \
      --replace 'SYSTEMDSYSTEMUNITDIR :=' 'SYSTEMDSYSTEMUNITDIR ?='
  '';

  installFlags = [
    "prefix=/"
    "DESTDIR=$$out"
    "SYSTEMDSYSTEMUNITDIR=/lib/systemd/system"
  ];

  meta = with stdenv.lib; {
    description = "IRC client that runs as a daemon accepting notification requests.";
    homepage = "https://gitlab.com/esr/irker";
    license = licenses.bsd2;
    maintainers = with maintainers; [ dtzWill ];
    platforms = platforms.unix;
  };
}

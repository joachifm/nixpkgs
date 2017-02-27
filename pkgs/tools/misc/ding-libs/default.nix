{ stdenv, fetchurl, check }:

stdenv.mkDerivation rec {
  name = "ding-libs-${version}";
  version = "0.6.0";

  src = fetchurl {
    url = "https://fedorahosted.org/released/ding-libs/ding-libs-${version}.tar.gz";
    sha1 = "c8ec86cb93a26e013a13b12a7b0b3fbc1bca16c1";
    sha256 = "1bczkvq7cblp75kqn6r2d7j5x7brfw6wxirzc6d2rkyb80gj2jkn";
  };

  enableParallelBuilding = true;
  buildInputs = [ check ];

  doCheck = true;

  meta = {
    description = "'D is not GLib' utility libraries";
    homepage = https://fedorahosted.org/sssd/;
    platforms = with stdenv.lib.platforms; linux;
    maintainers = with stdenv.lib.maintainers; [ e-user ];
    license = [ stdenv.lib.licenses.gpl3 stdenv.lib.licenses.lgpl3 ];
  };
}

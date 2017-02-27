{ stdenv, fetchurl, cmake, qt4, qjson, doxygen, boost }:

stdenv.mkDerivation rec {
  name = "libechonest-${version}";
  version = "2.3.0";

  src = fetchurl {
    url = "http://files.lfranchi.com/${name}.tar.bz2";
    sha1 = "cf1b279c96f15c87c36fdeb23b569a60cdfb01db";
    sha256 = "0i1bmq3a26p01nvlxqzb37bjbpzdc1mvjadkpwp136xz5ykkp63r";
  };

  buildInputs = [ cmake qt4 qjson doxygen boost ];
  enableParallelBuilding = true;

  meta = {
    description = "A C++/Qt wrapper around the Echo Nest API";
    homepage = "http://projects.kde.org/projects/playground/libs/libechonest";
    license = stdenv.lib.licenses.gpl2Plus;
    platforms = stdenv.lib.platforms.unix;
  };
}

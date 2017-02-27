{ stdenv, fetchurl }:

stdenv.mkDerivation rec {
  version = "4.5.0";
  name = "libpfm-${version}";

  src = fetchurl {
    url = "mirror://sourceforge/perfmon2/libpfm4/${name}.tar.gz";
    sha1 = "857eb066724e2a5b723d6802d217c8eddff79082";
    sha256 = "1d8nsp1apv4iwf24dpxs62v05r1ja699c3ify12xspx0r008j3vb";
  };

  installFlags = "DESTDIR=\${out} PREFIX= LDCONFIG=true";

  meta = with stdenv.lib; {
    description = "Helper library to program the performance monitoring events";
    longDescription = ''
      This package provides a library, called libpfm4 which is used to
      develop monitoring tools exploiting the performance monitoring
      events such as those provided by the Performance Monitoring Unit
      (PMU) of modern processors.
    '';
    license = licenses.gpl2;
    maintainers = [ maintainers.pierron ];
    platforms = platforms.all;
  };
}

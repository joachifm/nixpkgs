{ stdenv, fetchurl, removeReferencesToHook }:

stdenv.mkDerivation rec {
  name = "hello-2.10";

  src = fetchurl {
    url = "mirror://gnu/hello/${name}.tar.gz";
    sha256 = "0ssi1wpaf7plaswqqjwigppsg5fyh99vdlb9kzl7c9lng89ndq1i";
  };

  outputs = [ "out" "bar" ];

  # The magic sauce
  nativeBuildInputs = [ removeReferencesToHook ];

  # Generate some garbage to experiment on
  postInstall = ''
    echo ${stdenv.cc.cc} >> $out/bin/cc
    mkdir $bar
    echo ${stdenv.cc.libc.dev} >> $bar/textfile
    echo ${stdenv.cc.cc}       >> $bar/textfile
  '';

  # The expectation here is that out will be allowed to retain
  # its reference to stdenv.cc.cc, while neither cc.cc nor
  # cc.libc.dev will occur in output bar.
  removeReferencesTo = [ stdenv.cc.cc stdenv.cc.libc.dev ];
  removeReferencesToOutputs = [ "bar" ];

  doCheck = true;

  meta = {
    description = "A program that produces a familiar, friendly greeting";
    longDescription = ''
      GNU Hello is a program that prints "Hello, world!" when you run it.
      It is fully customizable.
    '';
    homepage = http://www.gnu.org/software/hello/manual/;
    license = stdenv.lib.licenses.gpl3Plus;
    maintainers = [ stdenv.lib.maintainers.eelco ];
    platforms = stdenv.lib.platforms.all;
  };
}
